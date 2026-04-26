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
final class MangaMetadataExtractionTests: XCTestCase {
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
}
