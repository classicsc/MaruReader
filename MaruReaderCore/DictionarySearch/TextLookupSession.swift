// TextLookupSession.swift
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

struct CandidateGroup {
    let key: CandidateRankingKey
    let candidates: [LookupCandidate]
}

public struct TextLookupResultsBatch: Sendable {
    public let html: String
    public let nextCursor: Int
    public let hasMore: Bool

    public init(html: String, nextCursor: Int, hasMore: Bool) {
        self.html = html
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public actor TextLookupSession {
    public let request: TextLookupRequest
    public let queryText: String
    public let styles: DisplayStyles

    public var requestId: UUID {
        request.id
    }

    private let dictionaryStyles: String
    private let candidateGroups: [CandidateGroup]
    private let persistenceController: DictionaryPersistenceController
    private let dictionaryMetadata: [UUID: DictionaryMetadata]
    private let queryStartIndex: String.Index
    private let renderer: DictionaryResultsHTMLRenderer

    private var nextCandidateGroupIndex: Int = 0
    /// Lightweight grouped matches — no glossary decompression has occurred
    private var matchGroups: [GroupedTermMatches] = []
    /// Materialized results cache, keyed by termKey
    private var materializedCache: [String: GroupedSearchResults] = [:]
    /// Tag metadata cache, fetched once and reused across batches
    private var cachedTagMetadata: [String: TermFetcher.TagMetaData]?
    private var seenTermKeys: Set<String> = []
    private var renderCursor: Int = 0
    private var primaryResult: String?
    private var primaryResultSourceRange: Range<String.Index>?
    private var editedContext: String?
    private var editedPrimaryResultSourceRange: Range<String.Index>?

    init(
        request: TextLookupRequest,
        queryText: String,
        queryStartIndex: String.Index,
        styles: DisplayStyles,
        dictionaryStyles: String,
        candidateGroups: [CandidateGroup],
        persistenceController: DictionaryPersistenceController,
        dictionaryMetadata: [UUID: DictionaryMetadata]
    ) {
        self.request = request
        self.queryText = queryText
        self.queryStartIndex = queryStartIndex
        self.styles = styles
        self.dictionaryStyles = dictionaryStyles
        self.candidateGroups = candidateGroups
        self.persistenceController = persistenceController
        self.dictionaryMetadata = dictionaryMetadata
        self.renderer = DictionaryResultsHTMLRenderer(styles: styles)
    }

    public func dictionaryStylesCSS() -> String {
        dictionaryStyles
    }

    public func resetRenderCursor() {
        renderCursor = 0
    }

    public func prepareInitialResults(minimumResults: Int = 1) async throws -> Bool {
        guard minimumResults > 0 else {
            return hasAnyResults()
        }

        while matchGroups.count < minimumResults, nextCandidateGroupIndex < candidateGroups.count {
            _ = try await fetchNextCandidateGroup()
            if !matchGroups.isEmpty {
                break
            }
        }

        return !matchGroups.isEmpty
    }

    public func renderNextBatch(maxGroups: Int, mode: DictionaryResultsHTMLRenderer.Mode) async throws -> TextLookupResultsBatch {
        guard maxGroups > 0 else {
            return TextLookupResultsBatch(html: "", nextCursor: renderCursor, hasMore: hasMoreResults())
        }

        while matchGroups.count - renderCursor < maxGroups, nextCandidateGroupIndex < candidateGroups.count {
            _ = try await fetchNextCandidateGroup()
        }

        let endIndex = min(matchGroups.count, renderCursor + maxGroups)
        let batchMatchGroups = Array(matchGroups[renderCursor ..< endIndex])
        renderCursor = endIndex

        // Materialize only this batch
        let materializedGroups = try await materializeBatch(batchMatchGroups)

        let html = await renderer.render(groups: materializedGroups, mode: mode)
        return TextLookupResultsBatch(html: html, nextCursor: renderCursor, hasMore: hasMoreResults())
    }

    public func snapshot() async throws -> TextLookupResponse? {
        guard let primaryResult,
              let primaryRange = primaryResultSourceRange
        else {
            return nil
        }

        // Materialize all fetched groups for the snapshot
        let allMaterialized = try await materializeBatch(matchGroups)

        var response = TextLookupResponse(
            request: request,
            results: allMaterialized,
            primaryResult: primaryResult,
            primaryResultSourceRange: primaryRange,
            styles: styles
        )
        response.editedContext = editedContext
        response.editedPrimaryResultSourceRange = editedPrimaryResultSourceRange
        return response
    }

    public func termGroup(for termKey: String) async throws -> GroupedSearchResults? {
        if let cached = materializedCache[termKey] {
            return cached
        }
        guard let matchGroup = matchGroups.first(where: { $0.termKey == termKey }) else {
            return nil
        }
        let materialized = try await materializeBatch([matchGroup])
        return materialized.first
    }

    public func updateEditedContext(_ newContext: String) -> Bool {
        guard let primaryResult,
              let primaryResultSourceRange
        else {
            editedContext = newContext
            editedPrimaryResultSourceRange = nil
            return false
        }

        editedContext = newContext

        guard let firstRange = newContext.range(of: primaryResult) else {
            editedPrimaryResultSourceRange = nil
            return false
        }

        var allRanges: [Range<String.Index>] = []
        var searchStart = newContext.startIndex
        while let range = newContext.range(of: primaryResult, range: searchStart ..< newContext.endIndex) {
            allRanges.append(range)
            searchStart = range.upperBound
        }

        if allRanges.count == 1 {
            editedPrimaryResultSourceRange = firstRange
            return true
        }

        let originalContext = request.context
        let originalStart = originalContext.distance(
            from: originalContext.startIndex,
            to: primaryResultSourceRange.lowerBound
        )
        let originalProportion = Double(originalStart) / Double(max(1, originalContext.count))
        let targetPosition = Int(originalProportion * Double(newContext.count))

        var bestRange = firstRange
        var bestDistance = Int.max
        for range in allRanges {
            let position = newContext.distance(from: newContext.startIndex, to: range.lowerBound)
            let distance = abs(position - targetPosition)
            if distance < bestDistance {
                bestDistance = distance
                bestRange = range
            }
        }

        editedPrimaryResultSourceRange = bestRange
        return true
    }

    private func hasAnyResults() -> Bool {
        !matchGroups.isEmpty
    }

    private func hasMoreResults() -> Bool {
        renderCursor < matchGroups.count || nextCandidateGroupIndex < candidateGroups.count
    }

    private func fetchNextCandidateGroup() async throws -> [GroupedTermMatches] {
        guard nextCandidateGroupIndex < candidateGroups.count else { return [] }

        let group = candidateGroups[nextCandidateGroupIndex]
        nextCandidateGroupIndex += 1

        let context = persistenceController.newBackgroundContext()
        let termMatches = try await TermFetcher.fetchMatches(
            candidates: group.candidates,
            dictionaryMetadata: dictionaryMetadata,
            context: context
        )
        let groupedMatches = DictionarySearchService.groupMatches(termMatches)

        let newGroups = groupedMatches.filter { group in
            seenTermKeys.insert(group.termKey).inserted
        }

        if !newGroups.isEmpty {
            matchGroups.append(contentsOf: newGroups)
            if primaryResult == nil {
                updatePrimaryResult(from: newGroups)
            }
        }

        return newGroups
    }

    private func updatePrimaryResult(from groups: [GroupedTermMatches]) {
        guard primaryResult == nil,
              let topGroup = groups.first,
              let topMatch = topGroup.dictionaryMatches.first?.matches.first
        else {
            return
        }

        primaryResult = topMatch.term
        let substringLength = topMatch.candidate.originalSubstring.count
        let endIndex = request.context.index(
            queryStartIndex,
            offsetBy: substringLength,
            limitedBy: request.context.endIndex
        ) ?? request.context.endIndex
        primaryResultSourceRange = queryStartIndex ..< endIndex
    }

    // MARK: - Materialization

    /// Materializes a batch of GroupedTermMatches into GroupedSearchResults,
    /// caching the results for later access.
    private func materializeBatch(_ groups: [GroupedTermMatches]) async throws -> [GroupedSearchResults] {
        // Separate cached from uncached groups
        var result: [GroupedSearchResults] = []
        var toMaterialize: [GroupedTermMatches] = []

        for group in groups {
            if let cached = materializedCache[group.termKey] {
                result.append(cached)
            } else {
                toMaterialize.append(group)
            }
        }

        if !toMaterialize.isEmpty {
            let context = persistenceController.newBackgroundContext()

            // Fetch and cache tag metadata before materialization to avoid a redundant fetch
            if cachedTagMetadata == nil {
                let enabledDictionaryIDs = Array(dictionaryMetadata.filter(\.value.termResultsEnabled).keys)
                cachedTagMetadata = try await TermFetcher.fetchTagMetadataMap(
                    enabledDictionaryIDs: enabledDictionaryIDs,
                    context: context
                )
            }

            let materialized = try await TermFetcher.materializeGroupedMatches(
                toMaterialize,
                dictionaryMetadata: dictionaryMetadata,
                context: context,
                tagMetadataMap: cachedTagMetadata
            )

            for group in materialized {
                materializedCache[group.termKey] = group
            }
            result.append(contentsOf: materialized)
        }

        // Preserve original group ordering
        let ordering = Swift.Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($1.termKey, $0) })
        result.sort { (ordering[$0.termKey] ?? 0) < (ordering[$1.termKey] ?? 0) }

        return result
    }
}
