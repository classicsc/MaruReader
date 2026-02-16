// TagBankIteratorTests.swift
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

import Foundation
@testable import MaruReaderCore
import Testing

struct TagBankIteratorTests {
    @Test func tagBankIterator_V3Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V3 tag bank data
        let jsonString = """
        [
            ["noun", "partOfSpeech", 1, "Common noun", 0],
            ["verb", "partOfSpeech", 2, "Action verb", 10],
            ["jlpt-n5", "frequency", 3, "Very common (JLPT N5)", 100]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_tag_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TagBankV3Entry>(
            bankURLs: [tempURL]
        )

        var tags: [TagBankV3Entry] = []
        for try await entry in iterator {
            tags.append(entry)
        }

        #expect(tags.count == 3)

        // First tag
        #expect(tags[0].name == "noun")
        #expect(tags[0].category == "partOfSpeech")
        #expect(tags[0].order == 1)
        #expect(tags[0].notes == "Common noun")
        #expect(tags[0].score == 0)

        // Second tag
        #expect(tags[1].name == "verb")
        #expect(tags[1].category == "partOfSpeech")
        #expect(tags[1].order == 2)
        #expect(tags[1].notes == "Action verb")
        #expect(tags[1].score == 10)

        // Third tag
        #expect(tags[2].name == "jlpt-n5")
        #expect(tags[2].category == "frequency")
        #expect(tags[2].order == 3)
        #expect(tags[2].notes == "Very common (JLPT N5)")
        #expect(tags[2].score == 100)
    }

    @Test func tagBankIterator_MultipleFiles_StreamsAllTags() async throws {
        let jsonString1 = """
        [
            ["noun", "partOfSpeech", 1, "Common noun", 0],
            ["verb", "partOfSpeech", 2, "Action verb", 10]
        ]
        """

        let jsonString2 = """
        [
            ["adjective", "partOfSpeech", 3, "Descriptive word", 5],
            ["jlpt-n5", "frequency", 4, "Very common (JLPT N5)", 100]
        ]
        """

        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_tag_bank_1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_tag_bank_2.json")
        try jsonString1.write(to: tempURL1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: tempURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }

        let iterator = StreamingBankIterator<TagBankV3Entry>(
            bankURLs: [tempURL1, tempURL2]
        )

        var tags: [TagBankV3Entry] = []
        for try await entry in iterator {
            tags.append(entry)
        }

        #expect(tags.count == 4)
        #expect(tags.map(\.name) == ["noun", "verb", "adjective", "jlpt-n5"])
    }

    @Test func tagBankIterator_InvalidData_ThrowsError() async throws {
        let jsonString = """
        [
            ["noun", "partOfSpeech", 1, "Common noun", 0],
            {"invalid": "object"}
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_tag_bank_throwing.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TagBankV3Entry>(
            bankURLs: [tempURL]
        )

        var tags: [TagBankV3Entry] = []
        var errorOccurred = false

        do {
            for try await entry in iterator {
                tags.append(entry)
            }
        } catch {
            errorOccurred = true
        }

        #expect(errorOccurred)
        #expect(tags.count == 1) // Only first valid row parsed before error
    }

    @Test func tagBankIterator_EmptyFiles_ReturnsNoTags() async throws {
        let jsonString = "[]"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_tag_bank_empty.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TagBankV3Entry>(
            bankURLs: [tempURL]
        )

        var tags: [TagBankV3Entry] = []
        for try await entry in iterator {
            tags.append(entry)
        }

        #expect(tags.isEmpty)
    }

    @Test func tagBankIterator_NoFiles_ReturnsNoTags() async throws {
        let iterator = StreamingBankIterator<TagBankV3Entry>(
            bankURLs: []
        )

        var tags: [TagBankV3Entry] = []
        for try await entry in iterator {
            tags.append(entry)
        }

        #expect(tags.isEmpty)
    }
}
