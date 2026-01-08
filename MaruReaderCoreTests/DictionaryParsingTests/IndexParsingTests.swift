// IndexParsingTests.swift
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

struct IndexParsingTests {
    @Test func parseIndex_ValidJSON_ReturnsCorrectIndex() throws {
        // Purpose: Ensure valid index.json is parsed into Index struct.
        // Input: Sample JSON Data matching Yomitan index format.
        // Expected: Index with title, revision, and format matching input; no errors.
        let jsonString = """
        {
            "title": "TestDict",
            "attribution": "Test Attribution",
            "downloadUrl": "http://example.com/dict",
            "frequencyMode": "rank-based",
            "sequenced": true,
            "author": "Test Author",
            "indexUrl": "http://example.com/index",
            "isUpdatable": true,
            "minimumYomitanVersion": "1.0",
            "sourceLanguage": "ja",
            "targetLanguage": "en",
            "revision": "1.0a",
            "format": 3
        }
        """
        let data = jsonString.data(using: .utf8)!

        let decoder = JSONDecoder()
        let index = try decoder.decode(DictionaryIndex.self, from: data)

        #expect(index.title == "TestDict")
        #expect(index.revision == "1.0a")
        #expect(index.format == 3)
        #expect(index.attribution == "Test Attribution")
        #expect(index.downloadUrl == "http://example.com/dict")
        #expect(index.frequencyMode?.rawValue == "rank-based")
        #expect(index.sequenced == true)
        #expect(index.author == "Test Author")
        #expect(index.indexUrl == "http://example.com/index")
        #expect(index.isUpdatable == true)
        #expect(index.minimumYomitanVersion == "1.0")
        #expect(index.sourceLanguage == "ja")
        #expect(index.targetLanguage == "en")
    }

    @Test func parseIndex_InvalidJSON_ThrowsUnsupportedFormat() throws {
        // Purpose: Verify malformed JSON throws expected error.
        // Input: Invalid JSON (missing keys).
        // Expected: Throws ParserError.unsupportedFormat.
        let jsonString = """
        {
            "title": "TestDict"
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode(DictionaryIndex.self, from: data)
        }
    }
}
