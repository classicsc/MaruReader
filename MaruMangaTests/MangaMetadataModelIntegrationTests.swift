// MangaMetadataModelIntegrationTests.swift
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
import Testing

private let runtimeSupportProbe = MangaMetadataExtractionRuntimeSupportProbe()

/// Real titles and authors are included because the Foundation Model's
/// performance appears to vary between familiar and unfamiliar names.
/// The quality matrix remains observational rather than strict because
/// Foundation Model outputs can still vary between runs.
@Suite(
    .enabled("Foundation Models filename extraction is unavailable in this environment.") {
        await runtimeSupportProbe.isSupported()
    }
)
struct MangaMetadataModelIntegrationTests {
    @Test("Filename extraction returns English title and author")
    func filenameExtractionEnglishTitleAndAuthor() async {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "Chainsaw Man - Tatsuki Fujimoto.cbz")

        #expect(metadata.title == "Chainsaw Man")
        #expect(metadata.author == "Tatsuki Fujimoto")
    }

    @Test("Filename extraction returns Japanese title and author")
    func filenameExtractionJapaneseTitleAndAuthor() async {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "【石黒正数】それでも町は廻っている 第01巻.zip")

        #expect(metadata.title == "それでも町は廻っている 第01巻")
        #expect(metadata.author == "石黒正数")
    }

    @Test("Filename extraction keeps the volume in the title")
    func filenameExtractionJapaneseWithVolume() async {
        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "[Library Edition] 呪術廻戦 10巻 芥見下々.cbz")

        #expect(metadata.title == "呪術廻戦 10巻")
        #expect(metadata.author == "芥見下々")
    }

    @Test("Filename extraction quality matrix remains observational")
    func filenameExtractionQualityMatrix() async {
        let extractor = MangaFilenameMetadataExtractor()

        for testCase in Self.observationalCases {
            let metadata = await extractor.extract(from: testCase.filename)

            withKnownIssue(
                "Foundation Models output is nondeterministic; title mismatches in the quality matrix are observational.",
                isIntermittent: true
            ) {
                #expect(metadata.title == testCase.title, "Filename: \(testCase.filename)")
            }

            withKnownIssue(
                "Foundation Models output is nondeterministic; author mismatches in the quality matrix are observational.",
                isIntermittent: true
            ) {
                #expect(metadata.author == testCase.author, "Filename: \(testCase.filename)")
            }
        }
    }

    private struct ExpectedMetadataCase {
        let filename: String
        let title: String
        let author: String
    }

    private static let observationalCases = [
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
}

private actor MangaMetadataExtractionRuntimeSupportProbe {
    private var cachedResult: Bool?

    func isSupported() async -> Bool {
        if let cachedResult {
            return cachedResult
        }

        guard MangaFilenameMetadataExtractor.isModelAvailable else {
            cachedResult = false
            return false
        }

        let extractor = MangaFilenameMetadataExtractor()
        let metadata = await extractor.extract(from: "Chainsaw Man - Tatsuki Fujimoto.cbz")
        let isSupported = metadata.titleWasExtracted && metadata.authorWasExtracted
        cachedResult = isSupported
        return isSupported
    }
}
