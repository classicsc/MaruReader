//
//  TermFetcher.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import CoreData
import Foundation
import os.log

/// Fetches terms from Core Data using batch queries and converts them to SearchResult structs
class TermFetcher {
    // MARK: - Properties

    private let backgroundContext: NSManagedObjectContext

    // MARK: - Initialization

    /// Initialize with a background Core Data context
    /// - Parameter backgroundContext: NSManagedObjectContext with privateQueueConcurrencyType
    init(backgroundContext: NSManagedObjectContext) {
        self.backgroundContext = backgroundContext
    }

    // MARK: - Public Methods

    /// Fetch terms matching the given candidates
    /// - Parameter candidates: Array of LookupCandidate objects to search for
    /// - Returns: Array of SearchResult structs
    func fetchTerms(for candidates: [LookupCandidate]) async throws -> [SearchResult] {
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

    // MARK: - Private Methods

    /// Perform the actual Core Data fetch within the background context
    /// - Parameters:
    ///   - candidates: Array of LookupCandidate objects
    ///   - context: NSManagedObjectContext to perform the fetch in
    /// - Returns: Array of SearchResult structs
    private static func performFetch(candidates: [LookupCandidate], context: NSManagedObjectContext) throws -> [SearchResult] {
        let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermFetcher")
        // Extract unique candidate texts for batch lookup
        let candidateTexts = Array(Set(candidates.map(\.text)))
        logger.debug("Fetching terms for candidates: \(candidateTexts, privacy: .public)")

        // Create fetch request for terms
        let fetchRequest: NSFetchRequest<Term> = Term.fetchRequest()

        // Batch lookup predicate
        fetchRequest.predicate = NSPredicate(format: "expression IN %@", candidateTexts)

        // Prefetch relationships to minimize database round trips
        fetchRequest.relationshipKeyPathsForPrefetching = [
            "entries",
            "entries.dictionary",
            "entries.richTermTags",
            "entries.richDefinitionTags",
            "frequency",
            "frequency.dictionary",
            "ipa",
            "ipa.dictionary",
            "pitches",
            "pitches.dictionary",
        ]

        // Fetch terms
        let terms = try context.fetch(fetchRequest)

        // Convert to SearchResult structs immediately to avoid threading violations
        var searchResults: [SearchResult] = []

        for term in terms {
            // Find matching candidates for this term
            let matchingCandidates = candidates.filter { $0.text == term.expression }

            for candidate in matchingCandidates {
                // Process each term entry - properly cast NSSet to Set<TermEntry>
                guard let entriesSet = term.entries as? Set<TermEntry> else { continue }

                for entry in entriesSet {
                    // Skip disabled dictionaries
                    guard let dictionary = entry.dictionary,
                          dictionary.termResultsEnabled else { continue }

                    let entryRules = Set(entry.rules as? [String] ?? [])

                    // Check if deinflection rules match
                    if !candidate.deinflectionOutputRules.isEmpty, !entryRules.isEmpty {
                        let entryRules = Set(entry.rules as? [String] ?? [])
                        let candidateRules = Set(candidate.deinflectionOutputRules)

                        // Skip if no rule overlap (this entry doesn't match the deinflection)
                        if entryRules.isDisjoint(with: candidateRules) {
                            continue
                        }
                    }

                    // Calculate frequency for ranking
                    let frequency = calculateFrequency(for: term)

                    // Create ranking criteria
                    let rankingCriteria = RankingCriteria(
                        candidate: candidate,
                        term: term.expression ?? "",
                        entry: entry,
                        definitions: entry.glossary as? [Definition] ?? [],
                        frequency: frequency,
                        dictionaryTitle: dictionary.title ?? "",
                        dictionaryPriority: Int(dictionary.termDisplayPriority)
                    )

                    // Create SearchResult
                    let searchResult = SearchResult(
                        candidate: candidate,
                        term: term.expression ?? "",
                        reading: term.reading?.isEmpty == false ? term.reading : nil,
                        definitions: entry.glossary as? [Definition] ?? [],
                        frequency: frequency.value,
                        dictionaryTitle: dictionary.title ?? "",
                        displayPriority: Int(dictionary.termDisplayPriority),
                        rankingCriteria: rankingCriteria
                    )

                    searchResults.append(searchResult)
                }
            }
        }

        // Sort by ranking criteria (best ranks first - reverse sort since we want higher ranking first)
        return searchResults.sorted { $0 > $1 }
    }

    /// Calculate frequency score for a term across all dictionaries
    /// - Parameter term: The term to calculate frequency for
    /// - Returns: Tuple containing frequency value and mode, or (nil, nil) if no frequency data available
    private static func calculateFrequency(for term: Term) -> (value: Double?, mode: String?) {
        guard let frequencySet = term.frequency as? Set<TermFrequencyEntry>,
              !frequencySet.isEmpty else { return (nil, nil) }

        // Use the frequency from the highest priority enabled dictionary
        let enabledFrequencies = frequencySet.compactMap { entry -> (Double, Int64, String?)? in
            guard let dictionary = entry.dictionary,
                  dictionary.termFrequencyEnabled else { return nil }
            return (entry.value, dictionary.termFrequencyDisplayPriority, dictionary.frequencyMode)
        }

        guard !enabledFrequencies.isEmpty else { return (nil, nil) }

        // Return frequency and mode from highest priority dictionary
        if let bestFrequency = enabledFrequencies.max(by: { $0.1 < $1.1 }) {
            return (bestFrequency.0, bestFrequency.2)
        }

        return (nil, nil)
    }
}
