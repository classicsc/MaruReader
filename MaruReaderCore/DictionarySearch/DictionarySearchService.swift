// DictionarySearchService.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import os.log

/// Metadata for a dictionary used during search
struct DictionaryMetadata: Sendable {
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

public actor DictionarySearchService {
    /// The maximum forward lookup length for the TextLookupRequest API
    static let maxForwardLookupLength = 10

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchService")

    private let persistenceController: DictionaryPersistenceController
    private var candidateGenerator: DictionaryCandidateGenerator
    private let backgroundContext: NSManagedObjectContext
    private let audioLookupService: AudioLookupService?

    /// Cached dictionary metadata, refreshed before each search
    private var dictionaryMetadataCache: [UUID: DictionaryMetadata] = [:]

    public init(
        persistenceController: DictionaryPersistenceController = DictionaryPersistenceController.shared,
        audioLookupService: AudioLookupService? = nil
    ) {
        self.persistenceController = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        self.candidateGenerator = DictionaryCandidateGenerator()
        self.audioLookupService = audioLookupService
    }

    public func performSearch(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Refresh dictionary metadata before search
        try await refreshDictionaryMetadata()

        let candidates = candidateGenerator.generateCandidates(from: query)
        let results = try await fetchTerms(for: candidates)
        return results
    }

    /// Refresh dictionary metadata cache from Core Data
    private func refreshDictionaryMetadata() async throws {
        let cache = try await backgroundContext.perform {
            let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO")

            let dictionaries = try self.backgroundContext.fetch(fetchRequest)

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

        self.dictionaryMetadataCache = cache
    }

    private func getDisplayStyles() async throws -> DisplayStyles {
        try await backgroundContext.perform {
            let fetchRequest: NSFetchRequest<DictionaryDisplayPreferences> = DictionaryDisplayPreferences.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "enabled == %@", NSNumber(booleanLiteral: true))
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            fetchRequest.fetchLimit = 1

            let prefs = try self.backgroundContext.fetch(fetchRequest)

            if let pref = prefs.first {
                return DisplayStyles(
                    fontFamily: pref.fontFamily ?? DictionaryDisplayDefaults.defaultFontFamily,
                    contentFontSize: pref.fontSize,
                    popupFontSize: pref.popupFontSize,
                    showDeinflection: pref.showDeinflection,
                    pitchDownstepNotationInHeaderEnabled: pref.pitchDownstepNotationInHeaderEnabled,
                    pitchResultsAreaCollapsedDisplay: pref.pitchResultsAreaCollapsedDisplay,
                    pitchResultsAreaDownstepNotationEnabled: pref.pitchResultsAreaDownstepNotationEnabled,
                    pitchResultsAreaDownstepPositionEnabled: pref.pitchResultsAreaDownstepPositionEnabled,
                    pitchResultsAreaEnabled: pref.pitchResultsAreaEnabled
                )
            } else {
                let newPref = DictionaryDisplayPreferences(context: self.backgroundContext)
                newPref.id = UUID()
                newPref.enabled = true
                newPref.fontFamily = DictionaryDisplayDefaults.defaultFontFamily
                newPref.fontSize = DictionaryDisplayDefaults.defaultFontSize
                newPref.popupFontSize = DictionaryDisplayDefaults.defaultPopupFontSize
                newPref.showDeinflection = DictionaryDisplayDefaults.defaultShowDeinflection
                newPref.pitchDownstepNotationInHeaderEnabled = DictionaryDisplayDefaults.defaultPitchDownstepNotationInHeaderEnabled
                newPref.pitchResultsAreaCollapsedDisplay = DictionaryDisplayDefaults.defaultPitchResultsAreaCollapsedDisplay
                newPref.pitchResultsAreaDownstepNotationEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepNotationEnabled
                newPref.pitchResultsAreaDownstepPositionEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepPositionEnabled
                newPref.pitchResultsAreaEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaEnabled

                try self.backgroundContext.save()

                return DisplayStyles(
                    fontFamily: DictionaryDisplayDefaults.defaultFontFamily,
                    contentFontSize: DictionaryDisplayDefaults.defaultFontSize,
                    popupFontSize: DictionaryDisplayDefaults.defaultPopupFontSize,
                    showDeinflection: DictionaryDisplayDefaults.defaultShowDeinflection,
                    pitchDownstepNotationInHeaderEnabled: DictionaryDisplayDefaults.defaultPitchDownstepNotationInHeaderEnabled,
                    pitchResultsAreaCollapsedDisplay: DictionaryDisplayDefaults.defaultPitchResultsAreaCollapsedDisplay,
                    pitchResultsAreaDownstepNotationEnabled: DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepNotationEnabled,
                    pitchResultsAreaDownstepPositionEnabled: DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepPositionEnabled,
                    pitchResultsAreaEnabled: DictionaryDisplayDefaults.defaultPitchResultsAreaEnabled
                )
            }
        }
    }

    /// Perform a search and get the TextLookupResponse
    public func performTextLookup(query: TextLookupRequest) async throws -> TextLookupResponse? {
        // Get the text to query using the offset within context and the max lookup length
        var startIndex = query.context.index(query.context.startIndex, offsetBy: query.offset)
        let endIndex = query.context.index(startIndex, offsetBy: DictionarySearchService.maxForwardLookupLength, limitedBy: query.context.endIndex) ?? query.context.endIndex
        // If the query text begins with whitespace or punctuation, skip those characters
        while startIndex < endIndex, query.context[startIndex].isWhitespace || query.context[startIndex].isPunctuation {
            startIndex = query.context.index(after: startIndex)
        }
        let queryText = String(query.context[startIndex ..< endIndex])
        // If the query text is empty after trimming, return nil
        guard !queryText.isEmpty else {
            logger.debug("Skipping text lookup for empty query text")
            return nil
        }
        logger.debug("Performing text lookup for query: \(queryText)")
        logger.debug("Context: \(query.context), Offset: \(query.offset)")

        let results = try await performSearch(query: queryText)
        var groupedResults = DictionarySearchService.groupResults(results)
        guard !groupedResults.isEmpty else {
            return nil
        }

        // Enrich results with audio data if audio service is available
        if let audioService = audioLookupService {
            groupedResults = await enrichWithAudioResults(groupedResults, audioService: audioService)
        }

        let styles = try await getDisplayStyles()
        // Get the top ranked result
        let topResult = groupedResults.first?.dictionariesResults.first?.results.first
        let topTerm = topResult?.term ?? ""
        let topOriginalSubstring = topResult?.candidate.originalSubstring ?? ""

        // The range in context that was matched
        let matchedRange = startIndex ..< query.context.index(startIndex, offsetBy: topOriginalSubstring.count)
        logger.debug("Top term: \(topTerm), Matched range: \(matchedRange)")

        return TextLookupResponse(
            request: query,
            results: groupedResults,
            primaryResult: topTerm,
            primaryResultSourceRange: matchedRange,
            styles: styles
        )
    }

    static func groupResults(_ results: [SearchResult]) -> [GroupedSearchResults] {
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
                let combinedHTML = dictResults.generateCombinedHTML(dictionaryUUID: dictionaryUUID)
                return DictionaryResults(
                    dictionaryTitle: dictionaryTitle,
                    dictionaryUUID: dictionaryUUID,
                    sequence: sequence,
                    score: score,
                    results: dictResults,
                    combinedHTML: combinedHTML
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
            let deinflectionInfo = formatDeinflectionInfo(from: firstResult.deinflectionRules)

            return GroupedSearchResults(
                termKey: termKey,
                expression: firstResult.term,
                reading: firstResult.reading,
                dictionariesResults: dictionaryResults,
                pitchAccentResults: pitchAccentResults,
                termTags: mergedTermTags,
                deinflectionInfo: deinflectionInfo
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

    private func fetchTerms(for candidates: [LookupCandidate]) async throws -> [SearchResult] {
        guard !candidates.isEmpty else { return [] }

        let metadata = dictionaryMetadataCache

        return try await withCheckedThrowingContinuation { continuation in
            let context = backgroundContext
            context.perform {
                do {
                    let results = try TermFetcher.performFetch(
                        candidates: candidates,
                        dictionaryMetadata: metadata,
                        context: context
                    )
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Audio Enrichment

    /// Enrich grouped results with audio data
    private func enrichWithAudioResults(
        _ results: [GroupedSearchResults],
        audioService: AudioLookupService
    ) async -> [GroupedSearchResults] {
        // Create audio requests for each unique term+reading (without pitch filter to get all audio)
        let audioRequests = results.map { group in
            AudioLookupRequest(
                term: group.expression,
                reading: group.reading,
                downstepPosition: nil // Get all audio, filter client-side by pitch
            )
        }

        // Batch lookup all audio
        let audioResults = await audioService.lookupAudio(for: audioRequests)

        // Map audio results by term+reading key for efficient lookup
        var audioMap: [String: AudioLookupResult] = [:]
        for audioResult in audioResults {
            let key = "\(audioResult.request.term)|\(audioResult.request.reading ?? "")"
            audioMap[key] = audioResult
        }

        // Create new grouped results with audio attached
        return results.map { group in
            let key = "\(group.expression)|\(group.reading ?? "")"
            let audio = audioMap[key]

            let termAudio: TermAudioResults? = audio.map { result in
                TermAudioResults(
                    expression: group.expression,
                    reading: group.reading,
                    sources: result.sources
                )
            }

            return GroupedSearchResults(
                termKey: group.termKey,
                expression: group.expression,
                reading: group.reading,
                dictionariesResults: group.dictionariesResults,
                pitchAccentResults: group.pitchAccentResults,
                termTags: group.termTags,
                deinflectionInfo: group.deinflectionInfo,
                audioResults: termAudio
            )
        }
    }

    /// Format deinflection rules into a human-readable string
    private static func formatDeinflectionInfo(from rules: [[String]]) -> String? {
        guard !rules.isEmpty else { return nil }

        // Each inner array is a chain of rules that were applied
        // If there's only one chain with one rule, show it simply
        if rules.count == 1, let chain = rules.first {
            if chain.isEmpty {
                return nil
            } else if chain.count == 1 {
                return chain[0]
            } else {
                return chain.joined(separator: " \u{2192} ")
            }
        }

        // Multiple chains - show them as alternatives
        let chainDescriptions = rules.map { chain in
            chain.isEmpty ? "" : chain.joined(separator: " \u{2192} ")
        }.filter { !$0.isEmpty }

        return chainDescriptions.joined(separator: " | ")
    }
}
