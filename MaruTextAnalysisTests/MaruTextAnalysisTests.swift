// MaruTextAnalysisTests.swift
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
@testable import MaruTextAnalysis
import Testing

private final class InstalledTokenizerDictionaryFixtureState: @unchecked Sendable {
    let lock = NSLock()
    var url: URL?
}

struct MaruTextAnalysisTests {
    private static let installedTokenizerDictionaryFixtureState = InstalledTokenizerDictionaryFixtureState()

    @Test func installedTokenizerDictionary_isPresentAtOverrideLocation() throws {
        let directoryURL = try makeInstalledTokenizerDictionaryFixture()
        InstalledTokenizerDictionary.overrideDirectoryURL = directoryURL

        let resolvedDirectoryURL = try InstalledTokenizerDictionary.directoryURL()

        #expect(FileManager.default.fileExists(atPath: resolvedDirectoryURL.appendingPathComponent("char.def").path))
        #expect(FileManager.default.fileExists(atPath: resolvedDirectoryURL.appendingPathComponent("rewrite.def").path))
        #expect(FileManager.default.fileExists(atPath: resolvedDirectoryURL.appendingPathComponent("sudachi.json").path))
        #expect(FileManager.default.fileExists(atPath: resolvedDirectoryURL.appendingPathComponent("system_full.dic").path))
        #expect(FileManager.default.fileExists(atPath: resolvedDirectoryURL.appendingPathComponent("unk.def").path))
        #expect(InstalledTokenizerDictionary.version() == nil)
    }

    @Test func sharedAnalyzer_warmsUpSuccessfully() throws {
        InstalledTokenizerDictionary.overrideDirectoryURL = try makeInstalledTokenizerDictionaryFixture()
        let analyzer = try #require(try? SharedSudachiAnalyzer.result.get())
        #expect(throws: Never.self) {
            try analyzer.warmUp()
        }
    }

    @Test func emptyString_returnsEmpty() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let result = FuriganaGenerator.generateSegments(from: "")
        #expect(result.isEmpty)
    }

    @Test func kanaOnly_hasNoReadings() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let segments = FuriganaGenerator.generateSegments(from: "これはひらがなです")
        #expect(segments.allSatisfy { $0.reading == nil })
    }

    @Test func okurigana_isSplitFromKanjiReading() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let segments = FuriganaGenerator.generateSegments(from: "食べる")

        #expect(segments.count == 2)
        #expect(segments[0].base == "食")
        #expect(segments[0].reading == "た")
        #expect(segments[1].base == "べる")
        #expect(segments[1].reading == nil)
    }

    @Test func allKanjiWord_keepsFullReading() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let segments = FuriganaGenerator.generateSegments(from: "日本語")

        #expect(segments.count == 1)
        #expect(segments[0].base == "日本語")
        #expect(segments[0].reading == "にほんご")
    }

    @Test func punctuationAndMixedLatinText_arePreserved() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let segments = FuriganaGenerator.generateSegments(from: "ABCは日本語です。")
        let formatted = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(formatted.contains("ABC"))
        #expect(formatted.contains("日本語[にほんご]"))
        #expect(formatted.contains("。"))
    }

    @Test func segmentRanges_coverEntireSourceText() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let text = "私は学生です"
        let segments = FuriganaGenerator.generateSegments(from: text)

        var expectedStart = text.startIndex
        for segment in segments {
            #expect(segment.baseRange.lowerBound == expectedStart)
            #expect(String(text[segment.baseRange]) == segment.base)
            expectedStart = segment.baseRange.upperBound
        }

        #expect(expectedStart == text.endIndex)
    }

    @Test func formatAnkiStyle_stripsOkuriganaFromReading() {
        InstalledTokenizerDictionary.overrideDirectoryURL = try? makeInstalledTokenizerDictionaryFixture()
        let segments = FuriganaGenerator.generateSegments(from: "食べる")
        let formatted = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(formatted == "食[た]べる")
    }

    @Test func formatCloze_splitsAroundSelection() throws {
        InstalledTokenizerDictionary.overrideDirectoryURL = try makeInstalledTokenizerDictionaryFixture()
        let text = "私は学校へ行く"
        let segments = FuriganaGenerator.generateSegments(from: text)
        let selectionRange = try #require(text.range(of: "学校"))

        let cloze = FuriganaGenerator.formatCloze(segments, selectionRange: selectionRange, in: text)

        #expect(cloze.prefix.contains("私"))
        #expect(cloze.body.contains("学校"))
        #expect(cloze.suffix.contains("行"))
    }

    private func makeInstalledTokenizerDictionaryFixture() throws -> URL {
        Self.installedTokenizerDictionaryFixtureState.lock.lock()
        if let cachedInstalledTokenizerDirectory = Self.installedTokenizerDictionaryFixtureState.url {
            Self.installedTokenizerDictionaryFixtureState.lock.unlock()
            return cachedInstalledTokenizerDirectory
        }
        Self.installedTokenizerDictionaryFixtureState.lock.unlock()

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceDirectory = repoRoot.appendingPathComponent("build/sudachi/v20260116-full", isDirectory: true)

        #expect(FileManager.default.fileExists(atPath: resourceDirectory.appendingPathComponent("system_full.dic").path))

        Self.installedTokenizerDictionaryFixtureState.lock.lock()
        Self.installedTokenizerDictionaryFixtureState.url = resourceDirectory
        Self.installedTokenizerDictionaryFixtureState.lock.unlock()
        return resourceDirectory
    }
}
