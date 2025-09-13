//
//  KanjiParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
@testable import MaruReader
import Testing

struct KanjiParsingTests {
    // MARK: - Kanji Bank V1

    @Test func kanjiBankV1Entry_ValidRows_ParsesCorrectly() throws {
        // Purpose: Ensure kanji_bank v1 rows (with and without meanings) decode correctly.
        // Input: Two rows: one with multiple meanings, one with zero meanings (only 4 fields).
        // Expected: Proper splitting of readings/tags and meanings collection.
        let jsonString = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", "Chinese", "Han"],
            ["日", "ニチ ジツ", "ひ か", "jlpt-n5", "sun", "day", "Japan"],
            ["木", "モク", "き", "", "tree"],
            ["人", "ジン ニン", "ひと", "", "person", "human"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiBankV1Entry].self, from: data)

        #expect(entries.count == 4)
        // First entry
        #expect(entries[0].character == "漢")
        #expect(entries[0].onyomi == ["カン", "ケン"])
        #expect(entries[0].kunyomi == ["かん"]) // single kunyomi
        #expect(entries[0].tags == ["jlpt-n1", "joyo"])
        #expect(entries[0].meanings == ["Chinese", "Han"])
        // Second entry multiple meanings
        #expect(entries[1].meanings == ["sun", "day", "Japan"])
        // Third entry empty tags means []
        #expect(entries[2].tags.isEmpty)
        #expect(entries[2].meanings == ["tree"])
        // Fourth entry
        #expect(entries[3].meanings == ["person", "human"])
    }

    @Test func kanjiBankV1Entry_TooFewItems_ThrowsDecodingError() throws {
        // Purpose: Detect row with fewer than required 4 base fields.
        // Input: Row with only 3 strings.
        // Expected: DecodingError thrown.
        let jsonString = """
        [
            ["漢", "カン ケン", "かん"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode([KanjiBankV1Entry].self, from: data)
        }
    }

    @Test func kanjiBankV1Entry_InvalidMeaningType_ThrowsInvalidData() throws {
        // Purpose: Ensure non-string additional items trigger invalidData.
        // Input: Fifth element is a number instead of a string.
        // Expected: DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["漢", "カン", "かん", "jlpt-n1", 123]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try decoder.decode([KanjiBankV1Entry].self, from: data)
        }
    }

    // MARK: - Kanji Bank V3

    @Test func kanjiBankV3Entry_ValidRow_ParsesCorrectly() throws {
        // Purpose: Ensure kanji_bank v3 row decodes with proper splitting and field mapping.
        // Input: Single row with multi readings, multi tags, meanings array, stats.
        // Expected: Correct arrays & dictionary; no extra items.
        let jsonString = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", ["Chinese", "Han"], {"frequency": "120", "grade": "6"}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        let e = entries[0]
        #expect(e.character == "漢")
        #expect(e.onyomi == ["カン", "ケン"])
        #expect(e.kunyomi == ["かん"])
        #expect(e.tags == ["jlpt-n1", "joyo"])
        #expect(e.meanings == ["Chinese", "Han"])
        #expect(e.stats["frequency"] == "120")
        #expect(e.stats["grade"] == "6")
    }

    @Test func kanjiBankV3Entry_EmptyReadingsTagsAndMeanings_ParsesEmptyCollections() throws {
        // Purpose: Verify empty strings for readings/tags produce empty arrays and empty meanings array accepted.
        // Input: Row with empty reading, empty kunyomi, empty tags, empty meanings, empty stats.
        // Expected: Arrays empty; stats empty.
        let jsonString = """
        [
            ["仮", "", "", "", [], {}]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        let e = entries[0]
        #expect(e.character == "仮")
        #expect(e.onyomi.isEmpty)
        #expect(e.kunyomi.isEmpty)
        #expect(e.tags.isEmpty)
        #expect(e.meanings.isEmpty)
        #expect(e.stats.isEmpty)
    }

    @Test func kanjiBankV3Entry_TooManyItems_ThrowsInvalidData() throws {
        // Purpose: Detect rows with more than 6 items.
        // Input: Row with an extra string element.
        // Expected: DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["漢", "カン", "かん", "jlpt-n1", ["Chinese"], {"frequency": "100"}, "extra"]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try decoder.decode([KanjiBankV3Entry].self, from: data)
        }
    }

    @Test func kanjiBankV3Entry_TooFewItems_ThrowsDecodingError() throws {
        // Purpose: Detect rows with fewer than 6 required items.
        // Input: Row with only 5 items.
        // Expected: DecodingError.
        let jsonString = """
        [
            ["漢", "カン", "かん", "jlpt-n1", ["Chinese"]]
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode([KanjiBankV3Entry].self, from: data)
        }
    }
}
