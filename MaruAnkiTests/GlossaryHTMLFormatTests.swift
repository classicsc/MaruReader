// GlossaryHTMLFormatTests.swift
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

/// Tests for glossary HTML format compatibility with Lapis note type.
///
/// Lapis expects specific HTML structure for glossary switching to work:
/// - Outer `<div class="yomitan-glossary">` wrapper
/// - `<li data-dictionary="...">` elements for each dictionary entry
///
/// These tests ensure Maru's output matches Yomitan's format.
struct GlossaryHTMLFormatTests {
    // MARK: - Test Fixtures

    private func makeTestSearchResult(
        term: String = "映像",
        reading: String? = "えいぞう",
        dictionaryTitle: String = "Dictionary A",
        dictionaryUUID: UUID = UUID()
    ) -> SearchResult {
        let candidate = LookupCandidate(from: term)
        let rankingCriteria = RankingCriteria(
            sourceTermLength: term.count,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 100,
            termScore: 0,
            dictionaryTitle: dictionaryTitle,
            definitionCount: 1,
            term: term
        )

        return SearchResult(
            candidate: candidate,
            term: term,
            reading: reading,
            definitions: [.text("Test definition")],
            frequency: nil,
            frequencies: [],
            pitchAccents: [],
            dictionaryTitle: dictionaryTitle,
            dictionaryUUID: dictionaryUUID,
            displayPriority: 100,
            rankingCriteria: rankingCriteria,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 1,
            score: 0
        )
    }

    private func makeDictionaryResults(
        dictionaryTitle: String,
        dictionaryUUID: UUID = UUID(),
        searchResults: [SearchResult]? = nil
    ) -> DictionaryResults {
        let results = searchResults ?? [makeTestSearchResult(dictionaryTitle: dictionaryTitle, dictionaryUUID: dictionaryUUID)]
        return DictionaryResults(
            dictionaryTitle: dictionaryTitle,
            dictionaryUUID: dictionaryUUID,
            sequence: 1,
            score: 0,
            results: results
        )
    }

    private func makeGroupedSearchResults(
        expression: String = "映像",
        reading: String? = "えいぞう",
        dictionariesResults: [DictionaryResults]
    ) -> GroupedSearchResults {
        GroupedSearchResults(
            termKey: "\(expression)|\(reading ?? "")",
            expression: expression,
            reading: reading,
            dictionariesResults: dictionariesResults,
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )
    }

    private func makeTextLookupResponse(selectedGroup: GroupedSearchResults) -> TextLookupResponse {
        let request = TextLookupRequest(context: "テスト文章", offset: 0)
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

        let context = request.context
        let range = context.startIndex ..< context.index(context.startIndex, offsetBy: 2)

        return TextLookupResponse(
            request: request,
            results: [selectedGroup],
            primaryResult: "テスト",
            primaryResultSourceRange: range,
            styles: styles
        )
    }

    // MARK: - Single Dictionary Glossary Tests

    @Test func singleDictionaryGlossary_hasYomitanGlossaryClass() async {
        let dictionaryUUID = UUID()
        let dictResults = makeDictionaryResults(dictionaryTitle: "Dictionary A", dictionaryUUID: dictionaryUUID)
        let group = makeGroupedSearchResults(dictionariesResults: [dictResults])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            selectedDictionaryID: dictionaryUUID
        )

        let result = await resolver.resolve(.singleDictionaryGlossary(dictionaryID: dictionaryUUID))

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("class=\"yomitan-glossary\""), "Missing yomitan-glossary class for Lapis compatibility")
    }

    @Test func singleDictionaryGlossary_hasDataDictionaryAttribute() async {
        let dictionaryUUID = UUID()
        let dictionaryTitle = "Dictionary A"
        let dictResults = makeDictionaryResults(dictionaryTitle: dictionaryTitle, dictionaryUUID: dictionaryUUID)
        let group = makeGroupedSearchResults(dictionariesResults: [dictResults])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            selectedDictionaryID: dictionaryUUID
        )

        let result = await resolver.resolve(.singleDictionaryGlossary(dictionaryID: dictionaryUUID))

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("data-dictionary=\"\(dictionaryTitle)\""), "Missing data-dictionary attribute for Lapis compatibility")
    }

    @Test func singleDictionaryGlossary_hasListStructure() async {
        let dictionaryUUID = UUID()
        let dictResults = makeDictionaryResults(dictionaryTitle: "Test Dictionary", dictionaryUUID: dictionaryUUID)
        let group = makeGroupedSearchResults(dictionariesResults: [dictResults])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group,
            selectedDictionaryID: dictionaryUUID
        )

        let result = await resolver.resolve(.singleDictionaryGlossary(dictionaryID: dictionaryUUID))

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("<ol>"), "Missing ol element")
        #expect(html.contains("<li data-dictionary="), "Missing li with data-dictionary")
    }

    @Test func singleGlossary_usesFirstDisplayedDictionary() async {
        let firstDictionary = makeDictionaryResults(dictionaryTitle: "Dictionary A")
        let secondDictionary = makeDictionaryResults(dictionaryTitle: "Dictionary B")
        let group = makeGroupedSearchResults(dictionariesResults: [firstDictionary, secondDictionary])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.singleGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("data-dictionary=\"Dictionary A\""))
        #expect(!html.contains("data-dictionary=\"Dictionary B\""))
    }

    // MARK: - Multi Dictionary Glossary Tests

    @Test func multiDictionaryGlossary_hasYomitanGlossaryClass() async {
        let dict1 = makeDictionaryResults(dictionaryTitle: "Dictionary A")
        let dict2 = makeDictionaryResults(dictionaryTitle: "Dictionary B")
        let group = makeGroupedSearchResults(dictionariesResults: [dict1, dict2])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.multiDictionaryGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("class=\"yomitan-glossary\""), "Missing yomitan-glossary class for Lapis compatibility")
    }

    @Test func multiDictionaryGlossary_hasDataDictionaryForEachDictionary() async {
        let dict1Title = "Dictionary A"
        let dict2Title = "Dictionary B"
        let dict1 = makeDictionaryResults(dictionaryTitle: dict1Title)
        let dict2 = makeDictionaryResults(dictionaryTitle: dict2Title)
        let group = makeGroupedSearchResults(dictionariesResults: [dict1, dict2])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.multiDictionaryGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        #expect(html.contains("data-dictionary=\"\(dict1Title)\""), "Missing data-dictionary for first dictionary")
        #expect(html.contains("data-dictionary=\"\(dict2Title)\""), "Missing data-dictionary for second dictionary")
    }

    @Test func multiDictionaryGlossary_hasSingleOlWithMultipleLi() async {
        let dict1 = makeDictionaryResults(dictionaryTitle: "Dictionary 1")
        let dict2 = makeDictionaryResults(dictionaryTitle: "Dictionary 2")
        let dict3 = makeDictionaryResults(dictionaryTitle: "Dictionary 3")
        let group = makeGroupedSearchResults(dictionariesResults: [dict1, dict2, dict3])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.multiDictionaryGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        // Should have exactly one ol
        let olCount = html.components(separatedBy: "<ol>").count - 1
        #expect(olCount == 1, "Expected single ol element, found \(olCount)")

        // Should have li for each dictionary
        let liCount = html.components(separatedBy: "<li data-dictionary=").count - 1
        #expect(liCount == 3, "Expected 3 li elements with data-dictionary, found \(liCount)")
    }

    @Test func multiDictionaryGlossary_includesDictionaryNameInContent() async {
        let dictTitle = "Dictionary A"
        let dict = makeDictionaryResults(dictionaryTitle: dictTitle)
        let group = makeGroupedSearchResults(dictionariesResults: [dict])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.multiDictionaryGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        // Yomitan format includes dictionary name in italics: <i>(dict name)</i>
        #expect(html.contains("<i>(\(dictTitle))</i>"), "Missing italicized dictionary name in Yomitan format")
    }

    // MARK: - HTML Escaping Tests

    @Test func glossary_escapesDictionaryTitleInDataAttribute() async {
        let dictionaryTitle = "Dictionary with \"quotes\" & <special> chars"
        let dict = makeDictionaryResults(dictionaryTitle: dictionaryTitle)
        let group = makeGroupedSearchResults(dictionariesResults: [dict])
        let response = makeTextLookupResponse(selectedGroup: group)

        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: group
        )

        let result = await resolver.resolve(.multiDictionaryGlossary)

        guard let html = result.text else {
            Issue.record("Expected text in result")
            return
        }

        // Should escape HTML special characters
        #expect(!html.contains("data-dictionary=\"Dictionary with \"quotes\""), "Dictionary title not properly escaped in data-dictionary attribute")
        #expect(html.contains("&amp;"), "Ampersand should be escaped")
        #expect(html.contains("&lt;"), "Less-than should be escaped")
        #expect(html.contains("&gt;"), "Greater-than should be escaped")
    }
}
