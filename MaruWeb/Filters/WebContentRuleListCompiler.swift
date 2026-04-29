// WebContentRuleListCompiler.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import os.log
import WebKit

/// Result of compiling a set of enabled filter lists into installable
/// `WKContentRuleList`s.
public struct WebCompiledRuleSet: Sendable {
    /// Identifier digest shared by every chunk in this set.
    public let digest32: String
    /// Compiled rule list chunks, in stable order.
    public let ruleLists: [WKContentRuleList]
    /// Engine used by the page script to apply cosmetic filters that cannot be
    /// represented as WebKit content rules.
    public let cosmeticEngine: WebCosmeticFilterEngine
    /// Total rule count across all chunks (after splitting).
    public let totalRuleCount: Int
    /// Total filter count reported by the FFI prior to splitting.
    public let convertedFilterCount: Int
}

public enum WebContentRuleListCompileError: Error, Sendable {
    case noEnabledLists
    case noContentsAvailable
    case ruleJSONNotArray
    case chunkCompileFailed(index: Int, identifier: String, underlying: Error)
}

/// Compiles enabled filter lists into one or more `WKContentRuleList`s, partitioning the
/// result into chunks of at most `WebContentBlocker.maxRulesPerCompiledList` rules each.
@MainActor
public final class WebContentRuleListCompiler {
    private let store: WKContentRuleListStore
    private let storage: WebFilterListStorage
    private let log = Logger(subsystem: "MaruWeb", category: "rule-list-compiler")

    public init(
        store: WKContentRuleListStore = .default()!,
        storage: WebFilterListStorage = .shared
    ) {
        self.store = store
        self.storage = storage
    }

    // MARK: - Public API

    /// Compiles the currently enabled filter lists. Returns `nil` if no lists are enabled
    /// or none of them have contents on disk yet.
    public func compileEnabled() async throws -> WebCompiledRuleSet? {
        let enabled = storage.entries.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }

        var sources: [WebFilterListSource] = []
        sources.reserveCapacity(enabled.count)
        for entry in enabled {
            guard let contents = storage.loadContents(for: entry.id), !contents.isEmpty else {
                continue
            }
            sources.append(WebFilterListSource(
                identifier: entry.id.uuidString,
                contents: contents,
                format: entry.format
            ))
        }
        guard !sources.isEmpty else { return nil }

        let definition = try WebFilterListConverter.convert(sources)
        let cosmeticEngine = try WebCosmeticFilterEngine(sources: sources)
        let digest32 = String(definition.contentDigest.prefix(32))
        let chunks = try Self.partition(
            ruleListJSON: definition.encodedContentRuleList,
            maxRulesPerChunk: WebContentBlocker.maxRulesPerCompiledList
        )

        let identifiers = chunks.indices.map { Self.identifier(digest32: digest32, index: $0) }
        var compiled: [WKContentRuleList] = []
        compiled.reserveCapacity(chunks.count)

        // Cache hit short-circuit: every chunk identifier already in the store.
        if let allCached = await lookupAll(identifiers: identifiers) {
            await garbageCollect(keeping: Set(identifiers))
            return WebCompiledRuleSet(
                digest32: digest32,
                ruleLists: allCached,
                cosmeticEngine: cosmeticEngine,
                totalRuleCount: chunks.reduce(0) { $0 + $1.ruleCount },
                convertedFilterCount: Int(definition.convertedFilterCount)
            )
        }

        for (index, chunk) in chunks.enumerated() {
            let identifier = identifiers[index]
            do {
                if let cached = try await lookup(identifier: identifier) {
                    compiled.append(cached)
                    continue
                }
                let list = try await compile(identifier: identifier, json: chunk.json)
                compiled.append(list)
            } catch {
                throw WebContentRuleListCompileError.chunkCompileFailed(
                    index: index,
                    identifier: identifier,
                    underlying: error
                )
            }
        }

        await garbageCollect(keeping: Set(identifiers))

        return WebCompiledRuleSet(
            digest32: digest32,
            ruleLists: compiled,
            cosmeticEngine: cosmeticEngine,
            totalRuleCount: chunks.reduce(0) { $0 + $1.ruleCount },
            convertedFilterCount: Int(definition.convertedFilterCount)
        )
    }

    // MARK: - Splitter

    struct RuleChunk: Equatable {
        let json: String
        let ruleCount: Int
    }

    /// Partitions a content-rule-list JSON document into chunks of at most
    /// `maxRulesPerChunk` rules each.
    nonisolated static func partition(
        ruleListJSON: String,
        maxRulesPerChunk: Int
    ) throws -> [RuleChunk] {
        precondition(maxRulesPerChunk > 0)
        guard let data = ruleListJSON.data(using: .utf8) else {
            throw WebContentRuleListCompileError.ruleJSONNotArray
        }
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        guard let array = parsed as? [Any] else {
            throw WebContentRuleListCompileError.ruleJSONNotArray
        }
        if array.isEmpty {
            return []
        }
        var chunks: [RuleChunk] = []
        var index = 0
        while index < array.count {
            let end = min(index + maxRulesPerChunk, array.count)
            let slice = Array(array[index ..< end])
            let chunkData = try JSONSerialization.data(withJSONObject: slice, options: [])
            guard let chunkString = String(data: chunkData, encoding: .utf8) else {
                throw WebContentRuleListCompileError.ruleJSONNotArray
            }
            chunks.append(RuleChunk(json: chunkString, ruleCount: slice.count))
            index = end
        }
        return chunks
    }

    nonisolated static func identifier(digest32: String, index: Int) -> String {
        "\(WebContentBlocker.contentRuleListIdentifierPrefix)-\(digest32)-\(index)"
    }

    // MARK: - WKContentRuleListStore wrappers

    private func lookup(identifier: String) async throws -> WKContentRuleList? {
        try await withCheckedThrowingContinuation { continuation in
            store.lookUpContentRuleList(forIdentifier: identifier) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else if error != nil {
                    // A missing identifier surfaces as an error on this API; treat as nil.
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func lookupAll(identifiers: [String]) async -> [WKContentRuleList]? {
        var results: [WKContentRuleList] = []
        results.reserveCapacity(identifiers.count)
        for identifier in identifiers {
            guard let list = try? await lookup(identifier: identifier) else { return nil }
            results.append(list)
        }
        return results
    }

    private func compile(identifier: String, json: String) async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            store.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: json
            ) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.featureUnsupported))
                }
            }
        }
    }

    private func availableIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            store.getAvailableContentRuleListIdentifiers { identifiers in
                continuation.resume(returning: identifiers ?? [])
            }
        }
    }

    private func remove(identifier: String) async {
        await withCheckedContinuation { continuation in
            store.removeContentRuleList(forIdentifier: identifier) { _ in
                continuation.resume()
            }
        }
    }

    private func garbageCollect(keeping keep: Set<String>) async {
        let prefix = WebContentBlocker.contentRuleListIdentifierPrefix + "-"
        let identifiers = await availableIdentifiers()
        for identifier in identifiers
            where identifier.hasPrefix(prefix) && !keep.contains(identifier)
        {
            log.info("Removing stale content rule list \(identifier, privacy: .public)")
            await remove(identifier: identifier)
        }
    }
}
