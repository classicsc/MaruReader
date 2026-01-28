// TagParsingTests.swift
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
        let data = try #require(jsonString.data(using: .utf8))
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
        let data = try #require(jsonString.data(using: .utf8))
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
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        #expect(throws: DictionaryImportError.invalidData) {
            try decoder.decode([TagBankV3Entry].self, from: data)
        }
    }
}
