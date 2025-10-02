//
//  DictionarySearchService.swift
//  MaruReader
//
//  Service for performing dictionary searches and grouping results.
//

import CoreData
import Foundation
import os.log

actor DictionarySearchService {
    /// The maximum forward lookup length for the TextLookupRequest API
    static let maxForwardLookupLength = 10

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchService")

    private let persistenceController: PersistenceController
    private let candidateGenerator: DictionaryCandidateGenerator
    private let backgroundContext: NSManagedObjectContext

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        self.candidateGenerator = DictionaryCandidateGenerator()
    }

    func performSearch(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let candidates = candidateGenerator.generateCandidates(from: query)
        let results = try await fetchTerms(for: candidates)
        return results
    }

    /// Perform a search and get the TextLookupResponse
    func performTextLookup(query: TextLookupRequest) async throws -> TextLookupResponse {
        // Get the text to query using the offset within context and the max lookup length
        let startIndex = query.context.index(query.context.startIndex, offsetBy: query.offset)
        let endIndex = query.context.index(startIndex, offsetBy: DictionarySearchService.maxForwardLookupLength, limitedBy: query.context.endIndex) ?? query.context.endIndex
        let queryText = String(query.context[startIndex ..< endIndex])

        let results = try await performSearch(query: queryText)
        let groupedResults = DictionarySearchService.groupResults(results)
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
            primaryResultSourceRange: matchedRange
        )
    }

    static func groupResults(_ results: [SearchResult]) -> [GroupedSearchResults] {
        let grouped = Swift.Dictionary(grouping: results, by: { result in
            "\(result.term)|\(result.reading ?? "")"
        })

        return grouped.map { termKey, termResults in
            let firstResult = termResults.first!
            let dictionaryGroups = Swift.Dictionary(grouping: termResults, by: { $0.dictionaryUUID })

            let dictionaryResults = dictionaryGroups.map { dictionaryUUID, dictResults in
                let dictionaryTitle = dictResults.first?.dictionaryTitle ?? "Unknown Dictionary"
                let combinedHTML = dictResults.generateCombinedHTML(dictionaryUUID: dictionaryUUID)
                return DictionaryResults(
                    dictionaryTitle: dictionaryTitle,
                    dictionaryUUID: dictionaryUUID,
                    results: dictResults,
                    combinedHTML: combinedHTML
                )
            }.sorted { lhs, rhs in
                let lhsPriority = lhs.results.first?.displayPriority ?? 0
                let rhsPriority = rhs.results.first?.displayPriority ?? 0
                return lhsPriority < rhsPriority
            }

            return GroupedSearchResults(
                termKey: termKey,
                expression: firstResult.term,
                reading: firstResult.reading,
                dictionariesResults: dictionaryResults
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

        return try await withCheckedThrowingContinuation { continuation in
            let context = backgroundContext
            context.perform {
                do {
                    let results = try TermFetcher.performFetch(candidates: candidates, context: context)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
