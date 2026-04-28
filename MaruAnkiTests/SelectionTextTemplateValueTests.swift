// SelectionTextTemplateValueTests.swift
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
@testable import MaruAnki
@testable import MaruReaderCore
import Testing

struct SelectionTextTemplateValueTests {
    @Test func selectionText_returnsProvidedSelectionText() async {
        let group = makeGroup()
        let response = makeResponse(group: group)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            selectionText: "選択されたテキスト"
        )

        let result = await resolver.resolve(.selectionText)

        #expect(result.text == "選択されたテキスト")
    }

    @Test func selectionText_withoutProvidedSelectionTextIsEmpty() async {
        let group = makeGroup()
        let response = makeResponse(group: group)
        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let result = await resolver.resolve(.selectionText)

        #expect(result.text == nil)
    }

    private func makeGroup() -> GroupedSearchResults {
        GroupedSearchResults(
            termKey: "猫|ねこ",
            expression: "猫",
            reading: "ねこ",
            dictionariesResults: [],
            pitchAccentResults: [],
            termTags: []
        )
    }

    private func makeResponse(group: GroupedSearchResults) -> TextLookupResponse {
        let context = "猫がいる"
        let request = TextLookupRequest(context: context)
        let range = context.startIndex ..< context.index(context.startIndex, offsetBy: 1)
        let styles = DisplayStyles(
            fontFamily: "sans-serif",
            contentFontSize: 1.0,
            popupFontSize: 1.0,
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )

        return TextLookupResponse(
            request: request,
            results: [group],
            primaryResult: "猫",
            primaryResultSourceRange: range,
            styles: styles
        )
    }
}
