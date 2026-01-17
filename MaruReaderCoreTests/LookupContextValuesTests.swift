// LookupContextValuesTests.swift
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

struct LookupContextValuesTests {
    // MARK: - Default Source Type Tests

    @Test func lookupContextValues_defaultSourceType_isDictionary() {
        let contextValues = LookupContextValues()

        #expect(contextValues.sourceType == .dictionary)
    }

    @Test func lookupContextValues_withExplicitSourceType_preservesSourceType() {
        let contextValues = LookupContextValues(
            documentTitle: "Test Book",
            sourceType: .book
        )

        #expect(contextValues.sourceType == .book)
    }

    // MARK: - Source Type Transition Tests

    @Test func lookupContextValues_withSourceType_transitionsCorrectly() {
        let original = LookupContextValues(
            documentTitle: "Test Book",
            documentURL: URL(string: "file:///test.epub"),
            documentCoverImageURL: URL(string: "file:///cover.jpg"),
            screenshotURL: URL(string: "file:///screenshot.png"),
            sourceType: .book
        )

        let dictionaryScreenshotURL = URL(string: "file:///dictionary.png")
        let transitioned = original.withSourceType(
            .dictionary,
            screenshotURL: dictionaryScreenshotURL
        )

        #expect(transitioned.sourceType == .dictionary)
        #expect(transitioned.documentTitle == "Maru Dictionary")
        #expect(transitioned.documentURL == nil)
        #expect(transitioned.documentCoverImageURL == nil)
        #expect(transitioned.screenshotURL == dictionaryScreenshotURL)
    }

    @Test func lookupContextValues_withSourceType_bookToManga() {
        let original = LookupContextValues(
            documentTitle: "My Manga",
            sourceType: .book
        )

        let transitioned = original.withSourceType(.manga)

        #expect(transitioned.sourceType == .manga)
        #expect(transitioned.documentTitle == "My Manga")
    }

    @Test func lookupContextValues_withSourceType_webToDictionary() {
        let original = LookupContextValues(
            documentTitle: "Web Page",
            documentURL: URL(string: "https://example.com"),
            sourceType: .web
        )

        let transitioned = original.withSourceType(.dictionary)

        #expect(transitioned.sourceType == .dictionary)
        #expect(transitioned.documentTitle == "Maru Dictionary")
        #expect(transitioned.documentURL == nil)
    }

    // MARK: - All Source Types Tests

    @Test func contextSourceType_allCases_includesExpectedValues() {
        let allCases = ContextSourceType.allCases

        #expect(allCases.contains(.book))
        #expect(allCases.contains(.manga))
        #expect(allCases.contains(.web))
        #expect(allCases.contains(.dictionary))
        #expect(allCases.count == 4)
    }

    @Test func contextSourceType_rawValues_areCorrect() {
        #expect(ContextSourceType.book.rawValue == "book")
        #expect(ContextSourceType.manga.rawValue == "manga")
        #expect(ContextSourceType.web.rawValue == "web")
        #expect(ContextSourceType.dictionary.rawValue == "dictionary")
    }

    @Test func contextSourceType_decodesFromRawValue() {
        #expect(ContextSourceType(rawValue: "book") == .book)
        #expect(ContextSourceType(rawValue: "manga") == .manga)
        #expect(ContextSourceType(rawValue: "web") == .web)
        #expect(ContextSourceType(rawValue: "dictionary") == .dictionary)
        #expect(ContextSourceType(rawValue: "invalid") == nil)
    }
}
