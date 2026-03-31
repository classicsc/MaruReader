// TermFetcher.swift
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

/// Fetches terms from Core Data using batch queries and converts them to SearchResult structs
enum TermFetcher {
    private static let logger = Logger.maru(category: "TermFetcher")
    private static let exactPairFetchBatchSize = 200

    // MARK: - Public Methods

    /// Lightweight match phase: fetches term entries and ranking frequencies, validates
    /// deinflection chains, and returns sorted TermMatch objects without decompressing
    /// glossaries or fetching pitch accent/tag data.
    static func fetchMatches(
        candidates: [LookupCandidate],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext
    ) async throws -> [TermMatch] {
        let logger = Self.logger

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

        // Fetch only ranking-relevant frequencies (termFrequencyEnabled dictionaries)
        let termReadingKeys = Set(termEntries.map { Self.termReadingKey(expression: $0.expression, reading: $0.reading) })

        let frequencyMapValue = try await fetchFrequencyMap(
            termReadingKeys: termReadingKeys,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        // Build TermMatch objects — no glossary decompression, no pitch/tag fetches
        var matches: [TermMatch] = []

        for entry in termEntries {
            let expression = entry.expression
            let reading = entry.reading
            let dictionaryID = entry.dictionaryID

            let matchingCandidates = candidates.filter {
                $0.text == expression || $0.text == reading
            }

            for candidate in matchingCandidates {
                guard let dictMetadata = dictionaryMetadata[dictionaryID] else {
                    continue
                }

                guard let validatedChains = Self.validateDeinflectionChains(
                    candidate: candidate,
                    entryRulesRaw: entry.rules,
                    logger: logger,
                    expression: expression
                ) else {
                    continue
                }

                let key = Self.termReadingKey(expression: expression, reading: reading)
                let frequencies = frequencyMapValue[key] ?? []
                let rankFrequency = rankingFrequency(
                    from: frequencies,
                    dictionaryMetadata: dictionaryMetadata
                )

                let rankingCriteria = RankingCriteria(
                    candidate: candidate,
                    validatedDeinflectionChains: validatedChains,
                    term: expression,
                    termScore: entry.score,
                    definitionCount: entry.definitionCount,
                    frequency: (rankFrequency?.value, rankFrequency?.mode),
                    dictionaryTitle: dictMetadata.title,
                    dictionaryPriority: dictMetadata.termDisplayPriority
                )

                matches.append(TermMatch(
                    candidate: candidate,
                    term: expression,
                    reading: reading.isEmpty ? nil : reading,
                    glossaryData: entry.glossary,
                    definitionCount: entry.definitionCount,
                    rankingFrequency: rankFrequency,
                    dictionaryTitle: dictMetadata.title,
                    dictionaryUUID: dictionaryID,
                    displayPriority: dictMetadata.termDisplayPriority,
                    rankingCriteria: rankingCriteria,
                    termTagsRaw: entry.termTags,
                    definitionTagsRaw: entry.definitionTags,
                    deinflectionRules: validatedChains,
                    sequence: entry.sequence,
                    score: entry.score
                ))
            }
        }

        return matches.sorted { $0 > $1 }
    }

    static func rankingFrequency(
        from frequencies: [FrequencyInfo],
        dictionaryMetadata: [UUID: DictionaryMetadata]
    ) -> FrequencyInfo? {
        frequencies.first { frequency in
            dictionaryMetadata[frequency.dictionaryID]?.termFrequencyEnabled == true
        }
    }

    // MARK: - Materialization

    /// Materializes TermMatch objects into full SearchResult objects by decompressing
    /// glossaries and fetching pitch accent, tag, and full frequency data.
    static func materializeMatches(
        _ matches: [TermMatch],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        tagMetadataMap: [String: TagMetaData]? = nil
    ) async throws -> [SearchResult] {
        let logger = Self.logger

        guard !matches.isEmpty else { return [] }

        let enabledDictionaryIDs = Array(dictionaryMetadata.filter(\.value.termResultsEnabled).keys)
        let termReadingKeys = Set(matches.map { Self.termReadingKey(expression: $0.term, reading: $0.reading ?? "") })

        // Fetch auxiliary data in parallel
        async let frequencyMap = try fetchFrequencyMap(
            termReadingKeys: termReadingKeys,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        async let pitchAccentMap = try fetchPitchAccentMap(
            termReadingKeys: termReadingKeys,
            enabledDictionaryIDs: enabledDictionaryIDs,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            logger: logger
        )

        // Use cached tag metadata if provided, otherwise fetch
        async let fetchedTagMetadataMap = try {
            if let tagMetadataMap {
                return tagMetadataMap
            }
            return try await fetchTagMetadataMap(
                enabledDictionaryIDs: enabledDictionaryIDs,
                context: context,
                logger: logger
            )
        }()

        let frequencyMapValue = try await frequencyMap
        let pitchAccentMapValue = try await pitchAccentMap
        let tagMetadataMapValue = try await fetchedTagMetadataMap

        // Decompress glossaries and build SearchResults concurrently
        return await withTaskGroup(of: SearchResult?.self) { group in
            for match in matches {
                group.addTask {
                    guard let definitions = GlossaryCompressionCodec.decodeDefinitions(from: match.glossaryData) else {
                        logger.debug("Failed to decode glossary for term '\(match.term, privacy: .public)'")
                        return nil
                    }

                    let key = Self.termReadingKey(expression: match.term, reading: match.reading ?? "")
                    let frequencies = frequencyMapValue[key] ?? []
                    let pitchAccents = pitchAccentMapValue[key] ?? []

                    let termTags = buildTags(
                        tagNames: decodeStringArray(from: match.termTagsRaw) ?? [],
                        dictionaryID: match.dictionaryUUID,
                        tagMetadataMap: tagMetadataMapValue
                    )
                    let definitionTags = buildTags(
                        tagNames: decodeStringArray(from: match.definitionTagsRaw) ?? [],
                        dictionaryID: match.dictionaryUUID,
                        tagMetadataMap: tagMetadataMapValue
                    )

                    return SearchResult(
                        candidate: match.candidate,
                        term: match.term,
                        reading: match.reading,
                        definitions: definitions,
                        frequency: match.rankingFrequency?.value,
                        frequencies: frequencies,
                        pitchAccents: pitchAccents,
                        dictionaryTitle: match.dictionaryTitle,
                        dictionaryUUID: match.dictionaryUUID,
                        displayPriority: match.displayPriority,
                        rankingCriteria: match.rankingCriteria,
                        termTags: termTags,
                        definitionTags: definitionTags,
                        deinflectionRules: match.deinflectionRules,
                        sequence: match.sequence,
                        score: match.score
                    )
                }
            }

            var results: [SearchResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            // Preserve the original sort order
            return results.sorted { $0 > $1 }
        }
    }

    /// Materializes grouped term matches into full GroupedSearchResults.
    static func materializeGroupedMatches(
        _ groups: [GroupedTermMatches],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        deinflectionLanguage: DeinflectionLanguage = .en,
        tagMetadataMap: [String: TagMetaData]? = nil
    ) async throws -> [GroupedSearchResults] {
        let allMatches = groups.flatMap { $0.dictionaryMatches.flatMap(\.matches) }

        let searchResults = try await materializeMatches(
            allMatches,
            dictionaryMetadata: dictionaryMetadata,
            context: context,
            tagMetadataMap: tagMetadataMap
        )

        return DictionarySearchService.groupResults(searchResults, deinflectionLanguage: deinflectionLanguage)
    }

    // MARK: Intermediate result types

    struct TermEntryData {
        let expression: String
        let reading: String
        let dictionaryID: UUID
        let glossary: Data
        let definitionCount: Int
        let rules: String?
        let termTags: String?
        let definitionTags: String?
        let sequence: Int64
        let score: Double
    }

    struct TagMetaData {
        let name: String
        let notes: String
        let order: Double
        let score: Double
    }

    private struct TermReadingKey: Hashable {
        let expression: String
        let reading: String
    }

    // MARK: - Helper Methods

    /// Validates deinflection chains for a candidate against the dictionary entry's POS rules.
    /// Returns validated chains, or `nil` if the entry should be skipped entirely.
    static func validateDeinflectionChains(
        candidate: LookupCandidate,
        entryRulesRaw: String?,
        logger: Logger,
        expression: String
    ) -> [[String]]? {
        let entryRules = decodeStringArray(from: entryRulesRaw) ?? []

        let validatedChains: [[String]] = if entryRules.isEmpty {
            candidate.deinflectionInputRules
        } else {
            zip(candidate.deinflectionInputRules, candidate.deinflectionOutputRulesPerChain)
                .compactMap { inputChain, outputConditions in
                    if outputConditions.isEmpty { return inputChain }
                    if JapaneseDeinflector.conditionsMatch(
                        currentConditionStrings: outputConditions,
                        requiredConditionStrings: entryRules
                    ) {
                        return inputChain
                    }
                    return nil
                }
        }

        if validatedChains.isEmpty, !candidate.deinflectionInputRules.isEmpty {
            let allOutputRules = candidate.deinflectionOutputRulesPerChain.flatMap(\.self)
            if !allOutputRules.isEmpty {
                logger.debug("Skipping entry for term '\(expression, privacy: .public)' due to rule mismatch. Entry rules: \(entryRules, privacy: .public), Candidate output rules: \(allOutputRules, privacy: .public)")
                return nil
            }
        }

        return validatedChains
    }

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
                    definitionCount: Int(entry.definitionCount),
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
        termReadingKeys: Set<TermReadingKey>,
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        logger: Logger
    ) async throws -> [TermReadingKey: [FrequencyInfo]] {
        let frequencyDictionaryIDs = Array(dictionaryMetadata.keys)

        guard !frequencyDictionaryIDs.isEmpty, !termReadingKeys.isEmpty else {
            return [:]
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<TermFrequencyEntry> = TermFrequencyEntry.fetchRequest()
            var frequencyEntries: [TermFrequencyEntry] = []
            for batch in Self.chunked(Array(termReadingKeys), size: Self.exactPairFetchBatchSize) {
                fetchRequest.predicate = Self.exactPairPredicate(
                    termReadingKeys: batch,
                    dictionaryIDs: frequencyDictionaryIDs
                )
                try frequencyEntries.append(contentsOf: context.fetch(fetchRequest))
            }
            logger.debug("Found \(frequencyEntries.count) frequency entries")

            // Build map: expression+reading -> [FrequencyInfo] sorted by priority asc
            var frequencyMap: [TermReadingKey: [FrequencyInfo]] = [:]

            for entry in frequencyEntries {
                guard let expression = entry.expression,
                      let reading = entry.reading,
                      let dictionaryID = entry.dictionaryID,
                      let dictMetadata = dictionaryMetadata[dictionaryID]
                else {
                    continue
                }

                let key = Self.termReadingKey(expression: expression, reading: reading)
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
                frequencyMap[key, default: []].append(info)
            }

            for key in frequencyMap.keys {
                frequencyMap[key]?.sort { $0.priority < $1.priority }
            }

            return frequencyMap
        }
    }

    /// Fetch pitch accent data and build a lookup map
    private static func fetchPitchAccentMap(
        termReadingKeys: Set<TermReadingKey>,
        enabledDictionaryIDs _: [UUID],
        dictionaryMetadata: [UUID: DictionaryMetadata],
        context: NSManagedObjectContext,
        logger: Logger
    ) async throws -> [TermReadingKey: [PitchAccentResults]] {
        // Filter to only pitch-accent-enabled dictionaries
        let pitchEnabledIDs = dictionaryMetadata
            .filter(\.value.pitchAccentEnabled)
            .map(\.key)

        guard !pitchEnabledIDs.isEmpty, !termReadingKeys.isEmpty else {
            return [:]
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<PitchAccentEntry> = PitchAccentEntry.fetchRequest()
            var pitchEntries: [PitchAccentEntry] = []
            for batch in Self.chunked(Array(termReadingKeys), size: Self.exactPairFetchBatchSize) {
                fetchRequest.predicate = Self.exactPairPredicate(
                    termReadingKeys: batch,
                    dictionaryIDs: pitchEnabledIDs
                )
                try pitchEntries.append(contentsOf: context.fetch(fetchRequest))
            }
            logger.debug("Found \(pitchEntries.count) pitch accent entries")

            // Build map: expression+reading -> [PitchAccentResults] sorted by priority asc
            var pitchAccentMap: [TermReadingKey: [PitchAccentResults]] = [:]

            for entry in pitchEntries {
                guard let expression = entry.expression,
                      let reading = entry.reading,
                      let dictionaryID = entry.dictionaryID,
                      let dictMetadata = dictionaryMetadata[dictionaryID],
                      dictMetadata.pitchAccentEnabled,
                      let pitches = decodePitchAccents(from: entry.pitches)
                else {
                    continue
                }

                let key = Self.termReadingKey(expression: expression, reading: reading)
                let result = PitchAccentResults(
                    dictionaryTitle: dictMetadata.title,
                    dictionaryID: dictionaryID,
                    priority: dictMetadata.pitchDisplayPriority,
                    pitches: pitches
                )
                pitchAccentMap[key, default: []].append(result)
            }

            for key in pitchAccentMap.keys {
                pitchAccentMap[key]?.sort { $0.priority < $1.priority }
            }

            return pitchAccentMap
        }
    }

    /// Fetch tag metadata and build a lookup map
    static func fetchTagMetadataMap(
        enabledDictionaryIDs: [UUID],
        context: NSManagedObjectContext,
        logger: Logger? = nil
    ) async throws -> [String: TagMetaData] {
        let logger = logger ?? Self.logger
        return try await context.perform {
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

    private static func termReadingKey(expression: String, reading: String) -> TermReadingKey {
        TermReadingKey(expression: expression, reading: reading)
    }

    private static func exactPairPredicate(
        termReadingKeys: [TermReadingKey],
        dictionaryIDs: [UUID]
    ) -> NSPredicate {
        let pairPredicates = termReadingKeys.map { key in
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "expression == %@", key.expression),
                NSPredicate(format: "reading == %@", key.reading),
            ])
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "dictionaryID IN %@", dictionaryIDs),
            NSCompoundPredicate(orPredicateWithSubpredicates: pairPredicates),
        ])
    }

    private static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else {
            return []
        }

        var chunks: [[T]] = []
        chunks.reserveCapacity((items.count + size - 1) / size)

        var startIndex = 0
        while startIndex < items.count {
            let endIndex = min(startIndex + size, items.count)
            chunks.append(Array(items[startIndex ..< endIndex]))
            startIndex = endIndex
        }

        return chunks
    }
}
