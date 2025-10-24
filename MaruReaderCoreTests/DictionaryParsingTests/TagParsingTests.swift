//
//  TagParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation
@testable import MaruReaderCore
import Testing

struct TagParsingTests {
    @Test func parseTags_ValidArray_ReturnsTagBankV3EntryArray() throws {
        // Purpose: Ensure tag_bank JSON array is parsed into [TagBankV3Entry].
        // Input: Sample array with one tag row.
        // Expected: Array with matching name, category, order, notes, score.
        let jsonString = """
        [
            ["noun", "partOfSpeech", 1, "Common noun", 0]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let tags = try decoder.decode([TagBankV3Entry].self, from: data)

        #expect(tags.count == 1)
        #expect(tags[0].name == "noun")
        #expect(tags[0].category == "partOfSpeech")
        #expect(tags[0].order == 1)
        #expect(tags[0].notes == "Common noun")
        #expect(tags[0].score == 0)
    }

    @Test func parseTags_EmptyArray_ReturnsEmptyArray() throws {
        // Purpose: Handle empty tag bank gracefully.
        // Input: Empty JSON array.
        // Expected: Empty [TagBankV3Entry]; no errors.
        let jsonString = "[]"
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let tags = try decoder.decode([TagBankV3Entry].self, from: data)

        #expect(tags.isEmpty)
    }

    @Test func parseTags_InvalidRowCount_ThrowsUnsupportedFormat() throws {
        // Purpose: Detect invalid row structure in tags.
        // Input: Row with fewer than 5 elements.
        // Expected: Throws ParserError.unsupportedFormat.
        let jsonString = """
        [
            ["noun", "partOfSpeech", 1, "Common noun"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: DictionaryImportError.invalidData) {
            try decoder.decode([TagBankV3Entry].self, from: data)
        }
    }
}
