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
enum TermFetcher {
    // MARK: - Public Methods

    /// Perform the actual Core Data fetch within the background context
    /// - Parameters:
    ///   - candidates: Array of LookupCandidate objects
    ///   - context: NSManagedObjectContext to perform the fetch in
    /// - Returns: Array of SearchResult structs
    static func performFetch(candidates: [LookupCandidate], context: NSManagedObjectContext) throws -> [SearchResult] {
        let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermFetcher")
        // Extract unique candidate texts for batch lookup
        let candidateTexts = Array(Set(candidates.map(\.text)))
        logger.debug("Fetching terms for candidates: \(candidateTexts, privacy: .public)")

        // Create fetch request for terms
        let fetchRequest: NSFetchRequest<Term> = Term.fetchRequest()

        // Batch lookup predicate
        fetchRequest.predicate = NSPredicate(format: "(expression IN %@) OR (reading IN %@)", candidateTexts, candidateTexts)

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
            let matchingCandidates = candidates.filter { $0.text == term.expression || $0.text == term.reading }
            logger.debug("Term '\(term.expression ?? "", privacy: .public)' matches candidates: \(matchingCandidates.map(\.text), privacy: .public)")

            for candidate in matchingCandidates {
                // Process each term entry - properly cast NSSet to Set<TermEntry>
                guard let entriesSet = term.entries as? Set<TermEntry> else {
                    logger.debug("No entries found for term '\(term.expression ?? "", privacy: .public)'")
                    continue
                }

                for entry in entriesSet {
                    // Skip disabled dictionaries
                    guard let dictionary = entry.dictionary,
                          dictionary.termResultsEnabled
                    else {
                        logger.debug("Skipping entry from disabled dictionary for term '\(term.expression ?? "", privacy: .public)'")
                        continue
                    }

                    let entryRules = Set(entry.rules as? [String] ?? [])

                    // Check if deinflection rules match
                    if !candidate.deinflectionOutputRules.isEmpty, !entryRules.isEmpty {
                        let candidateRules = Set(candidate.deinflectionOutputRules)

                        // Skip if no rule overlap (this entry doesn't match the deinflection)
                        if entryRules.isDisjoint(with: candidateRules) {
                            logger.debug("Skipping entry for term '\(term.expression ?? "", privacy: .public)' due to rule mismatch. Entry rules: \(entryRules, privacy: .public), Candidate rules: \(candidateRules, privacy: .public)")
                            continue
                        }
                    }

                    // Calculate frequency for ranking
                    let frequency = calculateFrequency(for: term)

                    // Extract term tags
                    let termTags: [Tag] = {
                        guard let richTermTagsSet = entry.richTermTags as? Set<DictionaryTagMeta> else {
                            return []
                        }
                        return richTermTagsSet.map { Tag(from: $0) }
                    }()

                    // Extract definition tags
                    let definitionTags: [Tag] = {
                        guard let richDefTagsSet = entry.richDefinitionTags as? Set<DictionaryTagMeta> else {
                            return []
                        }
                        return richDefTagsSet.map { Tag(from: $0) }
                    }()

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

                    logger.debug("Created SearchResult: term='\(term.expression ?? "", privacy: .public)', candidate='\(candidate.text, privacy: .public)', deinflectionChains=\(candidate.deinflectionInputRules.count), sourceLength=\(candidate.originalSubstring.count), termTags=\(termTags.count), defTags=\(definitionTags.count), sequence=\(entry.sequence)")

                    // Create SearchResult
                    let searchResult = SearchResult(
                        candidate: candidate,
                        term: term.expression ?? "",
                        reading: term.reading?.isEmpty == false ? term.reading : nil,
                        definitions: entry.glossary as? [Definition] ?? [],
                        frequency: frequency.value,
                        dictionaryTitle: dictionary.title ?? "",
                        dictionaryUUID: dictionary.id ?? UUID(),
                        displayPriority: Int(dictionary.termDisplayPriority),
                        rankingCriteria: rankingCriteria,
                        termTags: termTags,
                        definitionTags: definitionTags,
                        deinflectionRules: candidate.deinflectionInputRules,
                        sequence: entry.sequence,
                        score: entry.score
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
    static func calculateFrequency(for term: Term) -> (value: Double?, mode: String?) {
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
