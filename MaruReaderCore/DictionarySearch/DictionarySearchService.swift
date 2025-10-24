//
//  DictionarySearchService.swift
//  MaruReader
//
//  Service for performing dictionary searches and grouping results.
//

import CoreData
import Foundation
import os.log

/// Metadata for a dictionary used during search
struct DictionaryMetadata: Sendable {
    let id: UUID
    let title: String
    let termDisplayPriority: Int
    let termFrequencyDisplayPriority: Int
    let frequencyMode: String?
    let termResultsEnabled: Bool
    let termFrequencyEnabled: Bool
}

public actor DictionarySearchService {
    /// The maximum forward lookup length for the TextLookupRequest API
    static let maxForwardLookupLength = 10

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchService")

    private let persistenceController: DictionaryPersistenceController
    private let candidateGenerator: DictionaryCandidateGenerator
    private let backgroundContext: NSManagedObjectContext

    /// Cached dictionary metadata, refreshed before each search
    private var dictionaryMetadataCache: [UUID: DictionaryMetadata] = [:]

    public init(persistenceController: DictionaryPersistenceController = DictionaryPersistenceController.shared) {
        self.persistenceController = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        self.candidateGenerator = DictionaryCandidateGenerator()
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
            fetchRequest.predicate = NSPredicate(format: "isComplete == YES")

            let dictionaries = try self.backgroundContext.fetch(fetchRequest)

            var cache: [UUID: DictionaryMetadata] = [:]
            for dict in dictionaries {
                guard let id = dict.id else { continue }

                let metadata = DictionaryMetadata(
                    id: id,
                    title: dict.title ?? "",
                    termDisplayPriority: Int(dict.termDisplayPriority),
                    termFrequencyDisplayPriority: Int(dict.termFrequencyDisplayPriority),
                    frequencyMode: dict.frequencyMode,
                    termResultsEnabled: dict.termResultsEnabled,
                    termFrequencyEnabled: dict.termFrequencyEnabled
                )
                cache[id] = metadata
            }

            return cache
        }

        self.dictionaryMetadataCache = cache
    }

    /// Perform a search and get the TextLookupResponse
    public func performTextLookup(query: TextLookupRequest) async throws -> TextLookupResponse? {
        // Get the text to query using the offset within context and the max lookup length
        let startIndex = query.context.index(query.context.startIndex, offsetBy: query.offset)
        let endIndex = query.context.index(startIndex, offsetBy: DictionarySearchService.maxForwardLookupLength, limitedBy: query.context.endIndex) ?? query.context.endIndex
        let queryText = String(query.context[startIndex ..< endIndex])

        let results = try await performSearch(query: queryText)
        let groupedResults = DictionarySearchService.groupResults(results)
        guard !groupedResults.isEmpty else {
            return nil
        }
        // Get the top ranked result
        let topResult = groupedResults.first?.dictionariesResults.first?.results.first
        let topTerm = topResult?.term ?? ""
        let topOriginalSubstring = topResult?.candidate.originalSubstring ?? ""

        // The range in context that was matched
        let matchedRange = startIndex ..< query.context.index(startIndex, offsetBy: topOriginalSubstring.count)

        return TextLookupResponse(
            requestID: query.id,
            results: groupedResults,
            primaryResult: topTerm,
            primaryResultSourceRange: matchedRange,
            contextStartOffset: query.contextStartOffset,
            context: query.context
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

            // Format deinflection info from top result
            let deinflectionInfo = formatDeinflectionInfo(from: firstResult.deinflectionRules)

            return GroupedSearchResults(
                termKey: termKey,
                expression: firstResult.term,
                reading: firstResult.reading,
                dictionariesResults: dictionaryResults,
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
