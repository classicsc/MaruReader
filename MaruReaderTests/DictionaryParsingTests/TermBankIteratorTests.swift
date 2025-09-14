//
//  TermBankIteratorTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
@testable import MaruReader
import Testing

struct TermBankIteratorTests {
    @Test func termBankIterator_V3Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V3 format data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            ["飲む", "のむ", "v5m", "B", 95, ["to drink"], 2, "common"],
            ["走る", "はしる", "v5r", "C", 90, ["to run"], 3, "common"]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [tempURL],
            dataFormat: 3,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        for try await term in iterator {
            terms.append(term)
        }

        #expect(terms.count == 3)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        #expect(terms[0].definitionTags == ["v1"])
        #expect(terms[0].rules == "A")
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == 1)
        #expect(terms[0].termTags == ["common"])
        #expect(terms[0].dictionary == dictionaryURI)

        // Check second term
        #expect(terms[1].expression == "飲む")
        #expect(terms[1].reading == "のむ")
        #expect(terms[1].definitionTags == ["v5m"])
        #expect(terms[1].rules == "B")
        #expect(terms[1].score == 95)
        #expect(terms[1].sequence == 2)

        // Check third term
        #expect(terms[2].expression == "走る")
        #expect(terms[2].reading == "はしる")
        #expect(terms[2].definitionTags == ["v5r"])
        #expect(terms[2].rules == "C")
        #expect(terms[2].score == 90)
        #expect(terms[2].sequence == 3)
    }

    @Test func termBankIterator_V1Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V1 format data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, "to eat", "to consume food"],
            ["飲む", "のむ", "v5m", "B", 95, "to drink"],
            ["走る", "はしる", "v5r", "C", 90, "to run", "to move quickly on foot"]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v1.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [tempURL],
            dataFormat: 1,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        for try await term in iterator {
            terms.append(term)
        }

        #expect(terms.count == 3)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        #expect(terms[0].definitionTags == ["v1"])
        #expect(terms[0].rules == "A")
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == nil)
        #expect(terms[0].termTags == nil)
        #expect(terms[0].dictionary == dictionaryURI)
        #expect(terms[0].glossary.count == 2)

        // Check second term (single definition)
        #expect(terms[1].expression == "飲む")
        #expect(terms[1].glossary.count == 1)

        // Check third term (multiple definitions)
        #expect(terms[2].expression == "走る")
        #expect(terms[2].glossary.count == 2)
    }

    @Test func termBankIterator_MultipleFiles_StreamsAllTerms() async throws {
        // Create multiple temporary test files
        let jsonString1 = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            ["飲む", "のむ", "v5m", "B", 95, ["to drink"], 2, "common"]
        ]
        """

        let jsonString2 = """
        [
            ["走る", "はしる", "v5r", "C", 90, ["to run"], 3, "common"],
            ["歩く", "あるく", "v5k", "D", 85, ["to walk"], 4, "common"]
        ]
        """

        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_2.json")
        try jsonString1.write(to: tempURL1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: tempURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }

        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [tempURL1, tempURL2],
            dataFormat: 3,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        for try await term in iterator {
            terms.append(term)
        }

        #expect(terms.count == 4)
        #expect(terms[0].expression == "食べる")
        #expect(terms[1].expression == "飲む")
        #expect(terms[2].expression == "走る")
        #expect(terms[3].expression == "歩く")
    }

    @Test func termBankIterator_InvalidData_ThrowsError() async throws {
        // Create a temporary test file with invalid data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            {"invalid": "object"}
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_throwing.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [tempURL],
            dataFormat: 3,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        var errorOccurred = false

        do {
            for try await term in iterator {
                terms.append(term)
            }
        } catch {
            errorOccurred = true
        }

        #expect(errorOccurred)
        #expect(terms.count == 1) // Should have parsed the first valid term
    }

    @Test func termBankIterator_EmptyFiles_ReturnsNoTerms() async throws {
        // Create an empty JSON array file
        let jsonString = "[]"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_empty.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [tempURL],
            dataFormat: 3,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        for try await term in iterator {
            terms.append(term)
        }

        #expect(terms.count == 0)
    }

    @Test func termBankIterator_NoFiles_ReturnsNoTerms() async throws {
        let dictionaryURI = URL(string: "dict://test-dictionary")!
        let iterator = TermBankIterator(
            termBankURLs: [],
            dataFormat: 3,
            dictionaryURI: dictionaryURI
        )

        var terms: [ParsedTerm] = []
        for try await term in iterator {
            terms.append(term)
        }

        #expect(terms.count == 0)
    }
}
