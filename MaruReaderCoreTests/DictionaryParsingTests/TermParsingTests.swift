//
//  TermParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation
@testable import MaruReaderCore
import Testing

struct TermParsingTests {
    @Test func termBankV3Entry_ValidArray_ReturnsParsedTermArray() throws {
        // Purpose: Ensure term_bank JSON is parsed into [TermBankV3Entry].
        // Input: Sample term row with basic glossary.
        // Expected: TermBankV3Entry with expression, reading (nil if empty), glossary.
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let terms = try decoder.decode([TermBankV3Entry].self, from: data)

        #expect(terms.count == 1)
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        #expect(terms[0].definitionTags == ["v1"])
        #expect(terms[0].rules == ["A"])
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == 1)
        #expect(terms[0].termTags == ["common"])
        switch terms[0].glossary[0] {
        case let .text(text):
            #expect(text == "to eat")
        default:
            #expect(Bool(false), "Expected text glossary entry")
        }
    }

    @Test func termBankV3Entry_ComplexGlossary_ReturnsCorrectGlossaryData() throws {
        // Purpose: Handle structured glossary objects.
        // Input: Term with nested structured-content glossary.
        // Expected: Glossary as valid structured content object.
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, [{"type": "structured-content", "content": "Detailed def"}], 1, "common"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let terms = try decoder.decode([TermBankV3Entry].self, from: data)

        #expect(terms.count == 1)
        switch terms[0].glossary[0] {
        case let .detailed(content):
            switch content {
            case let .structured(structured):
                switch structured.content {
                case let .text(text):
                    #expect(text == "Detailed def")
                default:
                    #expect(Bool(false), "Expected text content in structured glossary")
                }
            default:
                #expect(Bool(false), "Expected structured-content glossary entry")
            }
        default:
            #expect(Bool(false), "Expected detailed glossary entry")
        }
    }

    @Test func termBankV3Entry_InvalidRowCount_ThrowsUnsupportedFormat() throws {
        // Purpose: Detect invalid term row structure.
        // Input: Row with fewer than 8 elements.
        // Expected: Throws DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode([TermBankV3Entry].self, from: data)
        }
    }

    @Test func termBankV1Entry_ValidSingleDefinition_ReturnsParsedEntry() throws {
        let json = """
        [
          ["食べる", "たべる", "v1", "v1", 100, "to eat"]
        ]
        """
        let data = Data(json.utf8)
        let terms = try JSONDecoder().decode([TermBankV1Entry].self, from: data)
        #expect(terms.count == 1)
        let term = terms[0]
        #expect(term.expression == "食べる")
        #expect(term.reading == "たべる")
        #expect(term.definitionTags == ["v1"])
        #expect(term.rules == ["v1"])
        #expect(term.score == 100)
        switch term.glossary[0] {
        case let .text(text):
            #expect(text == "to eat")
        default:
            #expect(Bool(false), "Expected text glossary entry")
        }
    }

    @Test func termBankV1Entry_MultipleDefinitions_ReturnsAllGlossaryItems() throws {
        let json = """
        [
          ["食べる", "たべる", "v1 freq common", "v1", 250, "to eat", "consume", "ingest"]
        ]
        """
        let data = Data(json.utf8)
        let terms = try JSONDecoder().decode([TermBankV1Entry].self, from: data)
        #expect(terms.count == 1)
        let term = terms[0]
        #expect(term.definitionTags == ["v1", "freq", "common"])
        switch term.glossary[0] {
        case let .text(text):
            #expect(text == "to eat")
        default:
            #expect(Bool(false), "Expected text glossary entry")
        }
        switch term.glossary[1] {
        case let .text(text):
            #expect(text == "consume")
        default:
            #expect(Bool(false), "Expected text glossary entry")
        }
    }

    @Test func termBankV1Entry_EmptyTagsAndRules_YieldsEmptyArrays() throws {
        // Empty strings should produce empty tag & rule arrays per schema description.
        let json = """
        [
          ["本", "", "", "", 5, "book"]
        ]
        """
        let data = Data(json.utf8)
        let terms = try JSONDecoder().decode([TermBankV1Entry].self, from: data)
        let term = try #require(terms.first)
        #expect(term.expression == "本")
        #expect(term.reading == "")
        #expect(term.definitionTags.isEmpty)
        #expect(term.rules.isEmpty)
        #expect(term.score == 5)
        switch term.glossary[0] {
        case let .text(text):
            #expect(text == "book")
        default:
            #expect(Bool(false), "Expected text glossary entry")
        }
    }

    @Test func termBankV1Entry_InvalidAdditionalItemType_ThrowsInvalidData() throws {
        // After the first 5 required fields, additional items must be strings (definitions).
        // Here we provide a number (123) which should trigger DictionaryImportError.invalidData.
        let json = """
        [
          ["食べる", "たべる", "v1", "v1", 100, "to eat", 123]
        ]
        """
        let data = Data(json.utf8)
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try JSONDecoder().decode([TermBankV1Entry].self, from: data)
        }
    }

    @Test func termBankV1Entry_TooFewItems_ThrowsDecodingError() throws {
        // Missing the score field (only 4 items) violates the schema minItems=5 and should fail decoding.
        let json = """
        [
          ["食べる", "たべる", "v1", "v1"]
        ]
        """
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode([TermBankV1Entry].self, from: data)
        }
    }
}
