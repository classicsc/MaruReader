// FrequencyDisplayPriorityTests.swift
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

struct FrequencyDisplayPriorityTests {
    private func makeMetadata(
        id: UUID,
        title: String,
        displayPriority: Int,
        rankingEnabled: Bool
    ) -> DictionaryMetadata {
        DictionaryMetadata(
            id: id,
            title: title,
            termDisplayPriority: 0,
            termFrequencyDisplayPriority: displayPriority,
            pitchDisplayPriority: 0,
            frequencyMode: "rank-based",
            termResultsEnabled: true,
            termFrequencyEnabled: rankingEnabled,
            pitchAccentEnabled: false
        )
    }

    @Test func rankingFrequency_usesEnabledDictionaryNotDisplayPriority() {
        let displayFirstID = UUID()
        let rankingID = UUID()

        let metadata: [UUID: DictionaryMetadata] = [
            displayFirstID: makeMetadata(
                id: displayFirstID,
                title: "Display First",
                displayPriority: 0,
                rankingEnabled: false
            ),
            rankingID: makeMetadata(
                id: rankingID,
                title: "Ranking",
                displayPriority: 5,
                rankingEnabled: true
            ),
        ]

        let frequencies = [
            FrequencyInfo(
                dictionaryID: displayFirstID,
                dictionaryTitle: "Display First",
                value: 100,
                displayValue: nil,
                mode: "rank-based",
                priority: 0
            ),
            FrequencyInfo(
                dictionaryID: rankingID,
                dictionaryTitle: "Ranking",
                value: 500,
                displayValue: nil,
                mode: "rank-based",
                priority: 5
            ),
        ]

        let selected = TermFetcher.rankingFrequency(from: frequencies, dictionaryMetadata: metadata)

        #expect(selected?.dictionaryID == rankingID)
        #expect(selected?.value == 500)
    }

    @Test func frequencyDisplayHTML_usesDisplayPriorityForButtonAndExpandedOrder() {
        let candidate = LookupCandidate(from: "猫")

        let frequencies = [
            FrequencyInfo(
                dictionaryID: UUID(),
                dictionaryTitle: "Low Priority Dict",
                value: 999,
                displayValue: nil,
                mode: "rank-based",
                priority: 8
            ),
            FrequencyInfo(
                dictionaryID: UUID(),
                dictionaryTitle: "High Priority Dict",
                value: 100,
                displayValue: nil,
                mode: "rank-based",
                priority: 0
            ),
        ]

        let ranking = RankingCriteria(
            sourceTermLength: 1,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "Definitions",
            definitionCount: 1,
            term: "猫"
        )

        let result = SearchResult(
            candidate: candidate,
            term: "猫",
            reading: "ねこ",
            definitions: [.text("cat")],
            frequency: nil,
            frequencies: frequencies,
            pitchAccents: [],
            dictionaryTitle: "Definitions",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: ranking,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 0,
            score: 0
        )

        let dictionaryResults = DictionaryResults(
            dictionaryTitle: "Definitions",
            dictionaryUUID: result.dictionaryUUID,
            sequence: 0,
            score: 0,
            results: [result]
        )

        let group = GroupedSearchResults(
            termKey: "猫|ねこ",
            expression: "猫",
            reading: "ねこ",
            dictionariesResults: [dictionaryResults],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )

        let renderer = DictionaryResultsHTMLRenderer(
            styles: DisplayStyles(
                fontFamily: "Test",
                contentFontSize: 1,
                popupFontSize: 1,
                showDeinflection: false,
                deinflectionDescriptionLanguage: "system",
                pitchDownstepNotationInHeaderEnabled: false,
                pitchResultsAreaCollapsedDisplay: false,
                pitchResultsAreaDownstepNotationEnabled: false,
                pitchResultsAreaDownstepPositionEnabled: false,
                pitchResultsAreaEnabled: false
            )
        )

        let html = renderer.termGroupHTML(group)
        #expect(html.contains("title=\"High Priority Dict: rank-based\""))
        #expect(html.contains(">100</button>"))
        #expect(html.contains("High Priority Dict: 100"))
        #expect(html.contains("Low Priority Dict: 999"))

        guard let highIndex = html.range(of: "High Priority Dict: 100")?.lowerBound,
              let lowIndex = html.range(of: "Low Priority Dict: 999")?.lowerBound
        else {
            Issue.record("Expected frequency labels were not found in rendered HTML")
            return
        }

        #expect(highIndex < lowIndex)
    }

    @Test func frequencyDisplayHTML_usesLocalizedFallbackModeWhenMetadataIsMissing() {
        let candidate = LookupCandidate(from: "猫")

        let frequency = FrequencyInfo(
            dictionaryID: UUID(),
            dictionaryTitle: "Fallback Dict",
            value: 42,
            displayValue: nil,
            mode: nil,
            priority: 0
        )

        let ranking = RankingCriteria(
            sourceTermLength: 1,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "Definitions",
            definitionCount: 1,
            term: "猫"
        )

        let result = SearchResult(
            candidate: candidate,
            term: "猫",
            reading: "ねこ",
            definitions: [.text("cat")],
            frequency: nil,
            frequencies: [frequency],
            pitchAccents: [],
            dictionaryTitle: "Definitions",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: ranking,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 0,
            score: 0
        )

        let dictionaryResults = DictionaryResults(
            dictionaryTitle: "Definitions",
            dictionaryUUID: result.dictionaryUUID,
            sequence: 0,
            score: 0,
            results: [result]
        )

        let group = GroupedSearchResults(
            termKey: "猫|ねこ",
            expression: "猫",
            reading: "ねこ",
            dictionariesResults: [dictionaryResults],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )

        let renderer = DictionaryResultsHTMLRenderer(
            styles: DisplayStyles(
                fontFamily: "Test",
                contentFontSize: 1,
                popupFontSize: 1,
                showDeinflection: false,
                deinflectionDescriptionLanguage: "system",
                pitchDownstepNotationInHeaderEnabled: false,
                pitchResultsAreaCollapsedDisplay: false,
                pitchResultsAreaDownstepNotationEnabled: false,
                pitchResultsAreaDownstepPositionEnabled: false,
                pitchResultsAreaEnabled: false
            )
        )

        let html = renderer.termGroupHTML(group)
        let fallbackMode = FrameworkLocalization.string(
            "dictionary.frequency.mode.rankAuto",
            defaultValue: "rank-based (auto)"
        )

        #expect(html.contains("title=\"Fallback Dict: \(fallbackMode)\""))
        #expect(html.contains("Fallback Dict: 42"))
    }
}
