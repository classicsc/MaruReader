// PitchAccentCategoriesResolverTests.swift
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

struct PitchAccentCategoriesResolverTests {
    @Test func pitchAccentCategories_resolvesCommaSeparated() async {
        let pitchA = PitchAccent(position: .mora(0), nasal: nil, devoice: nil, tags: nil)
        let pitchB = PitchAccent(position: .mora(2), nasal: nil, devoice: nil, tags: nil)
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: UUID(), priority: 0, pitches: [pitchA, pitchB]),
        ]
        let tags = [MaruReaderCore.Tag(name: "n", category: "partOfSpeech", notes: "", order: 0, score: 0)]
        let group = GroupedSearchResults(
            termKey: "本|ほん",
            expression: "本",
            reading: "ほん",
            dictionariesResults: [],
            pitchAccentResults: pitchResults,
            termTags: tags
        )
        let response = makeResponse(primaryResult: "本", group: group)
        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let resolved = await resolver.resolve(.pitchAccentCategories)
        #expect(resolved.text == "heiban,odaka")
    }

    @Test func pitchAccentCategories_fallsBackToPitchTags() async {
        let pitch = PitchAccent(position: .mora(2), nasal: nil, devoice: nil, tags: ["v1"])
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: UUID(), priority: 0, pitches: [pitch]),
        ]
        let group = GroupedSearchResults(
            termKey: "食べる|たべる",
            expression: "食べる",
            reading: "たべる",
            dictionariesResults: [],
            pitchAccentResults: pitchResults,
            termTags: []
        )
        let response = makeResponse(primaryResult: "食べる", group: group)
        let resolver = TextLookupResponseTemplateResolver(response: response, selectedGroup: group)

        let resolved = await resolver.resolve(.pitchAccentCategories)
        #expect(resolved.text == "kifuku")
    }

    private func makeResponse(primaryResult: String, group: GroupedSearchResults) -> TextLookupResponse {
        let request = TextLookupRequest(context: primaryResult)
        let styles = DisplayStyles(
            fontFamily: DictionaryDisplayFontFamilyStacks.sansSerif,
            contentFontSize: 1,
            popupFontSize: 1,
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )
        return TextLookupResponse(
            request: request,
            results: [group],
            primaryResult: primaryResult,
            primaryResultSourceRange: primaryResult.startIndex ..< primaryResult.endIndex,
            styles: styles
        )
    }
}
