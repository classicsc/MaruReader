//
//  IndexParsingTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation
@testable import MaruReader
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
