// ContextImageTemplateValueTests.swift
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

struct ContextImageTemplateValueTests {
    // MARK: - Test Helpers

    private func makeResponse(
        context: String = "テスト",
        primaryResult: String = "テスト",
        contextValues: LookupContextValues? = nil
    ) -> (TextLookupResponse, GroupedSearchResults) {
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
            primaryResultSourceRange: context.range(of: primaryResult) ?? context.startIndex ..< context.endIndex,
            styles: styles
        )

        return (response, group)
    }

    private func makeContextValues(
        sourceType: ContextSourceType,
        coverURL: URL? = nil,
        screenshotURL: URL? = nil
    ) -> LookupContextValues {
        LookupContextValues(
            documentTitle: "Test Document",
            documentURL: nil,
            documentCoverImageURL: coverURL,
            screenshotURL: screenshotURL,
            sourceType: sourceType
        )
    }

    private let testCoverURL = URL(string: "file:///test/cover.jpg")!
    private let testScreenshotURL = URL(string: "file:///test/screenshot.png")!

    // MARK: - Book Source Tests

    @Test func contextImage_bookSource_defaultConfig_returnsCoverImage() async {
        let contextValues = makeContextValues(
            sourceType: .book,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testCoverURL)
    }

    @Test func contextImage_bookSource_screenshotPreference_returnsScreenshot() async {
        let contextValues = makeContextValues(
            sourceType: .book,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let config = ContextImageConfiguration(
            bookPreference: .screenshot,
            mangaPreference: .screenshot
        )
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: config
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testScreenshotURL)
    }

    // MARK: - Manga Source Tests

    @Test func contextImage_mangaSource_defaultConfig_returnsScreenshot() async {
        let contextValues = makeContextValues(
            sourceType: .manga,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testScreenshotURL)
    }

    @Test func contextImage_mangaSource_coverPreference_returnsCover() async {
        let contextValues = makeContextValues(
            sourceType: .manga,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let config = ContextImageConfiguration(
            bookPreference: .cover,
            mangaPreference: .cover
        )
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: config
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testCoverURL)
    }

    // MARK: - Web Source Tests

    @Test func contextImage_webSource_alwaysReturnsScreenshot() async {
        let contextValues = makeContextValues(
            sourceType: .web,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        // Even with cover preference, web should always return screenshot
        let config = ContextImageConfiguration(
            bookPreference: .cover,
            mangaPreference: .cover
        )
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: config
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testScreenshotURL)
    }

    // MARK: - Dictionary Source Tests

    @Test func contextImage_dictionarySource_returnsEmpty() async {
        let contextValues = makeContextValues(
            sourceType: .dictionary,
            coverURL: testCoverURL,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testScreenshotURL)
    }

    // MARK: - Fallback Tests

    @Test func contextImage_preferredImageUnavailable_fallsBackToOther() async {
        // Book source prefers cover by default, but only screenshot is available
        let contextValues = makeContextValues(
            sourceType: .book,
            coverURL: nil,
            screenshotURL: testScreenshotURL
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testScreenshotURL)
    }

    @Test func contextImage_screenshotPreferredButUnavailable_fallsBackToCover() async {
        // Web source prefers screenshot, but only cover is available
        let contextValues = makeContextValues(
            sourceType: .web,
            coverURL: testCoverURL,
            screenshotURL: nil
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.mediaFiles.values.first == testCoverURL)
    }

    // MARK: - No Context Values Tests

    @Test func contextImage_noContextValues_returnsEmpty() async {
        let (response, group) = makeResponse(contextValues: nil)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.text == nil)
        #expect(result.mediaFiles.isEmpty)
    }

    @Test func contextImage_noImagesAvailable_returnsEmpty() async {
        let contextValues = makeContextValues(
            sourceType: .book,
            coverURL: nil,
            screenshotURL: nil
        )
        let (response, group) = makeResponse(contextValues: contextValues)
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            contextImageConfiguration: .default
        )

        let result = await resolver.resolve(.contextImage)

        #expect(result.text == nil)
        #expect(result.mediaFiles.isEmpty)
    }
}
