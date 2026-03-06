// FrameworkLocalizationTests.swift
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

struct FrameworkLocalizationTests {
    @Test func literalKeysResolveFromFrameworkBundleForJapaneseLocale() {
        let localization = Locale.Language(identifier: "ja")
        let cases: [(key: String, expected: String)] = [
            ("Import complete.", "インポートが完了しました。"),
            ("Processing audio entries...", "音声エントリを処理中..."),
            ("Processing dictionary index...", "辞書インデックスを処理中..."),
            ("Copied media files.", "メディアファイルをコピーしました。"),
        ]

        for testCase in cases {
            #expect(FrameworkLocalization.string(testCase.key, localization: localization) == testCase.expected)
        }
    }

    @Test func semanticKeysResolveFromFrameworkBundleForJapaneseLocale() {
        let localization = Locale.Language(identifier: "ja")

        #expect(
            FrameworkLocalization.string("dictionary.image.link", defaultValue: "Image", localization: localization) == "画像"
        )
        #expect(
            FrameworkLocalization.string(
                "dictionary.frequency.mode.rankAuto",
                defaultValue: "rank-based (auto)",
                localization: localization
            ) == "順位ベース（自動）"
        )
        let summaryTemplate = FrameworkLocalization.string(
                "dictionary.deinflection.summary",
                defaultValue: "Uninflected: %1$@ (Rules: %2$@)",
                localization: localization
            )
        let summary = summaryTemplate
            .replacingOccurrences(of: "%1$@", with: "食べる")
            .replacingOccurrences(of: "%2$@", with: "past, polite")
        #expect(summary == "未変化形: 食べる (規則: past, polite)")
    }
}
