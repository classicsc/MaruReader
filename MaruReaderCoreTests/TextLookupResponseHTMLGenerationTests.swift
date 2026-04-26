// TextLookupResponseHTMLGenerationTests.swift
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

struct TextLookupResponseHTMLGenerationTests {
    @Test func dictionaryStylesHTML_scopesStylesByDictionary() {
        let dictionaryID = UUID()
        let dictionaryResults = DictionaryResults(
            dictionaryTitle: "Test Dictionary",
            dictionaryUUID: dictionaryID,
            sequence: 0,
            score: 0,
            results: []
        )

        let groupedResults = GroupedSearchResults(
            termKey: "term",
            expression: "term",
            reading: nil,
            dictionariesResults: [dictionaryResults],
            pitchAccentResults: [],
            termTags: []
        )

        let html = DictionaryResultsHTMLRenderer.dictionaryStylesHTML(for: [groupedResults]) { id in
            #expect(id == dictionaryID)
            return ".gloss-sc-ul[data-sc-content=glossary] { color: red; }"
        }

        #expect(html.contains("<style id=\"dictionary-styles\">"))
        #expect(html.contains("[data-dictionary=\"Test Dictionary\"]"))
        #expect(html.contains(".gloss-sc-ul[data-sc-content=glossary]"))
    }

    @Test func resultsRenderer_addsDataDictionaryAttribute() async {
        let dictionaryID = UUID()
        let dictionaryResults = DictionaryResults(
            dictionaryTitle: "Test Dictionary",
            dictionaryUUID: dictionaryID,
            sequence: 0,
            score: 0,
            results: []
        )

        let groupedResults = GroupedSearchResults(
            termKey: "term",
            expression: "term",
            reading: nil,
            dictionariesResults: [dictionaryResults],
            pitchAccentResults: [],
            termTags: []
        )

        let request = TextLookupRequest(context: "term", offset: 0)
        let range = request.context.startIndex ..< request.context.index(request.context.startIndex, offsetBy: 1)
        let styles = DisplayStyles(
            fontFamily: "Test",
            contentFontSize: 1.0,
            popupFontSize: 1.0,
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )

        let response = TextLookupResponse(
            request: request,
            results: [groupedResults],
            primaryResult: "term",
            primaryResultSourceRange: range,
            styles: styles
        )

        let renderer = DictionaryResultsHTMLRenderer(styles: response.styles)
        let html = await renderer.render(groups: response.results, mode: .results)
        #expect(html.contains("data-dictionary=\"Test Dictionary\""))
    }
}
