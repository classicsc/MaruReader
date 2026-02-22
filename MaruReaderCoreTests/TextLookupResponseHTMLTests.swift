// TextLookupResponseHTMLTests.swift
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

struct DictionaryResultsHTMLTests {
    @Test func resultsHTMLIncludesAnkiButtonAndTermKey() async {
        let response = makeResponse()
        let renderer = DictionaryResultsHTMLRenderer(styles: response.styles)
        let html = await renderer.render(groups: response.results, mode: .results)

        #expect(html.contains("class=\"anki-button\""))
        #expect(html.contains("data-term-key=\"neko|ねこ\""))
        #expect(html.contains("data-state=\"disabled\""))
        #expect(html.contains("hidden"))
    }

    @Test func popupHTMLIncludesAnkiButtonAndTermKey() async {
        let response = makeResponse()
        let renderer = DictionaryResultsHTMLRenderer(styles: response.styles)
        let html = await renderer.render(groups: response.results, mode: .popup)

        #expect(html.contains("class=\"anki-button\""))
        #expect(html.contains("data-term-key=\"neko|ねこ\""))
        #expect(html.contains("data-state=\"disabled\""))
        #expect(html.contains("hidden"))
    }

    @Test func dictionaryWebThemeRoundTripsThroughJSON() throws {
        let theme = DictionaryWebTheme(
            colorScheme: "light",
            textColor: "#111111",
            backgroundColor: "#F5EDD6",
            accentColor: "#0A84FF",
            linkColor: "#0A84FF",
            glossImageBackgroundColor: "#F5EDD6"
        )

        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(DictionaryWebTheme.self, from: data)

        #expect(decoded == theme)
    }
}

private func makeResponse() -> TextLookupResponse {
    let context = "neko"
    let request = TextLookupRequest(context: context)
    let range = context.startIndex ..< context.endIndex
    let termKey = "neko|ねこ"

    let group = GroupedSearchResults(
        termKey: termKey,
        expression: "neko",
        reading: "ねこ",
        dictionariesResults: [],
        pitchAccentResults: [],
        termTags: [],
        deinflectionInfo: nil
    )

    let styles = DisplayStyles(
        fontFamily: "Test",
        contentFontSize: 14,
        popupFontSize: 14,
        showDeinflection: true,
        pitchDownstepNotationInHeaderEnabled: false,
        pitchResultsAreaCollapsedDisplay: false,
        pitchResultsAreaDownstepNotationEnabled: false,
        pitchResultsAreaDownstepPositionEnabled: false,
        pitchResultsAreaEnabled: false
    )

    return TextLookupResponse(
        request: request,
        results: [group],
        primaryResult: "neko",
        primaryResultSourceRange: range,
        styles: styles
    )
}
