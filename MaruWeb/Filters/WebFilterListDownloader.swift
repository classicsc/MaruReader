// WebFilterListDownloader.swift
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

// swiftformat:disable header
// This Source Code Form is subject to the terms of the Mozilla
// Public License, v. 2.0. If a copy of the MPL was not distributed
// with this file, You can obtain one at
// https://mozilla.org/MPL/2.0/.
//
// Copyright 2026 Samuel Smoker
// Original version Copyright 2022 The Brave Authors.

import Foundation
import os.log

/// Result of refreshing a single filter list.
public enum WebFilterListRefreshOutcome: Sendable, Equatable {
    /// New contents were downloaded and written to disk.
    case updated(digest: String)
    /// Server returned 304 Not Modified.
    case notModified
    /// Refresh failed; the previous contents (if any) are still usable.
    case failed(message: String)
}

/// Downloads filter lists with conditional GET, persisting results into
/// `WebFilterListStorage`. Safe to call from any actor — public methods hop to the main
/// actor when touching the storage.
public actor WebFilterListDownloader {
    @MainActor
    public static let shared = WebFilterListDownloader(storage: .shared)

    private let session: URLSession
    private let storage: WebFilterListStorage
    private let log = Logger(subsystem: "MaruWeb", category: "filter-list-downloader")
    /// Limits how many lists refresh in parallel to avoid stampeding the user's network.
    private let maxConcurrentRefreshes = 3

    public init(
        session: URLSession = WebFilterListDownloader.makeDefaultSession(),
        storage: WebFilterListStorage
    ) {
        self.session = session
        self.storage = storage
    }

    /// Builds a session that respects HTTP caching headers and uses a short-ish timeout
    /// so a wedged server can't stall the weekly refresh forever.
    public static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": "MaruReader/Web (FilterListUpdater)",
            "Accept": "text/plain, */*;q=0.5",
        ]
        return URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Refreshes every enabled filter list, with at most `maxConcurrentRefreshes` in
    /// flight at once. Returns a per-id outcome map.
    @discardableResult
    public func refreshAll(force: Bool = false) async -> [UUID: WebFilterListRefreshOutcome] {
        let entries = await MainActor.run { storage.entries.filter(\.isEnabled) }
        var outcomes: [UUID: WebFilterListRefreshOutcome] = [:]
        var iterator = entries.makeIterator()
        await withTaskGroup(of: (UUID, WebFilterListRefreshOutcome).self) { group in
            for _ in 0 ..< min(maxConcurrentRefreshes, entries.count) {
                guard let entry = iterator.next() else { break }
                group.addTask { [self] in
                    await (entry.id, refresh(entry: entry, force: force))
                }
            }
            while let result = await group.next() {
                outcomes[result.0] = result.1
                if let entry = iterator.next() {
                    group.addTask { [self] in
                        await (entry.id, refresh(entry: entry, force: force))
                    }
                }
            }
        }
        return outcomes
    }

    /// Refreshes a single filter list. `force` ignores etag/last-modified headers.
    public func refresh(entry: WebFilterListEntry, force: Bool = false) async -> WebFilterListRefreshOutcome {
        let attemptedAt = Date()
        var request = URLRequest(url: entry.sourceURL)
        request.httpMethod = "GET"
        if !force {
            if let etag = entry.etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified = entry.lastModifiedHeader {
                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                let message = "Non-HTTP response"
                await MainActor.run {
                    storage.applyDownloadFailure(id: entry.id, attemptedAt: attemptedAt, message: message)
                }
                return .failed(message: message)
            }
            switch httpResponse.statusCode {
            case 304:
                await MainActor.run {
                    storage.applyDownloadNotModified(id: entry.id, attemptedAt: attemptedAt, at: Date())
                }
                return .notModified
            case 200 ..< 300:
                guard let contents = String(data: data, encoding: .utf8) else {
                    let message = "Response body was not valid UTF-8"
                    await MainActor.run {
                        storage.applyDownloadFailure(id: entry.id, attemptedAt: attemptedAt, message: message)
                    }
                    return .failed(message: message)
                }
                let etag = httpResponse.value(forHTTPHeaderField: "Etag")
                let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
                do {
                    let digest = try await MainActor.run {
                        try storage.applyDownloadSuccess(
                            id: entry.id,
                            contents: contents,
                            etag: etag,
                            lastModified: lastModified,
                            attemptedAt: attemptedAt,
                            succeededAt: Date()
                        )
                    }
                    await updatePerListMetrics(entry: entry, contents: contents)
                    return .updated(digest: digest)
                } catch {
                    let message = "Failed to write filter list contents: \(error.localizedDescription)"
                    await MainActor.run {
                        storage.applyDownloadFailure(id: entry.id, attemptedAt: attemptedAt, message: message)
                    }
                    return .failed(message: message)
                }
            default:
                let message = "HTTP \(httpResponse.statusCode)"
                await MainActor.run {
                    storage.applyDownloadFailure(id: entry.id, attemptedAt: attemptedAt, message: message)
                }
                return .failed(message: message)
            }
        } catch {
            let message = (error as? URLError).map { "URLError(\($0.code.rawValue)): \($0.localizedDescription)" }
                ?? error.localizedDescription
            log.error("Filter list refresh failed for \(entry.sourceURL.absoluteString, privacy: .public): \(message, privacy: .public)")
            await MainActor.run {
                storage.applyDownloadFailure(id: entry.id, attemptedAt: attemptedAt, message: message)
            }
            return .failed(message: message)
        }
    }

    private func updatePerListMetrics(entry: WebFilterListEntry, contents: String) async {
        let source = WebFilterListSource(
            identifier: entry.id.uuidString,
            contents: contents,
            format: entry.format
        )
        guard let result = try? WebFilterListConverter.convert([source]) else { return }
        let ruleCount = Int(result.ruleCount)
        let convertedCount = Int(result.convertedFilterCount)
        await MainActor.run {
            storage.applyCompileMetrics(
                id: entry.id,
                ruleCount: ruleCount,
                convertedFilterCount: convertedCount
            )
        }
    }
}
