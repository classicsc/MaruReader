//
//  TermFetcher.swift
//  MaruReader
//
//  Optimized Core Data queries for dictionary search functionality.
//

import CoreData
import Foundation

/// Handles optimized Core Data queries for dictionary search operations
final class TermFetcher: Sendable {
    // MARK: - Properties

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    // MARK: - Initialization

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }

    /// Initialize with a specific context (useful for testing)
    init(context: NSManagedObjectContext, persistenceController: PersistenceController? = nil) {
        self.context = context
        self.persistenceController = persistenceController ?? .shared
    }

    // MARK: - Public Methods

    /// Fetch terms matching the given candidate texts
    /// - Parameters:
    ///   - candidates: Array of lookup candidates to search for
    ///   - includeDisabledDictionaries: Whether to include disabled dictionaries
    /// - Returns: Dictionary mapping candidate text to found terms with entries
    func fetchTerms(
        for candidates: [LookupCandidate],
        includeDisabledDictionaries: Bool = false
    ) async throws -> [String: [TermWithEntries]] {
        let candidateTexts = Set(candidates.map(\.text))

        return try await context.perform {
            var results: [String: [TermWithEntries]] = [:]

            // Batch fetch all matching terms
            let terms = try self.fetchTermsBatch(
                for: Array(candidateTexts),
                includeDisabledDictionaries: includeDisabledDictionaries
            )

            // Group terms by matching text
            for term in terms {
                let termDTO = TermDTO(from: term)

                // Check which candidate texts match this term
                let matchingTexts = candidateTexts.filter { candidateText in
                    candidateText == term.expression || candidateText == term.reading
                }

                // Fetch entries and frequency data for this term
                let entriesWithFrequency = try self.fetchTermEntries(
                    for: term,
                    includeDisabledDictionaries: includeDisabledDictionaries
                )

                let termWithEntries = TermWithEntries(
                    term: termDTO,
                    entries: entriesWithFrequency.entries,
                    frequencyEntries: entriesWithFrequency.frequencies
                )

                // Add to results for each matching text
                for text in matchingTexts {
                    if results[text] == nil {
                        results[text] = []
                    }
                    results[text]?.append(termWithEntries)
                }
            }

            return results
        }
    }

    /// Fetch terms for a single candidate text efficiently
    /// - Parameters:
    ///   - candidateText: The text to search for
    ///   - includeDisabledDictionaries: Whether to include disabled dictionaries
    /// - Returns: Array of terms with entries and frequency data
    func fetchTerms(
        for candidateText: String,
        includeDisabledDictionaries: Bool = false
    ) async throws -> [TermWithEntries] {
        try await context.perform {
            let terms = try self.fetchTermsBatch(
                for: [candidateText],
                includeDisabledDictionaries: includeDisabledDictionaries
            )

            var results: [TermWithEntries] = []

            for term in terms {
                let termDTO = TermDTO(from: term)

                // Check if this term matches the candidate text
                guard candidateText == term.expression || candidateText == term.reading else {
                    continue
                }

                let entriesWithFrequency = try self.fetchTermEntries(
                    for: term,
                    includeDisabledDictionaries: includeDisabledDictionaries
                )

                let termWithEntries = TermWithEntries(
                    term: termDTO,
                    entries: entriesWithFrequency.entries,
                    frequencyEntries: entriesWithFrequency.frequencies
                )

                results.append(termWithEntries)
            }

            return results
        }
    }

    /// Fetch enabled dictionaries for ranking context
    func fetchEnabledDictionaries() async throws -> [DictionaryDTO] {
        try await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "termResultsEnabled == true")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Dictionary.termDisplayPriority, ascending: false),
            ]

            let dictionaries = try self.context.fetch(request)
            return dictionaries.toDTOs()
        }
    }

    // MARK: - Private Methods

    /// Batch fetch terms matching the given texts
    private func fetchTermsBatch(
        for candidateTexts: [String],
        includeDisabledDictionaries: Bool
    ) throws -> [Term] {
        let request: NSFetchRequest<Term> = Term.fetchRequest()

        // Create predicate for expression or reading matches
        let expressionPredicate = NSPredicate(format: "expression IN %@", candidateTexts)
        let readingPredicate = NSPredicate(format: "reading IN %@", candidateTexts)
        let textMatchPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [expressionPredicate, readingPredicate]
        )

        // Filter for terms with entries
        let hasEntriesPredicate = NSPredicate(format: "entryCount > 0")

        var predicates = [textMatchPredicate, hasEntriesPredicate]

        // Optionally filter by enabled dictionaries
        if !includeDisabledDictionaries {
            let enabledDictionariesPredicate = NSPredicate(
                format: "ANY entries.dictionary.termResultsEnabled == true"
            )
            predicates.append(enabledDictionariesPredicate)
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // Optimize the query
        request.relationshipKeyPathsForPrefetching = ["entries", "entries.dictionary", "frequency"]
        request.returnsObjectsAsFaults = false

        return try context.fetch(request)
    }

    /// Fetch term entries and frequency data for a specific term
    private func fetchTermEntries(
        for term: Term,
        includeDisabledDictionaries: Bool
    ) throws -> (entries: [TermEntryDTO], frequencies: [TermFrequencyEntryDTO]) {
        // Fetch entries
        let entriesRequest: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()
        entriesRequest.predicate = NSPredicate(format: "term == %@", term)

        if !includeDisabledDictionaries {
            let enabledPredicate = NSPredicate(format: "dictionary.termResultsEnabled == true")
            let termPredicate = NSPredicate(format: "term == %@", term)
            entriesRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                termPredicate,
                enabledPredicate,
            ])
        }

        entriesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TermEntry.displayPriority, ascending: false),
        ]
        entriesRequest.relationshipKeyPathsForPrefetching = ["dictionary"]

        let entries = try context.fetch(entriesRequest)

        // Filter enabled entries
        let enabledEntries = entries.filter { entry in
            includeDisabledDictionaries || (entry.enabled == true)
        }

        // Fetch frequency entries
        let frequencyRequest: NSFetchRequest<TermFrequencyEntry> = TermFrequencyEntry.fetchRequest()
        frequencyRequest.predicate = NSPredicate(format: "term == %@", term)

        if !includeDisabledDictionaries {
            let enabledPredicate = NSPredicate(format: "dictionary.termFrequencyEnabled == true")
            let termPredicate = NSPredicate(format: "term == %@", term)
            frequencyRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                termPredicate,
                enabledPredicate,
            ])
        }

        frequencyRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TermFrequencyEntry.displayPriority, ascending: false),
        ]
        frequencyRequest.relationshipKeyPathsForPrefetching = ["dictionary"]

        let frequencies = try context.fetch(frequencyRequest)

        // Filter enabled frequencies
        let enabledFrequencies = frequencies.filter { frequency in
            includeDisabledDictionaries || (frequency.enabled == true)
        }

        return (
            entries: enabledEntries.toDTOs(),
            frequencies: enabledFrequencies.toDTOs()
        )
    }
}

// MARK: - Supporting Types

/// A term with its associated entries and frequency data
struct TermWithEntries: Sendable {
    let term: TermDTO
    let entries: [TermEntryDTO]
    let frequencyEntries: [TermFrequencyEntryDTO]

    /// Whether this term has any enabled entries
    var hasEnabledEntries: Bool {
        entries.contains { $0.enabled == true }
    }

    /// Get enabled entries sorted by display priority
    var enabledEntries: [TermEntryDTO] {
        entries
            .filter { $0.enabled == true }
            .sorted { ($0.displayPriority ?? 0) > ($1.displayPriority ?? 0) }
    }

    /// Get enabled frequency entries sorted by display priority
    var enabledFrequencyEntries: [TermFrequencyEntryDTO] {
        frequencyEntries
            .filter { $0.enabled == true }
            .sorted { ($0.displayPriority ?? 0) > ($1.displayPriority ?? 0) }
    }
}

// MARK: - Extensions

extension TermFetcher {
    /// Get statistics about database contents for debugging
    func getDatabaseStatistics() async throws -> (
        totalTerms: Int,
        totalEntries: Int,
        enabledDictionaries: Int
    ) {
        try await context.perform {
            let termsRequest: NSFetchRequest<Term> = Term.fetchRequest()
            let totalTerms = try self.context.count(for: termsRequest)

            let entriesRequest: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()
            let totalEntries = try self.context.count(for: entriesRequest)

            let dictionariesRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            dictionariesRequest.predicate = NSPredicate(format: "termResultsEnabled == true")
            let enabledDictionaries = try self.context.count(for: dictionariesRequest)

            return (
                totalTerms: totalTerms,
                totalEntries: totalEntries,
                enabledDictionaries: enabledDictionaries
            )
        }
    }
}
