// PitchAccentCategoryCalculatorTests.swift
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

struct PitchAccentCategoryCalculatorTests {
    @Test func moraCount_handlesSmallKana() {
        #expect(PitchAccentCategoryCalculator.moraCount(for: "きょう") == 2)
        #expect(PitchAccentCategoryCalculator.moraCount(for: "がっこう") == 4)
    }

    @Test func downstepPosition_patternCalculations() {
        #expect(PitchAccentCategoryCalculator.downstepPosition(for: .pattern("HLL")) == 1)
        #expect(PitchAccentCategoryCalculator.downstepPosition(for: .pattern("LHH")) == 0)
        #expect(PitchAccentCategoryCalculator.downstepPosition(for: .pattern("HHH")) == nil)
    }

    @Test func categories_usePartOfSpeechTags() {
        let pitch = PitchAccent(position: .mora(2), nasal: nil, devoice: nil, tags: nil)
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: UUID(), priority: 0, pitches: [pitch]),
        ]
        let tags = [Tag(name: "v1", category: "partOfSpeech")]
        let group = GroupedSearchResults(
            termKey: "食べる|たべる",
            expression: "食べる",
            reading: "たべる",
            dictionariesResults: [],
            pitchAccentResults: pitchResults,
            termTags: tags,
            deinflectionInfo: nil
        )

        let categories = PitchAccentCategoryCalculator.categories(for: group)
        #expect(categories == [.kifuku])
    }

    @Test func categories_fallbackToPitchTags() {
        let pitch = PitchAccent(position: .mora(2), nasal: nil, devoice: nil, tags: ["v5k"])
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: UUID(), priority: 0, pitches: [pitch]),
        ]
        let group = GroupedSearchResults(
            termKey: "歩く|あるく",
            expression: "歩く",
            reading: "あるく",
            dictionariesResults: [],
            pitchAccentResults: pitchResults,
            termTags: [],
            deinflectionInfo: nil
        )

        let categories = PitchAccentCategoryCalculator.categories(for: group)
        #expect(categories == [.kifuku])
    }
}
