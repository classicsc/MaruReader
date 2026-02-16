// ClozeFuriganaTemplateValueTests.swift
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
        let expected = FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from: context))

        #expect(combined == expected)
        #expect(body.contains("["))
    }

    // MARK: - Edited Context Tests

    @Test func clozeWithEditedContext_editBeforeMatch_updatesPrefix() async throws {
        // Original: "今日は学校へ行く", editing to add prefix
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        var (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)

        // Edit context to add text before the match
        let editedContext = "昨日も今日も学校へ行く"
        _ = response.updateEditedRange(for: editedContext)

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozePrefix).text ?? ""
        let body = await resolver.resolve(.clozeBody).text ?? ""
        let suffix = await resolver.resolve(.clozeSuffix).text ?? ""

        // Verify prefix contains the added text
        #expect(prefix.contains("昨日も今日も"))
        #expect(body == primaryResult)
        #expect(suffix.contains("行く"))
    }

    @Test func clozeWithEditedContext_editAfterMatch_updatesSuffix() async throws {
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        var (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)

        // Edit context to change text after the match
        let editedContext = "今日は学校へ行かない"
        _ = response.updateEditedRange(for: editedContext)

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozePrefix).text ?? ""
        let body = await resolver.resolve(.clozeBody).text ?? ""
        let suffix = await resolver.resolve(.clozeSuffix).text ?? ""

        #expect(prefix == "今日は")
        #expect(body == primaryResult)
        #expect(suffix.contains("行かない"))
    }

    @Test func clozeWithEditedContext_termRemoved_bodyStillAvailable() async throws {
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        var (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)

        // Edit context to remove the term entirely
        let editedContext = "今日は公園へ行く"
        _ = response.updateEditedRange(for: editedContext)

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozePrefix).text ?? ""
        let body = await resolver.resolve(.clozeBody).text ?? ""
        let suffix = await resolver.resolve(.clozeSuffix).text ?? ""

        // When term is removed from context, prefix/suffix are empty (no valid range)
        // but body still contains the primary result for reference
        #expect(prefix == "")
        #expect(body == primaryResult)
        #expect(suffix == "")
    }

    @Test func clozeFuriganaWithEditedContext_termRemoved_entireContextAsPrefix() async throws {
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        var (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)

        // Edit context to remove the term entirely
        let editedContext = "今日は公園へ行く"
        _ = response.updateEditedRange(for: editedContext)

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozeFuriganaPrefix).text ?? ""
        let body = await resolver.resolve(.clozeFuriganaBody).text
        let suffix = await resolver.resolve(.clozeFuriganaSuffix).text

        // For furigana version, when term is removed, entire context goes to prefix
        let expectedFurigana = FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from: editedContext))
        #expect(prefix == expectedFurigana)
        #expect(body == nil)
        #expect(suffix == nil)
    }

    @Test func clozeFuriganaWithEditedContext_updatesCorrectly() async throws {
        let context = "今日は学校へ行く"
        let primaryResult = "学校"
        let range = try #require(context.range(of: primaryResult))

        var (response, group) = makeResponse(context: context, primaryResult: primaryResult, range: range)

        // Edit context
        let editedContext = "明日は学校へ行かない"
        _ = response.updateEditedRange(for: editedContext)

        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let prefix = await resolver.resolve(.clozeFuriganaPrefix).text ?? ""
        let body = await resolver.resolve(.clozeFuriganaBody).text ?? ""
        let suffix = await resolver.resolve(.clozeFuriganaSuffix).text ?? ""

        // Verify the combined segments form the full furigana for the edited context
        let combined = prefix + body + suffix
        let expected = FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from: editedContext))

        #expect(combined == expected)
        #expect(body.contains("学校"))
    }
}
