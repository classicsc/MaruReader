//
//  TermFetcherTests.swift
//  MaruReaderTests
//
//  Unit tests for TermFetcher functionality using Swift Testing.
//

import CoreData
@testable import MaruReader
import Testing

@Suite("TermFetcher Tests")
struct TermFetcherTests {
    let persistenceController: PersistenceController
    let context: NSManagedObjectContext
    let termFetcher: TermFetcher

    init() async {
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        termFetcher = TermFetcher(context: context, persistenceController: persistenceController)

        // Create test data
        await createTestData()
    }

    // MARK: - Test Data Creation

    private func createTestData() async {
        do {
            try await context.perform {
                // Create test dictionary
                let dictionary = Dictionary(context: self.context)
                dictionary.id = UUID()
                dictionary.title = "Test Dictionary"
                dictionary.termResultsEnabled = true
                dictionary.termFrequencyEnabled = true
                dictionary.termDisplayPriority = 100
                dictionary.termFrequencyDisplayPriority = 100

                // Create disabled dictionary
                let disabledDictionary = Dictionary(context: self.context)
                disabledDictionary.id = UUID()
                disabledDictionary.title = "Disabled Dictionary"
                disabledDictionary.termResultsEnabled = false
                disabledDictionary.termFrequencyEnabled = false
                disabledDictionary.termDisplayPriority = 50

                // Create test terms
                let term1 = Term(context: self.context)
                term1.id = UUID()
                term1.expression = "食べる"
                term1.reading = "たべる"

                let term2 = Term(context: self.context)
                term2.id = UUID()
                term2.expression = "飲む"
                term2.reading = "のむ"

                let term3 = Term(context: self.context)
                term3.id = UUID()
                term3.expression = "本"
                term3.reading = "ほん"

                // Create term entries for enabled dictionary
                let entry1 = TermEntry(context: self.context)
                entry1.id = UUID()
                entry1.term = term1
                entry1.dictionary = dictionary
                entry1.score = 100
                entry1.sequence = 1
                entry1.setValue([Definition.text("to eat")], forKey: "glossary")
                entry1.setValue(["v1"], forKey: "rules")
                entry1.setValue(["common"], forKey: "termTags")
                entry1.setValue([], forKey: "definitionTags") // Required field

                let entry2 = TermEntry(context: self.context)
                entry2.id = UUID()
                entry2.term = term2
                entry2.dictionary = dictionary
                entry2.score = 95
                entry2.sequence = 2
                entry2.setValue([Definition.text("to drink")], forKey: "glossary")
                entry2.setValue(["v5m"], forKey: "rules")
                entry2.setValue(["common"], forKey: "termTags")
                entry2.setValue([], forKey: "definitionTags") // Required field

                let entry3 = TermEntry(context: self.context)
                entry3.id = UUID()
                entry3.term = term3
                entry3.dictionary = dictionary
                entry3.score = 98
                entry3.sequence = 3
                entry3.setValue([Definition.text("book"), Definition.text("main")], forKey: "glossary")
                entry3.setValue(["n"], forKey: "rules")
                entry3.setValue(["common"], forKey: "termTags")
                entry3.setValue([], forKey: "definitionTags") // Required field

                // Create entry for disabled dictionary
                let disabledEntry = TermEntry(context: self.context)
                disabledEntry.id = UUID()
                disabledEntry.term = term1
                disabledEntry.dictionary = disabledDictionary
                disabledEntry.score = 80
                disabledEntry.sequence = 4
                disabledEntry.setValue([Definition.text("to consume")], forKey: "glossary")
                disabledEntry.setValue(["v1"], forKey: "rules")
                disabledEntry.setValue([], forKey: "termTags") // Required field
                disabledEntry.setValue([], forKey: "definitionTags") // Required field

                // Create frequency entries
                let frequency1 = TermFrequencyEntry(context: self.context)
                frequency1.id = UUID()
                frequency1.term = term1
                frequency1.dictionary = dictionary
                frequency1.value = 5000
                frequency1.displayValue = "5000"

                let frequency2 = TermFrequencyEntry(context: self.context)
                frequency2.id = UUID()
                frequency2.term = term2
                frequency2.dictionary = dictionary
                frequency2.value = 4500
                frequency2.displayValue = "4500"

                // Save context
                try self.context.save()
            }
        } catch {
            fatalError("Failed to create test data: \(error)")
        }
    }

    // MARK: - Tests

    @Test("Fetch terms for single candidate by expression")
    func fetchTermsForSingleCandidate() async throws {
        let results = try await termFetcher.fetchTerms(for: "食べる", includeDisabledDictionaries: false)

        #expect(results.count == 1, "Should find exactly one term")

        let termWithEntries = try #require(results.first, "Should have at least one result")
        #expect(termWithEntries.term.expression == "食べる", "Expression should match search term")
        #expect(termWithEntries.term.reading == "たべる", "Reading should be たべる")
        #expect(termWithEntries.entries.count == 1, "Should have one enabled entry")
        #expect(termWithEntries.frequencyEntries.count == 1, "Should have one frequency entry")

        // Verify entry content in detail
        let entry = try #require(termWithEntries.entries.first, "Should have at least one entry")
        #expect(entry.score == 100, "Entry score should be 100")
        #expect(entry.enabled == true, "Entry should be enabled")
        #expect(entry.sequence == 1, "Entry sequence should be 1")
        #expect(entry.dictionaryTitle == "Test Dictionary", "Should be from Test Dictionary")
        #expect(!entry.glossary.isEmpty, "Entry should have glossary definitions")

        // Verify frequency content
        let frequency = try #require(termWithEntries.frequencyEntries.first, "Should have at least one frequency entry")
        #expect(frequency.value == 5000, "Frequency value should be 5000")
        #expect(frequency.displayValue == "5000", "Display value should be '5000'")
        #expect(frequency.enabled == true, "Frequency entry should be enabled")
    }

    @Test("Fetch terms by reading")
    func fetchTermsByReading() async throws {
        let results = try await termFetcher.fetchTerms(for: "たべる", includeDisabledDictionaries: false)

        #expect(results.count == 1, "Should find exactly one term when searching by reading")

        let termWithEntries = try #require(results.first, "Should have at least one result")
        #expect(termWithEntries.term.expression == "食べる", "Should find the same term as expression search")
        #expect(termWithEntries.term.reading == "たべる", "Reading should match search input")

        // Verify we get the same comprehensive data when searching by reading
        #expect(termWithEntries.entries.count == 1, "Should have same entries as expression search")
        #expect(termWithEntries.frequencyEntries.count == 1, "Should have same frequency data as expression search")
    }

    @Test("Fetch terms including disabled dictionaries")
    func fetchTermsIncludingDisabledDictionaries() async throws {
        // Test without disabled dictionaries
        let enabledResults = try await termFetcher.fetchTerms(for: "食べる", includeDisabledDictionaries: false)
        let enabledTerm = try #require(enabledResults.first, "Should have results from enabled dictionaries")
        #expect(enabledTerm.entries.count == 1, "Should have one enabled entry")

        let enabledEntry = try #require(enabledTerm.entries.first, "Should have an enabled entry")
        #expect(enabledEntry.dictionaryTitle == "Test Dictionary", "Should be from enabled dictionary")
        #expect(enabledEntry.score == 100, "Should have score from enabled dictionary")

        // Test with disabled dictionaries
        let allResults = try await termFetcher.fetchTerms(for: "食べる", includeDisabledDictionaries: true)
        let allTerm = try #require(allResults.first, "Should have results including disabled dictionaries")
        #expect(allTerm.entries.count == 2, "Should have both enabled and disabled entries")

        // Verify we have entries from both dictionaries
        let dictionaries = Set(allTerm.entries.compactMap(\.dictionaryTitle))
        #expect(dictionaries.contains("Test Dictionary"), "Should include enabled dictionary")
        #expect(dictionaries.contains("Disabled Dictionary"), "Should include disabled dictionary")

        // Verify scores are different (indicating different entries)
        let scores = allTerm.entries.map(\.score)
        #expect(scores.contains(100), "Should have entry with score 100 from enabled dictionary")
        #expect(scores.contains(80), "Should have entry with score 80 from disabled dictionary")
    }

    @Test("Fetch terms for multiple candidates")
    func fetchTermsForMultipleCandidates() async throws {
        let candidates = [
            LookupCandidate(from: "食べる"),
            LookupCandidate(from: "飲む"),
            LookupCandidate(from: "nonexistent"),
        ]

        let results = try await termFetcher.fetchTerms(for: candidates, includeDisabledDictionaries: false)

        #expect(results.keys.count == 2, "Should find results for two candidates")
        #expect(results["食べる"] != nil, "Should find results for 食べる")
        #expect(results["飲む"] != nil, "Should find results for 飲む")
        #expect(results["nonexistent"] == nil, "Should not find results for nonexistent term")

        // Verify specific content for each result
        let taberuResults = try #require(results["食べる"], "Should have results for 食べる")
        #expect(taberuResults.count == 1, "Should have exactly one result for 食べる")
        let taberuTerm = try #require(taberuResults.first, "Should have a term for 食べる")
        #expect(taberuTerm.term.expression == "食べる", "Expression should be 食べる")
        #expect(taberuTerm.term.reading == "たべる", "Reading should be たべる")

        let nomuResults = try #require(results["飲む"], "Should have results for 飲む")
        #expect(nomuResults.count == 1, "Should have exactly one result for 飲む")
        let nomuTerm = try #require(nomuResults.first, "Should have a term for 飲む")
        #expect(nomuTerm.term.expression == "飲む", "Expression should be 飲む")
        #expect(nomuTerm.term.reading == "のむ", "Reading should be のむ")

        // Verify different scores to ensure we're getting different terms
        #expect(taberuTerm.entries.first?.score != nomuTerm.entries.first?.score, "Different terms should have different scores")
    }

    @Test("Fetch terms with both expression and reading match")
    func fetchTermsWithBothExpressionAndReadingMatch() async throws {
        let candidates = [
            LookupCandidate(from: "食べる"), // matches expression
            LookupCandidate(from: "たべる"), // matches reading
        ]

        let results = try await termFetcher.fetchTerms(for: candidates, includeDisabledDictionaries: false)

        // Both candidates should return the same term
        #expect(results.keys.count == 2, "Should have results for both candidates")

        let expressionResult = try #require(results["食べる"]?.first, "Should have result for expression search")
        let readingResult = try #require(results["たべる"]?.first, "Should have result for reading search")

        // Verify both searches return the same underlying term
        #expect(expressionResult.term.expression == "食べる", "Expression search should return correct expression")
        #expect(readingResult.term.expression == "食べる", "Reading search should return same term")
        #expect(expressionResult.term.reading == "たべる", "Expression search should return correct reading")
        #expect(readingResult.term.reading == "たべる", "Reading search should return same reading")

        // Verify they have the same content (same term, same entries)
        #expect(expressionResult.term.id == readingResult.term.id, "Should be the same term entity")
        #expect(expressionResult.entries.count == readingResult.entries.count, "Should have same number of entries")
        #expect(expressionResult.frequencyEntries.count == readingResult.frequencyEntries.count, "Should have same frequency data")
    }

    @Test("Fetch enabled dictionaries")
    func fetchEnabledDictionaries() async throws {
        let dictionaries = try await termFetcher.fetchEnabledDictionaries()

        #expect(dictionaries.count == 1, "Should find exactly one enabled dictionary")
        #expect(dictionaries.first?.title == "Test Dictionary")
        #expect(dictionaries.first?.termResultsEnabled == true)
    }

    @Test("Get database statistics")
    func getDatabaseStatistics() async throws {
        let stats = try await termFetcher.getDatabaseStatistics()

        #expect(stats.totalTerms == 3, "Should have 3 terms")
        #expect(stats.totalEntries == 4, "Should have 4 entries (3 enabled + 1 disabled)")
        #expect(stats.enabledDictionaries == 1, "Should have 1 enabled dictionary")
    }

    @Test("TermWithEntries helper methods")
    func termWithEntriesHelperMethods() async throws {
        // Use actual data from the test database instead of mock data
        let results = try await termFetcher.fetchTerms(for: "食べる", includeDisabledDictionaries: true)
        let termWithEntries = try #require(results.first, "Should have at least one result")

        // Test helper methods with real data
        #expect(termWithEntries.hasEnabledEntries == true, "Should have enabled entries")
        #expect(termWithEntries.enabledEntries.count >= 1, "Should have at least one enabled entry")
        #expect(termWithEntries.enabledFrequencyEntries.count >= 1, "Should have at least one enabled frequency entry")

        // Verify enabled entries are actually enabled
        for entry in termWithEntries.enabledEntries {
            #expect(entry.enabled == true, "All enabled entries should have enabled=true")
        }

        // Verify enabled frequency entries are actually enabled
        for frequency in termWithEntries.enabledFrequencyEntries {
            #expect(frequency.enabled == true, "All enabled frequency entries should have enabled=true")
        }
    }
}
