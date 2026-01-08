// ClozeFuriganaTemplateValueTests.swift
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
@testable import MaruAnki
@testable import MaruReaderCore
import Testing

struct ClozeFuriganaTemplateValueTests {
    private func makeResponse(
        context: String,
        primaryResult: String,
        range: Range<String.Index>
    ) -> (TextLookupResponse, GroupedSearchResults) {
        let request = TextLookupRequest(context: context, offset: 0)
        let styles = DisplayStyles(
            fontFamily: "sans-serif",
            contentFontSize: 1.0,
            popupFontSize: 1.0,
            showDeinflection: false,
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )

        let group = GroupedSearchResults(
            termKey: "\(primaryResult)|",
            expression: primaryResult,
            reading: nil,
            dictionariesResults: [],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )

        let response = TextLookupResponse(
            request: request,
            results: [group],
            primaryResult: primaryResult,
            primaryResultSourceRange: range,
            styles: styles
        )

        return (response, group)
    }

    @Test func clozeFuriganaSegments_matchFullSentenceOutput() async throws {
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        let (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)
        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozeFuriganaPrefix).text ?? ""
        let body = await resolver.resolve(.clozeFuriganaBody).text ?? ""
        let suffix = await resolver.resolve(.clozeFuriganaSuffix).text ?? ""

        let combined = prefix + body + suffix
        let expected = SentenceFuriganaGenerator.generate(from: context)

        #expect(combined == expected)
        #expect(body.contains("["))
    }
}
