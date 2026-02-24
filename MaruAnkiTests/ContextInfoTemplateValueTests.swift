// ContextInfoTemplateValueTests.swift
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

struct ContextInfoTemplateValueTests {
    private func makeGroup(
        expression: String = "語る",
        dictionaryTitle: String = "Dictionary A"
    ) -> GroupedSearchResults {
        let dictionaryResult = DictionaryResults(
            dictionaryTitle: dictionaryTitle,
            dictionaryUUID: UUID(),
            sequence: 1,
            score: 0,
            results: []
        )

        return GroupedSearchResults(
            termKey: "\(expression)|",
            expression: expression,
            reading: nil,
            dictionariesResults: [dictionaryResult],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )
    }

    private func makeResponse(
        context: String,
        primaryResult: String,
        group: GroupedSearchResults,
        contextValues: LookupContextValues?
    ) -> TextLookupResponse {
        let request = TextLookupRequest(
            context: context,
            offset: 0,
            contextValues: contextValues
        )
        let styles = DisplayStyles(
            fontFamily: "sans-serif",
            contentFontSize: 1.0,
            popupFontSize: 1.0,
            showDeinflection: false,
            deinflectionDescriptionLanguage: "system",
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )

        let range = context.startIndex ..< context.endIndex
        return TextLookupResponse(
            request: request,
            results: [group],
            primaryResult: primaryResult,
            primaryResultSourceRange: range,
            styles: styles
        )
    }

    @Test func contextInfo_returnsProvidedLookupContextInfo() async {
        let group = makeGroup()
        let contextValues = LookupContextValues(
            contextInfo: "Book Title - Position 42",
            sourceType: .book
        )
        let response = makeResponse(
            context: "語る",
            primaryResult: "語る",
            group: group,
            contextValues: contextValues
        )

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)
        let result = await resolver.resolve(.contextInfo)

        #expect(result.text == "Book Title - Position 42")
    }

    @Test func contextInfo_dictionarySource_formatsQueryHeadwordAndDictionary() async {
        let group = makeGroup(expression: "語る", dictionaryTitle: "Dictionary A")
        let contextValues = LookupContextValues(sourceType: .dictionary)
        let response = makeResponse(
            context: "検索語",
            primaryResult: "語る",
            group: group,
            contextValues: contextValues
        )

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)
        let result = await resolver.resolve(.contextInfo)

        #expect(result.text == "Query: 検索語 | Headword: 語る | Dictionary: Dictionary A")
    }

    @Test func contextInfo_withoutContextValues_usesDictionaryFallbackFormat() async {
        let group = makeGroup(expression: "学ぶ", dictionaryTitle: "Dictionary B")
        let response = makeResponse(
            context: "学ぶ",
            primaryResult: "学ぶ",
            group: group,
            contextValues: nil
        )

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)
        let result = await resolver.resolve(.contextInfo)

        #expect(result.text == "Query: 学ぶ | Headword: 学ぶ | Dictionary: Dictionary B")
    }
}
