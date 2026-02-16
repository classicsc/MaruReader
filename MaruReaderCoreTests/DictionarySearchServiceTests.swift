// DictionarySearchServiceTests.swift
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

struct DictionarySearchServiceTests {
    @Test func groupResults_deduplicatesPitchAccentsAcrossTermDictionaries() {
        let candidate = LookupCandidate(from: "neko")
        let pitchDictionaryID = UUID()
        let pitch = PitchAccent(position: .mora(1))
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: pitchDictionaryID, priority: 0, pitches: [pitch]),
        ]

        let definitions: [Definition] = [.text("definition")]

        let rankingA = RankingCriteria(
            sourceTermLength: 4,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "TermDictA",
            definitionCount: definitions.count,
            term: "neko"
        )

        let rankingB = RankingCriteria(
            sourceTermLength: 4,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "TermDictB",
            definitionCount: definitions.count,
            term: "猫"
        )

        let resultA = SearchResult(
            candidate: candidate,
            term: "neko",
            reading: "neko",
            definitions: definitions,
            frequency: nil,
            frequencies: [],
            pitchAccents: pitchResults,
            dictionaryTitle: "TermDictA",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: rankingA,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 0,
            score: 0
        )

        let resultB = SearchResult(
            candidate: candidate,
            term: "neko",
            reading: "neko",
            definitions: definitions,
            frequency: nil,
            frequencies: [],
            pitchAccents: pitchResults,
            dictionaryTitle: "TermDictB",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: rankingB,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 1,
            score: 0
        )

        let grouped = DictionarySearchService.groupResults([resultA, resultB])

        #expect(grouped.count == 1)
        #expect(grouped[0].pitchAccentResults.count == 1)
        #expect(grouped[0].pitchAccentResults.first?.pitches.count == 1)
        #expect(grouped[0].pitchAccentResults.first?.dictionaryID == pitchDictionaryID)
    }
}
