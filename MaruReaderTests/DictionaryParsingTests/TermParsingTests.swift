//
//  TermParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation
@testable import MaruReader
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

        #expect(throws: DictionaryImportError.invalidData) {
            try decoder.decode([TermBankV3Entry].self, from: data)
        }
    }
}
