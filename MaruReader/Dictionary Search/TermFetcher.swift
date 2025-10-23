//
//  TermFetcher.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import CoreData
import Foundation
import MaruReaderCore
import os.log

/// Fetches terms from Core Data using batch queries and converts them to SearchResult structs
enum TermFetcher {
    // MARK: - Public Methods

    /// Perform the actual Core Data fetch within the background context
    /// - Parameters:
    ///   - candidates: Array of LookupCandidate objects
    ///   - dictionaryMetadata: Dictionary metadata for filtering and ranking
    ///   - context: NSManagedObjectContext to perform the fetch in
    /// - Returns: Array of SearchResult structs
    static func performFetch(
        candidates: [LookupCandidate],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext
    ) throws -> [SearchResult] {
        let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermFetcher")

        // Extract unique candidate texts for batch lookup
        let candidateTexts = Array(Set(candidates.map(\.text)))
        logger.debug("Fetching terms for candidates: \(candidateTexts, privacy: .public)")

        // Filter to only enabled dictionaries
        let enabledDictionaries = dictionaryMetadata.filter(\.value.termResultsEnabled)
        let enabledDictionaryIDs = Array(enabledDictionaries.keys)

        guard !enabledDictionaryIDs.isEmpty else {
            logger.debug("No enabled dictionaries found")
            return []
        }

        // Fetch TermEntry entities
        let termEntries = try fetchTermEntries(
            candidateTexts: candidateTexts,
            enabledDictionaryIDs: enabledDictionaryIDs,
            context: context,
            logger: logger
        )

        logger.debug("Found \(termEntries.count) term entries")

        // Build lookup maps for related data
        let expressions = Set(termEntries.compactMap(\.expression))
        let readings = Set(termEntries.compactMap(\.reading))

        let frequencyMap = try fetchFrequencyMap(
            expressions: expressions,
            readings: readings,
            enabledDictionaryIDs: enabledDictionaryIDs,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        let tagMetadataMap = try fetchTagMetadataMap(
            enabledDictionaryIDs: enabledDictionaryIDs,
            context: context,
            logger: logger
        )

        // Convert to SearchResult structs
        var searchResults: [SearchResult] = []

        for entry in termEntries {
            guard let expression = entry.expression,
                  let reading = entry.reading,
                  let dictionaryID = entry.dictionaryID
            else {
                continue
            }

            // Find matching candidates for this entry
            let matchingCandidates = candidates.filter {
                $0.text == expression || $0.text == reading
            }
            logger.debug("Entry '\(expression, privacy: .public)' matches candidates: \(matchingCandidates.map(\.text), privacy: .public)")

            for candidate in matchingCandidates {
                // Get dictionary metadata
                guard let dictMetadata = dictionaryMetadata[dictionaryID] else {
                    logger.debug("No metadata found for dictionary ID \(dictionaryID)")
                    continue
                }

                // Check if deinflection rules match
                let entryRules = decodeStringArray(from: entry.rules) ?? []
                if !candidate.deinflectionOutputRules.isEmpty, !entryRules.isEmpty {
                    let candidateRules = Set(candidate.deinflectionOutputRules)
                    let entryRulesSet = Set(entryRules)

                    // Skip if no rule overlap
                    if entryRulesSet.isDisjoint(with: candidateRules) {
                        logger.debug("Skipping entry for term '\(expression, privacy: .public)' due to rule mismatch. Entry rules: \(entryRulesSet, privacy: .public), Candidate rules: \(candidateRules, privacy: .public)")
                        continue
                    }
                }

                // Decode glossary
                guard let definitions = decodeDefinitions(from: entry.glossary) else {
                    logger.debug("Failed to decode glossary for term '\(expression, privacy: .public)'")
                    continue
                }

                // Get frequency for this term
                let frequencyKey = "\(expression)|\(reading)"
                let frequency = frequencyMap[frequencyKey] ?? (nil, nil)

                // Build term tags
                let termTagNames = decodeStringArray(from: entry.termTags) ?? []
                let termTags = buildTags(
                    tagNames: termTagNames,
                    dictionaryID: dictionaryID,
                    tagMetadataMap: tagMetadataMap
                )

                // Build definition tags
                let definitionTagNames = decodeStringArray(from: entry.definitionTags) ?? []
                let definitionTags = buildTags(
                    tagNames: definitionTagNames,
                    dictionaryID: dictionaryID,
                    tagMetadataMap: tagMetadataMap
                )

                // Create ranking criteria
                let rankingCriteria = RankingCriteria(
                    candidate: candidate,
                    term: expression,
                    entry: entry,
                    definitions: definitions,
                    frequency: frequency,
                    dictionaryTitle: dictMetadata.title,
                    dictionaryPriority: dictMetadata.termDisplayPriority
                )

                logger.debug("Created SearchResult: term='\(expression, privacy: .public)', candidate='\(candidate.text, privacy: .public)', deinflectionChains=\(candidate.deinflectionInputRules.count), sourceLength=\(candidate.originalSubstring.count), termTags=\(termTags.count), defTags=\(definitionTags.count), sequence=\(entry.sequence)")

                // Create SearchResult
                let searchResult = SearchResult(
                    candidate: candidate,
                    term: expression,
                    reading: reading.isEmpty ? nil : reading,
                    definitions: definitions,
                    frequency: frequency.value,
                    dictionaryTitle: dictMetadata.title,
                    dictionaryUUID: dictionaryID,
                    displayPriority: dictMetadata.termDisplayPriority,
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

        // Sort by ranking criteria (best ranks first - reverse sort since we want higher ranking first)
        return searchResults.sorted { $0 > $1 }
    }

    // MARK: - Helper Methods

    /// Fetch TermEntry entities matching the candidate texts
    private static func fetchTermEntries(
        candidateTexts: [String],
        enabledDictionaryIDs: [UUID],
        context: NSManagedObjectContext,
        logger _: Logger
    ) throws -> [TermEntry] {
        let fetchRequest: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()

        // Fetch entries where expression or reading matches candidate text AND dictionary is enabled
        fetchRequest.predicate = NSPredicate(
            format: "(expression IN %@ OR reading IN %@) AND dictionaryID IN %@",
            candidateTexts,
            candidateTexts,
            enabledDictionaryIDs
        )

        return try context.fetch(fetchRequest)
    }

    /// Fetch frequency data and build a lookup map
    private static func fetchFrequencyMap(
        expressions: Set<String>,
        readings: Set<String>,
        enabledDictionaryIDs _: [UUID],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        logger: Logger
    ) throws -> [String: (value: Double?, mode: String?)] {
        // Filter to only frequency-enabled dictionaries
        let frequencyEnabledIDs = dictionaryMetadata
            .filter(\.value.termFrequencyEnabled)
            .map(\.key)

        guard !frequencyEnabledIDs.isEmpty else {
            return [:]
        }

        let fetchRequest: NSFetchRequest<TermFrequencyEntry> = TermFrequencyEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "expression IN %@ AND reading IN %@ AND dictionaryID IN %@",
            Array(expressions),
            Array(readings),
            frequencyEnabledIDs
        )

        let frequencyEntries = try context.fetch(fetchRequest)
        logger.debug("Found \(frequencyEntries.count) frequency entries")

        // Build map: "expression|reading" -> best frequency
        var frequencyMap: [String: (value: Double?, mode: String?)] = [:]

        // Group by expression+reading
        let grouped = [String: [TermFrequencyEntry]](grouping: frequencyEntries) { entry in
            guard let expression = entry.expression, let reading = entry.reading else {
                return ""
            }
            return "\(expression)|\(reading)"
        }

        for (key, entries) in grouped {
            // Get frequency from highest priority dictionary
            let bestFrequency = entries.compactMap { entry -> (Double, Int, String?)? in
                guard let dictionaryID = entry.dictionaryID,
                      let dictMetadata = dictionaryMetadata[dictionaryID],
                      dictMetadata.termFrequencyEnabled
                else {
                    return nil
                }
                return (entry.value, dictMetadata.termFrequencyDisplayPriority, dictMetadata.frequencyMode)
            }
            .min { $0.1 < $1.1 } // Lower priority number is higher priority

            if let best = bestFrequency {
                frequencyMap[key] = (best.0, best.2)
            }
        }

        return frequencyMap
    }

    /// Fetch tag metadata and build a lookup map
    private static func fetchTagMetadataMap(
        enabledDictionaryIDs: [UUID],
        context: NSManagedObjectContext,
        logger: Logger
    ) throws -> [String: DictionaryTagMeta] {
        let fetchRequest: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dictionaryID IN %@", enabledDictionaryIDs)

        let tagMetadata = try context.fetch(fetchRequest)
        logger.debug("Found \(tagMetadata.count) tag metadata entries")

        // Build map: "dictionaryID|tagName" -> DictionaryTagMeta
        var tagMap: [String: DictionaryTagMeta] = [:]
        for meta in tagMetadata {
            guard let dictionaryID = meta.dictionaryID, let name = meta.name else {
                continue
            }
            let key = "\(dictionaryID)|\(name)"
            tagMap[key] = meta
        }

        return tagMap
    }

    /// Build Tag objects from tag names and metadata
    private static func buildTags(
        tagNames: [String],
        dictionaryID: UUID,
        tagMetadataMap: [String: DictionaryTagMeta]
    ) -> [Tag] {
        tagNames.compactMap { tagName in
            let key = "\(dictionaryID)|\(tagName)"
            if let meta = tagMetadataMap[key] {
                return Tag(from: meta)
            } else {
                // Create a basic tag if metadata not found
                return Tag(name: tagName)
            }
        }
    }

    /// Decode a JSON string array
    private static func decodeStringArray(from jsonString: String?) -> [String]? {
        guard let jsonString,
              let data = jsonString.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode([String].self, from: data)
    }

    /// Decode definitions from JSON string
    private static func decodeDefinitions(from jsonString: String?) -> [Definition]? {
        guard let jsonString,
              let data = jsonString.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode([Definition].self, from: data)
    }
}
