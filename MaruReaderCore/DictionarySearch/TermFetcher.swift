// TermFetcher.swift
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
        context: NSManagedObjectContext,
        decodeDefinitions: @escaping @Sendable (Data?) -> [Definition]? = GlossaryCompressionCodec.decodeDefinitions
    ) async throws -> [SearchResult] {
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
        let termEntries = try await fetchTermEntries(
            candidateTexts: candidateTexts,
            enabledDictionaryIDs: enabledDictionaryIDs,
            context: context,
            logger: logger
        )

        logger.debug("Found \(termEntries.count) term entries")

        // Build lookup maps for related data
        let expressions = Set(termEntries.compactMap(\.expression))
        let readings = Set(termEntries.compactMap(\.reading))

        async let frequencyMap = try fetchFrequencyMap(
            expressions: expressions,
            readings: readings,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        async let pitchAccentMap = try fetchPitchAccentMap(
            expressions: expressions,
            readings: readings,
            enabledDictionaryIDs: enabledDictionaryIDs,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        async let tagMetadataMap = try fetchTagMetadataMap(
            enabledDictionaryIDs: enabledDictionaryIDs,
            context: context,
            logger: logger
        )

        let frequencyMapValue = try await frequencyMap
        let pitchAccentMapValue = try await pitchAccentMap
        let tagMetadataMapValue = try await tagMetadataMap

        // Convert to SearchResult structs concurrently per entry
        let searchResults = await withTaskGroup(of: [SearchResult].self) { group in
            for entry in termEntries {
                group.addTask {
                    let expression = entry.expression
                    let reading = entry.reading
                    let dictionaryID = entry.dictionaryID

                    guard let definitions = decodeDefinitions(entry.glossary) else {
                        logger.debug("Failed to decode glossary for term '\(expression, privacy: .public)'")
                        return []
                    }

                    // Find matching candidates for this entry
                    let matchingCandidates = candidates.filter {
                        $0.text == expression || $0.text == reading
                    }
                    logger.debug("Entry '\(expression, privacy: .public)' matches candidates: \(matchingCandidates.map(\.text), privacy: .public)")

                    var entryResults: [SearchResult] = []

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

                        // Get frequencies for this term
                        let frequencyKey = "\(expression)|\(reading)"
                        let frequencies = frequencyMapValue[frequencyKey] ?? []
                        let rankingFrequency = rankingFrequency(
                            from: frequencies,
                            dictionaryMetadata: dictionaryMetadata
                        )

                        // Get pitch accents for this term
                        let pitchAccents = pitchAccentMapValue[frequencyKey] ?? []

                        // Build term tags
                        let termTagNames = decodeStringArray(from: entry.termTags) ?? []
                        let termTags = buildTags(
                            tagNames: termTagNames,
                            dictionaryID: dictionaryID,
                            tagMetadataMap: tagMetadataMapValue
                        )

                        // Build definition tags
                        let definitionTagNames = decodeStringArray(from: entry.definitionTags) ?? []
                        let definitionTags = buildTags(
                            tagNames: definitionTagNames,
                            dictionaryID: dictionaryID,
                            tagMetadataMap: tagMetadataMapValue
                        )

                        // Create ranking criteria using the selected ranking dictionary frequency.
                        let rankingCriteria = RankingCriteria(
                            candidate: candidate,
                            term: expression,
                            termScore: entry.score,
                            definitions: definitions,
                            frequency: (rankingFrequency?.value, rankingFrequency?.mode),
                            dictionaryTitle: dictMetadata.title,
                            dictionaryPriority: dictMetadata.termDisplayPriority
                        )

                        logger.debug("Created SearchResult: term='\(expression, privacy: .public)', candidate='\(candidate.text, privacy: .public)', deinflectionChains=\(candidate.deinflectionInputRules.count), sourceLength=\(candidate.originalSubstring.count), termTags=\(termTags.count), defTags=\(definitionTags.count), frequencies=\(frequencies.count), sequence=\(entry.sequence)")

                        // Create SearchResult
                        let searchResult = SearchResult(
                            candidate: candidate,
                            term: expression,
                            reading: reading.isEmpty ? nil : reading,
                            definitions: definitions,
                            frequency: rankingFrequency?.value,
                            frequencies: frequencies,
                            pitchAccents: pitchAccents,
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

                        entryResults.append(searchResult)
                    }

                    return entryResults
                }
            }

            var results: [SearchResult] = []
            for await entryResults in group {
                results.append(contentsOf: entryResults)
            }
            return results
        }

        // Sort by ranking criteria (best ranks first - reverse sort since we want higher ranking first)
        return searchResults.sorted { $0 > $1 }
    }

    static func rankingFrequency(
        from frequencies: [FrequencyInfo],
        dictionaryMetadata: [UUID: DictionaryMetadata]
    ) -> FrequencyInfo? {
        frequencies.first { frequency in
            dictionaryMetadata[frequency.dictionaryID]?.termFrequencyEnabled == true
        }
    }

    // MARK: Intermediate result types

    struct TermEntryData: Sendable {
        let expression: String
        let reading: String
        let dictionaryID: UUID
        let glossary: Data
        let rules: String?
        let termTags: String?
        let definitionTags: String?
        let sequence: Int64
        let score: Double
    }

    struct TagMetaData: Sendable {
        let name: String
        let notes: String
        let order: Double
        let score: Double
    }

    // MARK: - Helper Methods

    /// Fetch TermEntry entities matching the candidate texts
    private static func fetchTermEntries(
        candidateTexts: [String],
        enabledDictionaryIDs: [UUID],
        context: NSManagedObjectContext,
        logger _: Logger
    ) async throws -> [TermEntryData] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()

            // Fetch entries where expression or reading matches candidate text AND dictionary is enabled
            fetchRequest.predicate = NSPredicate(
                format: "(expression IN %@ OR reading IN %@) AND dictionaryID IN %@",
                candidateTexts,
                candidateTexts,
                enabledDictionaryIDs
            )
            let termEntries = try context.fetch(fetchRequest)
            return termEntries.compactMap { entry in
                guard let expression = entry.expression,
                      let reading = entry.reading,
                      let dictionaryID = entry.dictionaryID
                else {
                    return nil
                }

                let glossaryData: Data? = entry.glossary
                guard let glossary = glossaryData else {
                    return nil
                }

                return TermEntryData(
                    expression: expression,
                    reading: reading,
                    dictionaryID: dictionaryID,
                    glossary: glossary,
                    rules: entry.rules,
                    termTags: entry.termTags,
                    definitionTags: entry.definitionTags,
                    sequence: entry.sequence,
                    score: entry.score
                )
            }
        }
    }

    /// Fetch frequency data and build a lookup map
    private static func fetchFrequencyMap(
        expressions: Set<String>,
        readings: Set<String>,
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        logger: Logger
    ) async throws -> [String: [FrequencyInfo]] {
        let frequencyDictionaryIDs = Array(dictionaryMetadata.keys)

        guard !frequencyDictionaryIDs.isEmpty else {
            return [:]
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<TermFrequencyEntry> = TermFrequencyEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "expression IN %@ AND reading IN %@ AND dictionaryID IN %@",
                Array(expressions),
                Array(readings),
                frequencyDictionaryIDs
            )

            let frequencyEntries = try context.fetch(fetchRequest)
            logger.debug("Found \(frequencyEntries.count) frequency entries")

            // Build map: "expression|reading" -> [FrequencyInfo] sorted by priority asc
            var frequencyMap: [String: [FrequencyInfo]] = [:]

            // Group by expression+reading
            let grouped = Swift.Dictionary(grouping: frequencyEntries, by: { entry in
                guard let expression = entry.expression, let reading = entry.reading else {
                    return ""
                }
                return "\(expression)|\(reading)"
            })

            for (key, entries) in grouped {
                var freqInfos: [FrequencyInfo] = []
                for entry in entries {
                    guard let dictionaryID = entry.dictionaryID,
                          let dictMetadata = dictionaryMetadata[dictionaryID]
                    else {
                        continue
                    }
                    let value = entry.value
                    let displayValue = entry.displayValue?.isEmpty == false ? entry.displayValue : nil
                    let info = FrequencyInfo(
                        dictionaryID: dictionaryID,
                        dictionaryTitle: dictMetadata.title,
                        value: value,
                        displayValue: displayValue,
                        mode: dictMetadata.frequencyMode,
                        priority: dictMetadata.termFrequencyDisplayPriority
                    )
                    freqInfos.append(info)
                }
                // Sort by priority ascending (lower number = higher priority)
                freqInfos.sort { $0.priority < $1.priority }
                frequencyMap[key] = freqInfos
            }

            return frequencyMap
        }
    }

    /// Fetch pitch accent data and build a lookup map
    private static func fetchPitchAccentMap(
        expressions: Set<String>,
        readings: Set<String>,
        enabledDictionaryIDs _: [UUID],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        logger: Logger
    ) async throws -> [String: [PitchAccentResults]] {
        // Filter to only pitch-accent-enabled dictionaries
        let pitchEnabledIDs = dictionaryMetadata
            .filter(\.value.pitchAccentEnabled)
            .map(\.key)

        guard !pitchEnabledIDs.isEmpty else {
            return [:]
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<PitchAccentEntry> = PitchAccentEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "expression IN %@ AND reading IN %@ AND dictionaryID IN %@",
                Array(expressions),
                Array(readings),
                pitchEnabledIDs
            )

            let pitchEntries = try context.fetch(fetchRequest)
            logger.debug("Found \(pitchEntries.count) pitch accent entries")

            // Build map: "expression|reading" -> [PitchAccentResults] sorted by priority asc
            var pitchAccentMap: [String: [PitchAccentResults]] = [:]

            // Group by expression+reading
            let grouped = Swift.Dictionary(grouping: pitchEntries, by: { entry in
                guard let expression = entry.expression, let reading = entry.reading else {
                    return ""
                }
                return "\(expression)|\(reading)"
            })

            for (key, entries) in grouped {
                var pitchResults: [PitchAccentResults] = []
                for entry in entries {
                    guard let dictionaryID = entry.dictionaryID,
                          let dictMetadata = dictionaryMetadata[dictionaryID],
                          dictMetadata.pitchAccentEnabled,
                          let pitches = decodePitchAccents(from: entry.pitches)
                    else {
                        continue
                    }
                    let result = PitchAccentResults(
                        dictionaryTitle: dictMetadata.title,
                        dictionaryID: dictionaryID,
                        priority: dictMetadata.pitchDisplayPriority,
                        pitches: pitches
                    )
                    pitchResults.append(result)
                }
                // Sort by priority ascending (lower number = higher priority)
                pitchResults.sort { $0.priority < $1.priority }
                pitchAccentMap[key] = pitchResults
            }

            return pitchAccentMap
        }
    }

    /// Fetch tag metadata and build a lookup map
    private static func fetchTagMetadataMap(
        enabledDictionaryIDs: [UUID],
        context: NSManagedObjectContext,
        logger: Logger
    ) async throws -> [String: TagMetaData] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "dictionaryID IN %@", enabledDictionaryIDs)

            let tagMetadata = try context.fetch(fetchRequest)
            logger.debug("Found \(tagMetadata.count) tag metadata entries")

            // Build map: "dictionaryID|tagName" -> TagMetaData
            var tagMap: [String: TagMetaData] = [:]
            for meta in tagMetadata {
                guard let dictionaryID = meta.dictionaryID, let name = meta.name else {
                    continue
                }
                let key = "\(dictionaryID)|\(name)"
                tagMap[key] = TagMetaData(
                    name: name,
                    notes: meta.notes ?? "",
                    order: meta.order,
                    score: meta.score
                )
            }

            return tagMap
        }
    }

    /// Build Tag objects from tag names and metadata
    private static func buildTags(
        tagNames: [String],
        dictionaryID: UUID,
        tagMetadataMap: [String: TagMetaData]
    ) -> [Tag] {
        tagNames.compactMap { tagName in
            let key = "\(dictionaryID)|\(tagName)"
            if let meta = tagMetadataMap[key] {
                return Tag(name: meta.name, notes: meta.notes, order: meta.order, score: meta.score)
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

    /// Decode pitch accents from JSON string
    private static func decodePitchAccents(from jsonString: String?) -> [PitchAccent]? {
        guard let jsonString,
              let data = jsonString.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode([PitchAccent].self, from: data)
    }
}
