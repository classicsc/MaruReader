// DictionarySearchService.swift
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

import CoreData
import Foundation
import os

/// Metadata for a dictionary used during search
struct DictionaryMetadata {
    let id: UUID
    let title: String
    let termDisplayPriority: Int
    let termFrequencyDisplayPriority: Int
    let pitchDisplayPriority: Int
    let frequencyMode: String?
    let termResultsEnabled: Bool
    let termFrequencyEnabled: Bool
    let pitchAccentEnabled: Bool
}

public struct DictionarySearchService: Sendable {
    /// The maximum forward lookup length for the TextLookupRequest API
    static let maxForwardLookupLength = 10

    private let logger = Logger.maru(category: "DictionarySearchService")

    private let persistenceController: DictionaryPersistenceController
    private let candidateGenerator: DictionaryCandidateGenerator
    public init(
        persistenceController: DictionaryPersistenceController = DictionaryPersistenceController.shared
    ) {
        self.persistenceController = persistenceController
        self.candidateGenerator = DictionaryCandidateGenerator()
    }

    public func performSearch(query: String) async throws -> [GroupedSearchResults] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let candidates = candidateGenerator.generateCandidates(from: query)
        guard !candidates.isEmpty else { return [] }

        let metadata = try await getDictionaryMetadata()
        let context = persistenceController.newBackgroundContext()

        let matches = try await TermFetcher.fetchMatches(
            candidates: candidates,
            dictionaryMetadata: metadata,
            context: context
        )
        let grouped = DictionarySearchService.groupMatches(matches)
        return try await TermFetcher.materializeGroupedMatches(
            grouped,
            dictionaryMetadata: metadata,
            context: context
        )
    }

    /// Get dictionary metadata cache from Core Data
    private func getDictionaryMetadata() async throws -> [UUID: DictionaryMetadata] {
        let backgroundContext = persistenceController.newBackgroundContext()
        return try await backgroundContext.perform {
            let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO")

            let dictionaries = try backgroundContext.fetch(fetchRequest)

            var cache: [UUID: DictionaryMetadata] = [:]
            for dict in dictionaries {
                guard let id = dict.id else { continue }

                let metadata = DictionaryMetadata(
                    id: id,
                    title: dict.title ?? "",
                    termDisplayPriority: Int(dict.termDisplayPriority),
                    termFrequencyDisplayPriority: Int(dict.termFrequencyDisplayPriority),
                    pitchDisplayPriority: Int(dict.pitchDisplayPriority),
                    frequencyMode: dict.frequencyMode,
                    termResultsEnabled: dict.termResultsEnabled,
                    termFrequencyEnabled: dict.termFrequencyEnabled,
                    pitchAccentEnabled: dict.pitchAccentEnabled
                )
                cache[id] = metadata
            }

            return cache
        }
    }

    /// Start a lookup session for incremental results.
    public func startTextLookup(request: TextLookupRequest) async throws -> TextLookupSession? {
        guard let queryInfo = DictionarySearchService.extractQueryInfo(from: request) else {
            logger.debug("Skipping text lookup for empty query text")
            return nil
        }

        let queryText = queryInfo.text
        logger.debug("Performing text lookup for query: \(queryText)")
        logger.debug("Context: \(request.context), Offset: \(request.offset)")

        let candidates = candidateGenerator.generateCandidates(from: queryText)
        guard !candidates.isEmpty else {
            return nil
        }

        let candidateGroups = DictionarySearchService.groupCandidatesByRanking(candidates)

        async let metadata = getDictionaryMetadata()
        let stylesValue = DictionaryDisplayPreferences.displayStyles
        let metadataValue = try await metadata

        let dictionaryStyles = DictionarySearchService.dictionaryStylesCSS(from: metadataValue)

        return TextLookupSession(
            request: request,
            queryText: queryText,
            queryStartIndex: queryInfo.startIndex,
            styles: stylesValue,
            dictionaryStyles: dictionaryStyles,
            candidateGroups: candidateGroups,
            persistenceController: persistenceController,
            dictionaryMetadata: metadataValue
        )
    }

    static func groupResults(_ results: [SearchResult], deinflectionLanguage: DeinflectionLanguage = .en) -> [GroupedSearchResults] {
        let grouped = Swift.Dictionary(grouping: results, by: { result in
            "\(result.term)|\(result.reading ?? "")"
        })

        return grouped.map { termKey, termResults in
            let firstResult = termResults.first!
            let dictionaryGroups = Swift.Dictionary(grouping: termResults, by: { "\($0.dictionaryUUID)|\($0.sequence)|\($0.definitionTags)|\($0.score)" })

            let dictionaryResults = dictionaryGroups.map { _, dictResults in
                let dictionaryTitle = dictResults.first?.dictionaryTitle ?? "Unknown Dictionary"
                let dictionaryUUID = dictResults.first?.dictionaryUUID ?? UUID()
                let sequence = dictResults.first?.sequence ?? 0
                let score = dictResults.first?.score ?? 0.0
                return DictionaryResults(
                    dictionaryTitle: dictionaryTitle,
                    dictionaryUUID: dictionaryUUID,
                    sequence: sequence,
                    score: score,
                    results: dictResults
                )
            }.sorted { (lhs: DictionaryResults, rhs: DictionaryResults) in
                let lhsPriority = lhs.results.first?.displayPriority ?? 0
                let rhsPriority = rhs.results.first?.displayPriority ?? 0
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.sequence < rhs.sequence
            }

            // Aggregate term tags from all results for this term
            let allTermTags = termResults.map(\.termTags)
            let mergedTermTags = [Tag].merge(allTermTags)

            // Aggregate pitch accents from all results for this term
            let allPitchAccents = firstResult.pitchAccents
            let pitchAccentsByDictionary = Swift.Dictionary(grouping: allPitchAccents, by: \.dictionaryID)
            let pitchAccentResults = pitchAccentsByDictionary.map { dictionaryID, pitchResults in
                let firstResult = pitchResults.first!
                // Flatten all pitches from this dictionary
                let allPitches = pitchResults.flatMap(\.pitches)
                return PitchAccentResults(
                    dictionaryTitle: firstResult.dictionaryTitle,
                    dictionaryID: dictionaryID,
                    priority: firstResult.priority,
                    pitches: allPitches
                )
            }.sorted { $0.priority < $1.priority }

            // Format deinflection info from top result
            let deinflectionInfo = formatDeinflectionInfo(from: firstResult.deinflectionRules, language: deinflectionLanguage)
            let deinflectionInfoHTML = formatDeinflectionInfoHTML(from: firstResult.deinflectionRules, language: deinflectionLanguage)

            return GroupedSearchResults(
                termKey: termKey,
                expression: firstResult.term,
                reading: firstResult.reading,
                dictionariesResults: dictionaryResults,
                pitchAccentResults: pitchAccentResults,
                termTags: mergedTermTags,
                deinflectionInfo: deinflectionInfo,
                deinflectionInfoHTML: deinflectionInfoHTML
            )
        }.sorted { lhs, rhs in
            guard let lhsFirst = lhs.dictionariesResults.first?.results.first,
                  let rhsFirst = rhs.dictionariesResults.first?.results.first
            else {
                return false
            }
            return lhsFirst.rankingCriteria > rhsFirst.rankingCriteria
        }
    }

    /// Groups lightweight TermMatch results by term|reading, then by dictionary.
    /// Uses raw tag strings for sub-grouping (no tag metadata resolution needed).
    static func groupMatches(_ matches: [TermMatch]) -> [GroupedTermMatches] {
        let grouped = Swift.Dictionary(grouping: matches) { match in
            "\(match.term)|\(match.reading ?? "")"
        }

        return grouped.map { termKey, termMatches in
            let firstMatch = termMatches.first!

            let dictionaryGroups = Swift.Dictionary(grouping: termMatches) {
                "\($0.dictionaryUUID)|\($0.sequence)|\($0.definitionTagsRaw ?? "")|\($0.score)"
            }

            let dictionaryMatchesList = dictionaryGroups.map { _, dictMatches in
                let first = dictMatches.first!
                return DictionaryTermMatches(
                    dictionaryTitle: first.dictionaryTitle,
                    dictionaryUUID: first.dictionaryUUID,
                    displayPriority: first.displayPriority,
                    sequence: first.sequence,
                    score: first.score,
                    matches: dictMatches
                )
            }.sorted { (lhs: DictionaryTermMatches, rhs: DictionaryTermMatches) in
                if lhs.displayPriority != rhs.displayPriority {
                    return lhs.displayPriority < rhs.displayPriority
                }
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.sequence < rhs.sequence
            }

            return GroupedTermMatches(
                termKey: termKey,
                expression: firstMatch.term,
                reading: firstMatch.reading,
                dictionaryMatches: dictionaryMatchesList,
                topRankingCriteria: firstMatch.rankingCriteria,
                deinflectionRules: firstMatch.deinflectionRules
            )
        }.sorted { lhs, rhs in
            lhs.topRankingCriteria > rhs.topRankingCriteria
        }
    }

    private static func extractQueryInfo(from request: TextLookupRequest) -> (text: String, startIndex: String.Index)? {
        guard request.offset >= 0 else { return nil }
        guard request.offset <= request.context.count else { return nil }

        var startIndex = request.context.index(request.context.startIndex, offsetBy: request.offset)
        let endIndex = request.context.index(
            startIndex,
            offsetBy: DictionarySearchService.maxForwardLookupLength,
            limitedBy: request.context.endIndex
        ) ?? request.context.endIndex

        // If the query text begins with whitespace or punctuation, skip those characters
        while startIndex < endIndex, request.context[startIndex].isWhitespace || request.context[startIndex].isPunctuation {
            startIndex = request.context.index(after: startIndex)
        }

        let queryText = String(request.context[startIndex ..< endIndex])
        guard !queryText.isEmpty else {
            return nil
        }

        return (queryText, startIndex)
    }

    private static func groupCandidatesByRanking(_ candidates: [LookupCandidate]) -> [CandidateGroup] {
        let grouped = Swift.Dictionary(grouping: candidates) { CandidateRankingKey(candidate: $0) }
        let sorted = grouped.sorted { lhs, rhs in
            lhs.key > rhs.key
        }

        return sorted.map { key, groupCandidates in
            CandidateGroup(key: key, candidates: groupCandidates)
        }
    }

    private static func dictionaryStylesCSS(from metadata: [UUID: DictionaryMetadata]) -> String {
        let styleInfos = metadata.values.map { DictionaryStyleInfo(id: $0.id, title: $0.title) }
        return DictionaryResultsHTMLRenderer.dictionaryStylesCSS(
            for: styleInfos,
            stylesheetProvider: DictionaryResultsHTMLRenderer.loadDictionaryStylesheet
        )
    }

    /// Format deinflection rules into a human-readable string using localized display names.
    private static func formatDeinflectionInfo(from rules: [[String]], language: DeinflectionLanguage) -> String? {
        guard !rules.isEmpty else { return nil }

        let localizeRule: (String) -> String = { name in
            JapaneseDeinflector.transforms[name]?.localization.displayName(for: language) ?? name
        }

        // Each inner array is a chain of rules that were applied
        // If there's only one chain with one rule, show it simply
        if rules.count == 1, let chain = rules.first {
            if chain.isEmpty {
                return nil
            } else if chain.count == 1 {
                return localizeRule(chain[0])
            } else {
                return chain.map(localizeRule).joined(separator: " \u{2192} ")
            }
        }

        // Multiple chains - show them as alternatives
        let chainDescriptions = rules.map { chain in
            chain.isEmpty ? "" : chain.map(localizeRule).joined(separator: " \u{2192} ")
        }.filter { !$0.isEmpty }

        return chainDescriptions.joined(separator: " | ")
    }

    /// Format deinflection rules as HTML, wrapping each rule name in a span with its description as a tooltip title.
    private static func formatDeinflectionInfoHTML(from rules: [[String]], language: DeinflectionLanguage) -> String? {
        guard !rules.isEmpty else { return nil }

        let ruleHTML: (String) -> String = { name in
            let localization = JapaneseDeinflector.transforms[name]?.localization
            let displayName = localization?.displayName(for: language) ?? name
            let description = localization?.description(for: language) ?? ""
            let escapedName = escapeHTML(displayName)
            if description.isEmpty {
                return escapedName
            }
            return "<span class=\"deinflection-rule\" title=\"\(escapeHTML(description))\">\(escapedName)</span>"
        }

        if rules.count == 1, let chain = rules.first {
            if chain.isEmpty {
                return nil
            } else if chain.count == 1 {
                return ruleHTML(chain[0])
            } else {
                return chain.map(ruleHTML).joined(separator: " \u{2192} ")
            }
        }

        let chainDescriptions = rules.map { chain in
            chain.isEmpty ? "" : chain.map(ruleHTML).joined(separator: " \u{2192} ")
        }.filter { !$0.isEmpty }

        return chainDescriptions.joined(separator: " | ")
    }
}
