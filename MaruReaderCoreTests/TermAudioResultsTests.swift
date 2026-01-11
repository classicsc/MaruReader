// TermAudioResultsTests.swift
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
@testable import MaruReaderCore
import Testing

struct TermAudioResultsTests {
    // MARK: - Test Helpers

    private func makeSource(pitchNumber: String?, name: String = "Test") -> AudioSourceResult {
        AudioSourceResult(
            url: URL(string: "https://example.com/\(UUID().uuidString).mp3")!,
            sourceName: name,
            sourceType: .urlPattern("test"),
            isLocal: false,
            pitchNumber: pitchNumber
        )
    }

    // MARK: - sources(forPitchPosition:requireExactMatch:) Tests

    @Test func sourcesForPitchPosition_withExactMatch_returnsOnlyMatchingSources() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")
        let sourceNil = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1, sourceNil]
        )

        let exactMatch = results.sources(forPitchPosition: "0", requireExactMatch: true)
        #expect(exactMatch.count == 1)
        #expect(exactMatch.first?.pitchNumber == "0")
    }

    @Test func sourcesForPitchPosition_withExactMatch_returnsEmptyWhenNoMatch() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")
        let sourceNil = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1, sourceNil]
        )

        let noMatch = results.sources(forPitchPosition: "5", requireExactMatch: true)
        #expect(noMatch.isEmpty)
    }

    @Test func sourcesForPitchPosition_withFallback_returnsAllWhenNoMatch() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1]
        )

        // Default behavior (requireExactMatch: false) falls back to all sources
        let fallback = results.sources(forPitchPosition: "5")
        #expect(fallback.count == 2)

        // Explicit requireExactMatch: false also falls back
        let explicitFallback = results.sources(forPitchPosition: "5", requireExactMatch: false)
        #expect(explicitFallback.count == 2)
    }

    @Test func sourcesForPitchPosition_withFallback_prefersMatchingWhenAvailable() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")
        let sourceNil = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1, sourceNil]
        )

        // When a match exists, returns only matching (no fallback needed)
        let matched = results.sources(forPitchPosition: "0", requireExactMatch: false)
        #expect(matched.count == 1)
        #expect(matched.first?.pitchNumber == "0")
    }

    @Test func sourcesForPitchPosition_nilPosition_withExactMatch_returnsEmpty() {
        let sourceNil = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [sourceNil]
        )

        // With requireExactMatch: true and nil position, return empty
        let noMatch = results.sources(forPitchPosition: nil, requireExactMatch: true)
        #expect(noMatch.isEmpty)
    }

    @Test func sourcesForPitchPosition_nilPosition_withFallback_returnsAll() {
        let source0 = makeSource(pitchNumber: "0")
        let sourceNil = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, sourceNil]
        )

        // With requireExactMatch: false and nil position, return all
        let allSources = results.sources(forPitchPosition: nil, requireExactMatch: false)
        #expect(allSources.count == 2)

        // Default (nil position) returns all
        let defaultSources = results.sources(forPitchPosition: nil)
        #expect(defaultSources.count == 2)
    }

    // MARK: - primaryURL(forPitchPosition:requireExactMatch:) Tests

    @Test func primaryURL_withExactMatch_returnsMatchingURL() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1]
        )

        let url = results.primaryURL(forPitchPosition: "0", requireExactMatch: true)
        #expect(url == source0.url)
    }

    @Test func primaryURL_withExactMatch_returnsNilWhenNoMatch() {
        let source0 = makeSource(pitchNumber: "0")

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0]
        )

        let url = results.primaryURL(forPitchPosition: "5", requireExactMatch: true)
        #expect(url == nil)
    }

    @Test func primaryURL_withFallback_returnsFirstAvailableWhenNoMatch() {
        let source0 = makeSource(pitchNumber: "0")
        let source1 = makeSource(pitchNumber: "1")

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [source0, source1]
        )

        // Falls back to first source when no pitch match
        let url = results.primaryURL(forPitchPosition: "5", requireExactMatch: false)
        #expect(url == source0.url)
    }

    // MARK: - URL Pattern Sources (nil pitchNumber) Behavior

    @Test func urlPatternSources_withExactMatch_neverShownForPitchResults() {
        // URL pattern sources have nil pitchNumber - they should never appear
        // in pitch-specific results when requireExactMatch is true
        let urlPatternSource = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [urlPatternSource]
        )

        // For any pitch position with requireExactMatch: true, should return empty
        #expect(results.sources(forPitchPosition: "0", requireExactMatch: true).isEmpty)
        #expect(results.sources(forPitchPosition: "1", requireExactMatch: true).isEmpty)
        #expect(results.sources(forPitchPosition: "2", requireExactMatch: true).isEmpty)
    }

    @Test func urlPatternSources_withFallback_stillAvailableForHeader() {
        // URL pattern sources should still be available for the header audio button
        // which uses the default fallback behavior
        let urlPatternSource = makeSource(pitchNumber: nil)

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [urlPatternSource]
        )

        // For header (uses fallback), URL pattern source should be available
        let sources = results.sources(forPitchPosition: "0", requireExactMatch: false)
        #expect(sources.count == 1)
    }

    @Test func mixedSources_exactMatchFiltersCorrectly() {
        // Mix of indexed sources (with pitch) and URL pattern sources (without pitch)
        let indexedSource0 = AudioSourceResult(
            url: URL(string: "https://example.com/indexed0.mp3")!,
            sourceName: "Indexed",
            sourceType: .indexed(UUID()),
            isLocal: true,
            pitchNumber: "0"
        )
        let indexedSource1 = AudioSourceResult(
            url: URL(string: "https://example.com/indexed1.mp3")!,
            sourceName: "Indexed",
            sourceType: .indexed(UUID()),
            isLocal: true,
            pitchNumber: "1"
        )
        let urlPatternSource = AudioSourceResult(
            url: URL(string: "https://example.com/pattern.mp3")!,
            sourceName: "URL Pattern",
            sourceType: .urlPattern("test"),
            isLocal: false,
            pitchNumber: nil
        )

        let results = TermAudioResults(
            expression: "test",
            reading: "てすと",
            sources: [indexedSource0, indexedSource1, urlPatternSource]
        )

        // Exact match for pitch 0 should only return indexed source with pitch 0
        let exactPitch0 = results.sources(forPitchPosition: "0", requireExactMatch: true)
        #expect(exactPitch0.count == 1)
        #expect(exactPitch0.first?.pitchNumber == "0")
        #expect(exactPitch0.first?.sourceName == "Indexed")

        // Exact match for pitch 2 (none exist) should return empty
        let exactPitch2 = results.sources(forPitchPosition: "2", requireExactMatch: true)
        #expect(exactPitch2.isEmpty)

        // Fallback for pitch 2 should return all 3 sources
        let fallbackPitch2 = results.sources(forPitchPosition: "2", requireExactMatch: false)
        #expect(fallbackPitch2.count == 3)
    }
}
