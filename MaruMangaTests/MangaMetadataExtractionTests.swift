// MangaMetadataExtractionTests.swift
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
@testable import MaruManga
import XCTest

/// Tests for manga metadata extraction functionality.
/// Real titles and authors are included because the Foundation Model's
/// performance appears to vary between familiar and unfamiliar names.
/// The quality matrix remains observational rather than strict because
/// Foundation Model outputs can still vary between runs.
final class MangaMetadataExtractionTests: XCTestCase {
    private struct ExpectedMetadataCase {
        let filename: String
        let title: String
        let author: String
    }

    func testParseOutputTracksExtractedFlags() {
        let extractor = MangaFilenameMetadataExtractor()
        let output = """
        Title: Golden Fist Man Chapter 1
        Author: Koji Tanaka
        """

        let metadata = extractor.parseOutput(output, fallbackTitle: "Fallback")

        XCTAssertEqual(metadata?.title, "Golden Fist Man Chapter 1")
        XCTAssertEqual(metadata?.author, "Koji Tanaka")
        XCTAssertEqual(metadata?.titleWasExtracted, true)
        XCTAssertEqual(metadata?.authorWasExtracted, true)
    }

    func testParseOutputUsesFallbackFlagsWhenEmpty() {
        let extractor = MangaFilenameMetadataExtractor()
        let output = """
        Title:
        Author:
        """

        let metadata = extractor.parseOutput(output, fallbackTitle: "Fallback")

        XCTAssertEqual(metadata?.title, "Fallback")
        XCTAssertEqual(metadata?.author, "")
        XCTAssertEqual(metadata?.titleWasExtracted, false)
        XCTAssertEqual(metadata?.authorWasExtracted, false)
    }

    func testParseOutputAcceptsMinorFormattingVariations() {
        let extractor = MangaFilenameMetadataExtractor()
        let output = """

           TITLE : Golden Fist Man Chapter 1

          author:   Koji Tanaka
        """

        let metadata = extractor.parseOutput(output, fallbackTitle: "Fallback")

        XCTAssertEqual(metadata?.title, "Golden Fist Man Chapter 1")
        XCTAssertEqual(metadata?.author, "Koji Tanaka")
        XCTAssertEqual(metadata?.titleWasExtracted, true)
        XCTAssertEqual(metadata?.authorWasExtracted, true)
    }

    func testParseOutputRejectsCommentary() {
        let extractor = MangaFilenameMetadataExtractor()
        let output = """
        Here is the extracted metadata:
        Title: Golden Fist Man Chapter 1
        Author: Koji Tanaka
        """

        let metadata = extractor.parseOutput(output, fallbackTitle: "Fallback")

        XCTAssertNil(metadata)
    }

    func testParseOutputRejectsDuplicateLabels() {
        let extractor = MangaFilenameMetadataExtractor()
        let output = """
        Title: Golden Fist Man Chapter 1
        Title: Duplicate
        Author: Koji Tanaka
        """

        let metadata = extractor.parseOutput(output, fallbackTitle: "Fallback")

        XCTAssertNil(metadata)
    }

    func testNormalizedPromptInputCollapsesWhitespaceAndRemovesExtension() {
        let extractor = MangaFilenameMetadataExtractor()

        XCTAssertEqual(
            extractor.normalizedPromptInput(for: "  [Library Edition]\n呪術廻戦\t 10巻   芥見下々.cbz "),
            "[Library Edition] 呪術廻戦 10巻 芥見下々"
        )
    }

    func testHeuristicMetadataExtractsDashedEnglishAuthor() {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = extractor.heuristicMetadata(
            for: "Chainsaw Man - Tatsuki Fujimoto.cbz",
            fallbackTitle: "Chainsaw Man - Tatsuki Fujimoto"
        )

        XCTAssertEqual(metadata?.title, "Chainsaw Man")
        XCTAssertEqual(metadata?.author, "Tatsuki Fujimoto")
        XCTAssertEqual(metadata?.titleWasExtracted, true)
        XCTAssertEqual(metadata?.authorWasExtracted, true)
    }

    func testHeuristicMetadataExtractsLeadingBracketedJapaneseAuthor() {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = extractor.heuristicMetadata(
            for: "【石黒正数】それでも町は廻っている 第01巻.zip",
            fallbackTitle: "【石黒正数】それでも町は廻っている 第01巻"
        )

        XCTAssertEqual(metadata?.title, "それでも町は廻っている 第01巻")
        XCTAssertEqual(metadata?.author, "石黒正数")
        XCTAssertEqual(metadata?.titleWasExtracted, true)
        XCTAssertEqual(metadata?.authorWasExtracted, true)
    }

    func testHeuristicMetadataExtractsTrailingJapaneseAuthor() {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = extractor.heuristicMetadata(
            for: "[Library Edition] 呪術廻戦 10巻 芥見下々.cbz",
            fallbackTitle: "[Library Edition] 呪術廻戦 10巻 芥見下々"
        )

        XCTAssertEqual(metadata?.title, "呪術廻戦 10巻")
        XCTAssertEqual(metadata?.author, "芥見下々")
        XCTAssertEqual(metadata?.titleWasExtracted, true)
        XCTAssertEqual(metadata?.authorWasExtracted, true)
    }

    func testExtractMetadataUsesFallbackWhenSmartExtractionDisabled() async {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extractMetadata(
            from: "[Library Edition] 呪術廻戦 10巻 芥見下々.cbz",
            useSmartExtraction: false
        )

        XCTAssertEqual(metadata.title, "[Library Edition] 呪術廻戦 10巻 芥見下々")
        XCTAssertEqual(metadata.author, "")
        XCTAssertFalse(metadata.titleWasExtracted)
        XCTAssertFalse(metadata.authorWasExtracted)
    }

    func testFilenameExtractionEnglishTitleAndAuthor() async throws {
        try requireModelAvailability()

        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "Chainsaw Man - Tatsuki Fujimoto.cbz")

        XCTAssertEqual(metadata.title, "Chainsaw Man")
        XCTAssertEqual(metadata.author, "Tatsuki Fujimoto")
    }

    func testFilenameExtractionJapaneseTitleAndAuthor() async throws {
        try requireModelAvailability()

        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "【石黒正数】それでも町は廻っている 第01巻.zip")

        XCTAssertEqual(metadata.title, "それでも町は廻っている 第01巻")
        XCTAssertEqual(metadata.author, "石黒正数")
    }

    func testFilenameExtractionJapaneseWithVolume() async throws {
        try requireModelAvailability()

        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "[Library Edition] 呪術廻戦 10巻 芥見下々.cbz")

        XCTAssertEqual(metadata.title, "呪術廻戦 10巻")
        XCTAssertEqual(metadata.author, "芥見下々")
    }

    func testFilenameExtractionQualityMatrix() async throws {
        try requireModelAvailability()

        let options = XCTExpectedFailure.Options()
        options.isStrict = false

        let extractor = MangaFilenameMetadataExtractor()
        let cases = [
            ExpectedMetadataCase(
                filename: "golden_fist_man_chapter_1.cbz",
                title: "Golden Fist Man Chapter 1",
                author: ""
            ),
            ExpectedMetadataCase(
                filename: "[Archive] (博之なこ) 赤い魚 第１巻 [600p].zip",
                title: "赤い魚 第１巻",
                author: "博之なこ"
            ),
            ExpectedMetadataCase(
                filename: "[Library Edition][Bonus] ワンピース 第010巻 尾田栄一郎.cbz",
                title: "ワンピース 第010巻",
                author: "尾田栄一郎"
            ),
            ExpectedMetadataCase(
                filename: "ダンダダン_第02巻_龍幸伸.zip",
                title: "ダンダダン 第02巻",
                author: "龍幸伸"
            ),
            ExpectedMetadataCase(
                filename: "(吾峠呼世晴) 鬼滅の刃 23巻 [ja].cbz",
                title: "鬼滅の刃 23巻",
                author: "吾峠呼世晴"
            ),
        ]

        for testCase in cases {
            let metadata = await extractor.extract(from: testCase.filename)
            XCTExpectFailure(
                "Foundation Models output is nondeterministic; title mismatches in the quality matrix are observational.",
                options: options
            )
            XCTAssertEqual(metadata.title, testCase.title, "Filename: \(testCase.filename)")

            XCTExpectFailure(
                "Foundation Models output is nondeterministic; author mismatches in the quality matrix are observational.",
                options: options
            )
            XCTAssertEqual(metadata.author, testCase.author, "Filename: \(testCase.filename)")
        }
    }

    func testSmartMetadataExtractionSettingDefaultsToEnabled() {
        let defaults = UserDefaults.standard
        let key = MangaMetadataExtractionSettings.smartExtractionEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        XCTAssertEqual(
            MangaMetadataExtractionSettings.smartExtractionEnabled,
            MangaMetadataExtractionSettings.smartExtractionEnabledDefault
        )
    }

    func testSmartMetadataExtractionSettingPersistsChanges() {
        let defaults = UserDefaults.standard
        let key = MangaMetadataExtractionSettings.smartExtractionEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        MangaMetadataExtractionSettings.smartExtractionEnabled = false
        XCTAssertEqual(MangaMetadataExtractionSettings.smartExtractionEnabled, false)
        MangaMetadataExtractionSettings.smartExtractionEnabled = true
        XCTAssertEqual(MangaMetadataExtractionSettings.smartExtractionEnabled, true)
    }

    func testSmartMetadataExtractionSettingDisabledInScreenshotMode() {
        XCTAssertFalse(
            MangaMetadataExtractionSettings.resolvedSmartExtractionEnabled(
                storedValue: true,
                processArguments: [MangaMetadataExtractionSettings.screenshotModeArgument]
            )
        )
        XCTAssertFalse(
            MangaMetadataExtractionSettings.resolvedSmartExtractionEnabled(
                storedValue: nil,
                processArguments: ["app", MangaMetadataExtractionSettings.screenshotModeArgument]
            )
        )
    }

    func testSmartMetadataExtractionSettingKeepsStoredPreferenceOutsideScreenshotMode() {
        XCTAssertTrue(
            MangaMetadataExtractionSettings.resolvedSmartExtractionEnabled(
                storedValue: true,
                processArguments: []
            )
        )
        XCTAssertFalse(
            MangaMetadataExtractionSettings.resolvedSmartExtractionEnabled(
                storedValue: false,
                processArguments: []
            )
        )
    }

    func testMetadataExtractorAvailabilityHelperMatchesExtractor() {
        XCTAssertEqual(
            MangaImportManager.isMetadataExtractorAvailable,
            MangaFilenameMetadataExtractor.isModelAvailable
        )
    }

    private func requireModelAvailability() throws {
        guard MangaFilenameMetadataExtractor.isModelAvailable else {
            throw XCTSkip("Foundation Models are unavailable on this device.")
        }
    }
}
