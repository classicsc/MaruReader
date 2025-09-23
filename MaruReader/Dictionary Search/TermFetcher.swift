//
//  TermFetcher.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import CoreData
import Foundation

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
        // Extract unique candidate texts for batch lookup
        let candidateTexts = Array(Set(candidates.map(\.text)))

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

                    // Check if deinflection rules match
                    if !candidate.deinflectionOutputRules.isEmpty {
                        let entryRules = Set(entry.rules as? [String] ?? [])
                        let candidateRules = Set(candidate.deinflectionOutputRules)

                        // Skip if no rule overlap (this entry doesn't match the deinflection)
                        if entryRules.isDisjoint(with: candidateRules) {
                            continue
                        }
                    }

                    // Calculate frequency for ranking
                    let frequency = calculateFrequency(for: term)

                    // Calculate rank score
                    let rankScore = calculateRankScore(
                        candidate: candidate,
                        entry: entry,
                        frequency: frequency
                    )

                    // Create SearchResult
                    let searchResult = SearchResult(
                        candidate: candidate,
                        term: term.expression ?? "",
                        reading: term.reading?.isEmpty == false ? term.reading : nil,
                        definitions: entry.glossary as? [Definition] ?? [],
                        frequency: frequency,
                        dictionaryTitle: dictionary.title ?? "",
                        displayPriority: Int(dictionary.termDisplayPriority),
                        rankScore: rankScore
                    )

                    searchResults.append(searchResult)
                }
            }
        }

        // Sort by rank score (higher scores first)
        return searchResults.sorted { $0.rankScore > $1.rankScore }
    }

    /// Calculate frequency score for a term across all dictionaries
    /// - Parameter term: The term to calculate frequency for
    /// - Returns: Frequency value or nil if no frequency data available
    private static func calculateFrequency(for term: Term) -> Double? {
        guard let frequencySet = term.frequency as? Set<TermFrequencyEntry>,
              !frequencySet.isEmpty else { return nil }

        // Use the frequency from the highest priority enabled dictionary
        let enabledFrequencies = frequencySet.compactMap { entry -> (Double, Int64)? in
            guard let dictionary = entry.dictionary,
                  dictionary.termFrequencyEnabled else { return nil }
            return (entry.value, dictionary.termFrequencyDisplayPriority)
        }

        guard !enabledFrequencies.isEmpty else { return nil }

        // Return frequency from highest priority dictionary
        return enabledFrequencies.max { $0.1 < $1.1 }?.0
    }

    /// Calculate ranking score for search result ordering
    /// - Parameters:
    ///   - candidate: The lookup candidate that matched
    ///   - entry: The term entry from Core Data
    ///   - frequency: Calculated frequency value
    /// - Returns: Ranking score (higher = better)
    private static func calculateRankScore(
        candidate: LookupCandidate,
        entry: TermEntry,
        frequency: Double?
    ) -> Double {
        var score: Double = 0

        // Dictionary priority (higher priority = higher score)
        if let dictionary = entry.dictionary {
            score += Double(dictionary.termDisplayPriority) * 1000
        }

        // Entry score from dictionary
        score += entry.score

        // Frequency boost (log scale to prevent domination)
        if let freq = frequency, freq > 0 {
            score += log10(freq + 1) * 100
        }

        // Prefer exact matches (no deinflection)
        if candidate.deinflectionInputRules.isEmpty {
            score += 500
        } else {
            // Penalize based on number of deinflection steps
            let totalSteps = candidate.deinflectionInputRules.reduce(0) { $0 + $1.count }
            score -= Double(totalSteps) * 10
        }

        // Prefer shorter candidates (more specific matches)
        score -= Double(candidate.text.count) * 0.1

        return score
    }
}
