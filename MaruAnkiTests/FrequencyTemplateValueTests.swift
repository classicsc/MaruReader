// FrequencyTemplateValueTests.swift
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

struct FrequencyTemplateValueTests {
    private func makeFrequency(
        dictionaryID: UUID = UUID(),
        dictionaryTitle: String,
        value: Double,
        mode: String?
    ) -> FrequencyInfo {
        FrequencyInfo(
            dictionaryID: dictionaryID,
            dictionaryTitle: dictionaryTitle,
            value: value,
            displayValue: nil,
            mode: mode,
            priority: 0
        )
    }

    private func makeGroup(frequencies: [FrequencyInfo]) -> GroupedSearchResults {
        let candidate = LookupCandidate(from: "語る")
        let rankingCriteria = RankingCriteria(
            sourceTermLength: 2,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: frequencies.first?.value,
            frequencyMode: frequencies.first?.mode,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "Dictionary A",
            definitionCount: 1,
            term: "語る"
        )
        let result = SearchResult(
            candidate: candidate,
            term: "語る",
            reading: "かたる",
            definitions: [.text("to tell")],
            frequency: frequencies.first?.value,
            frequencies: frequencies,
            pitchAccents: [],
            dictionaryTitle: "Dictionary A",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: rankingCriteria,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 1,
            score: 0
        )
        let dictionaryResults = DictionaryResults(
            dictionaryTitle: "Dictionary A",
            dictionaryUUID: UUID(),
            sequence: 1,
            score: 0,
            results: [result]
        )
        return GroupedSearchResults(
            termKey: "語る|かたる",
            expression: "語る",
            reading: "かたる",
            dictionariesResults: [dictionaryResults],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )
    }

    private func makeResponse(group: GroupedSearchResults) -> TextLookupResponse {
        let request = TextLookupRequest(context: "語る", offset: 0)
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

        return TextLookupResponse(
            request: request,
            results: [group],
            primaryResult: "語る",
            primaryResultSourceRange: request.context.startIndex ..< request.context.endIndex,
            styles: styles
        )
    }

    private func makeResolver(frequencies: [FrequencyInfo]) -> TextLookupResponseTemplateResolver {
        let group = makeGroup(frequencies: frequencies)
        let response = makeResponse(group: group)
        return TextLookupResponseTemplateResolver(response: response, selectedGroup: group)
    }

    private func harmonicMeanText(_ values: [Double]) -> String {
        let reciprocalSum = values.reduce(0.0) { $0 + 1.0 / $1 }
        return String(Int(Double(values.count) / reciprocalSum))
    }

    @Test func frequencyRankHarmonicMeanSortField_includesImplicitRankBasedDictionaries() async {
        let resolver = makeResolver(frequencies: [
            makeFrequency(dictionaryTitle: "BCCWJ", value: 2424, mode: nil),
            makeFrequency(dictionaryTitle: "Narou", value: 4276, mode: "rank-based"),
            makeFrequency(dictionaryTitle: "Occurrences", value: 12000, mode: "occurrence-based"),
        ])

        let result = await resolver.resolve(.frequencyRankHarmonicMeanSortField)

        #expect(result.text == harmonicMeanText([2424, 4276]))
    }

    @Test func frequencyOccurrenceHarmonicMeanSortField_excludesImplicitRankBasedDictionaries() async {
        let resolver = makeResolver(frequencies: [
            makeFrequency(dictionaryTitle: "BCCWJ", value: 2424, mode: nil),
            makeFrequency(dictionaryTitle: "Occurrences A", value: 100, mode: "occurrence-based"),
            makeFrequency(dictionaryTitle: "Occurrences B", value: 400, mode: "occurrence-based"),
        ])

        let result = await resolver.resolve(.frequencyOccurrenceHarmonicMeanSortField)

        #expect(result.text == harmonicMeanText([100, 400]))
    }

    @Test func frequencyRankSortField_fallsBackToImplicitRankBasedDictionary() async {
        let resolver = makeResolver(frequencies: [
            makeFrequency(dictionaryTitle: "BCCWJ", value: 2424, mode: nil),
            makeFrequency(dictionaryTitle: "Occurrences", value: 12000, mode: "occurrence-based"),
        ])

        let result = await resolver.resolve(.frequencyRankSortField(dictionaryID: UUID()))

        #expect(result.text == "2424")
    }
}
