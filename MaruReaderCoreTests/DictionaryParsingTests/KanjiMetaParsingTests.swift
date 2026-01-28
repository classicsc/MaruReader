// KanjiMetaParsingTests.swift
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

struct KanjiMetaParsingTests {
    // MARK: - Valid Cases

    @Test func kanjiMetaBankV3Entry_NumberFrequency_ParsesCorrectly() throws {
        // Purpose: Ensure numeric frequency decodes into .number.
        // Input: Row with number as third element.
        // Expected: KanjiMetaBankV3Entry with frequency .number(123).
        let jsonString = """
        [
            ["漢", "freq", 123]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        let entry = entries[0]
        #expect(entry.kanji == "漢")
        #expect(entry.type == "freq")
        switch entry.frequency {
        case let .number(v): #expect(v == 123)
        default: #expect(Bool(false), "Expected number frequency")
        }
    }

    @Test func kanjiMetaBankV3Entry_StringFrequency_ParsesCorrectly() throws {
        // Purpose: Ensure string frequency decodes into .string.
        // Input: Row with string as third element.
        // Expected: KanjiMetaBankV3Entry with frequency .string("high").
        let jsonString = """
        [
            ["日", "freq", "high"]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        switch entries[0].frequency {
        case let .string(s): #expect(s == "high")
        default: #expect(Bool(false), "Expected string frequency")
        }
    }

    @Test func kanjiMetaBankV3Entry_ObjectFrequencyWithDisplayValue_ParsesCorrectly() throws {
        // Purpose: Ensure object frequency with displayValue decodes into .object.
        // Input: Row with object containing value & displayValue.
        // Expected: KanjiMetaBankV3Entry with matching value/displayValue.
        let jsonString = """
        [
            ["人", "freq", {"value": 45, "displayValue": "Rank 45"}]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        switch entries[0].frequency {
        case let .object(value, display):
            #expect(value == 45)
            #expect(display == "Rank 45")
        default:
            #expect(Bool(false), "Expected object frequency")
        }
    }

    @Test func kanjiMetaBankV3Entry_ObjectFrequencyWithoutDisplayValue_ParsesCorrectly() throws {
        // Purpose: Ensure object frequency without displayValue decodes with nil display.
        // Input: Row with object containing only value.
        // Expected: .object with correct value and nil displayValue.
        let jsonString = """
        [
            ["書", "freq", {"value": 7}]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        let entries = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        #expect(entries.count == 1)
        switch entries[0].frequency {
        case let .object(value, display):
            #expect(value == 7)
            #expect(display == nil)
        default:
            #expect(Bool(false), "Expected object frequency without displayValue")
        }
    }

    // MARK: - Invalid Cases

    @Test func kanjiMetaBankV3Entry_InvalidType_ThrowsInvalidData() throws {
        // Purpose: Reject rows where second element isn't literal "freq".
        // Input: Second item is "frequency".
        // Expected: DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["漢", "frequency", 10]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        }
    }

    @Test func kanjiMetaBankV3Entry_TooFewItems_ThrowsInvalidData() throws {
        // Purpose: Detect rows with fewer than required 3 items.
        // Input: Only kanji + type.
        // Expected: DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["漢", "freq"]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        }
    }

    @Test func kanjiMetaBankV3Entry_TooManyItems_ThrowsInvalidData() throws {
        // Purpose: Detect rows with more than 3 items.
        // Input: Row includes an extra element.
        // Expected: DictionaryImportError.invalidData.
        let jsonString = """
        [
            ["漢", "freq", 123, "extra"]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        #expect(throws: DictionaryImportError.invalidData) {
            _ = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        }
    }

    @Test func kanjiMetaBankV3Entry_ObjectMissingValue_ThrowsDecodingError() throws {
        // Purpose: Ensure object missing required 'value' fails decoding.
        // Input: Object has only displayValue.
        // Expected: DecodingError (keyNotFound or typeMismatch) thrown.
        let jsonString = """
        [
            ["漢", "freq", {"displayValue": "Rank 12"}]
        ]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode([KanjiMetaBankV3Entry].self, from: data)
        }
    }
}
