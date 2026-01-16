// FuriganaGeneratorTests.swift
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

struct FuriganaGeneratorTests {
    // MARK: - Basic Functionality

    @Test func emptyString_returnsEmpty() {
        let result = FuriganaGenerator.generateSegments(from: "")
        #expect(result.isEmpty)
    }

    @Test func emptyString_formatReturnsEmpty() {
        let result = FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from: ""))
        #expect(result.isEmpty)
    }

    @Test func hiraganaOnly_noReading() {
        let segments = FuriganaGenerator.generateSegments(from: "これはひらがなです")
        // All segments should have nil reading since there's no kanji
        #expect(segments.allSatisfy { $0.reading == nil })
    }

    @Test func hiraganaOnly_formatHasNoBrackets() {
        let segments = FuriganaGenerator.generateSegments(from: "これはひらがなです")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        #expect(!result.contains("["))
        #expect(!result.contains("]"))
    }

    @Test func katakanaOnly_noReading() {
        let segments = FuriganaGenerator.generateSegments(from: "コレハカタカナデス")
        #expect(segments.allSatisfy { $0.reading == nil })
    }

    @Test func katakanaOnly_formatHasNoBrackets() {
        let segments = FuriganaGenerator.generateSegments(from: "コレハカタカナデス")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        #expect(!result.contains("["))
        #expect(!result.contains("]"))
    }

    // MARK: - Okurigana Stripping (Core Feature)

    @Test func okurigana_食べる_stripsTrailingKana() {
        let segments = FuriganaGenerator.generateSegments(from: "食べる")
        // Should have two segments: 食[た] and べる (no reading)
        let kanjiSegments = segments.filter { $0.reading != nil }
        let kanaSegments = segments.filter { $0.reading == nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "食")
        #expect(kanjiSegments.first?.reading == "た")

        // The okurigana べる should be in a separate segment without reading
        let okuriganaSegment = kanaSegments.first { $0.base.contains("べ") }
        #expect(okuriganaSegment != nil)
        #expect(okuriganaSegment?.reading == nil)
    }

    @Test func okurigana_行く_stripsTrailingKana() {
        let segments = FuriganaGenerator.generateSegments(from: "行く")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "行")
        #expect(kanjiSegments.first?.reading == "い")
    }

    @Test func okurigana_高い_stripsTrailingKana() {
        let segments = FuriganaGenerator.generateSegments(from: "高い")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "高")
        #expect(kanjiSegments.first?.reading == "たか")
    }

    @Test func okurigana_飲む_stripsTrailingKana() {
        let segments = FuriganaGenerator.generateSegments(from: "飲む")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "飲")
        #expect(kanjiSegments.first?.reading == "の")
    }

    @Test func okurigana_書く_stripsTrailingKana() {
        let segments = FuriganaGenerator.generateSegments(from: "書く")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "書")
        #expect(kanjiSegments.first?.reading == "か")
    }

    // MARK: - All-Kanji Words (No Okurigana)

    @Test func noOkurigana_日本語_fullReading() {
        let segments = FuriganaGenerator.generateSegments(from: "日本語")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "日本語")
        #expect(kanjiSegments.first?.reading == "にほんご")
    }

    @Test func noOkurigana_学校_fullReading() {
        let segments = FuriganaGenerator.generateSegments(from: "学校")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "学校")
        #expect(kanjiSegments.first?.reading == "がっこう")
    }

    @Test func noOkurigana_東京_fullReading() {
        let segments = FuriganaGenerator.generateSegments(from: "東京")
        let kanjiSegments = segments.filter { $0.reading != nil }

        #expect(kanjiSegments.count == 1)
        #expect(kanjiSegments.first?.base == "東京")
        #expect(kanjiSegments.first?.reading == "とうきょう")
    }

    // MARK: - Range Correctness

    @Test func segmentRanges_coverEntireText() {
        let text = "食べる"
        let segments = FuriganaGenerator.generateSegments(from: text)

        // Verify ranges are contiguous and cover the entire text
        var expectedStart = text.startIndex
        for segment in segments {
            #expect(segment.baseRange.lowerBound == expectedStart)
            expectedStart = segment.baseRange.upperBound
        }
        #expect(expectedStart == text.endIndex)
    }

    @Test func segmentRanges_matchOriginalText() {
        let text = "私は学生です"
        let segments = FuriganaGenerator.generateSegments(from: text)

        // Each segment's base should match the text at its range
        for segment in segments {
            let textAtRange = String(text[segment.baseRange])
            #expect(segment.base == textAtRange, "Segment base '\(segment.base)' should match text at range '\(textAtRange)'")
        }
    }

    // MARK: - Anki Format Output

    @Test func ankiFormat_okuriganaStripped() {
        let segments = FuriganaGenerator.generateSegments(from: "食べる")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        // Should be "食[た]べる" not "食べる[たべる]"
        #expect(result == "食[た]べる")
    }

    @Test func ankiFormat_simpleKanji_addsReading() {
        let segments = FuriganaGenerator.generateSegments(from: "日本語")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(result.contains("日本語["))
        #expect(result.contains("]"))
    }

    @Test func ankiFormat_multipleWords() {
        let segments = FuriganaGenerator.generateSegments(from: "私は日本語を勉強する")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        // Each kanji word should have proper furigana
        #expect(result.contains("私[わたし]") || result.contains("私[わたくし]"))
        #expect(result.contains("日本語[にほんご]"))
        #expect(result.contains("勉強[べんきょう]"))

        // Okurigana should be stripped from する
        #expect(!result.contains("する[する]"))
    }

    @Test func ankiFormat_pureKanji_hasReading() {
        let segments = FuriganaGenerator.generateSegments(from: "東京と大阪")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(result.contains("東京[とうきょう]"))
        #expect(result.contains("大阪[おおさか]"))
    }

    @Test func ankiFormat_noKanji_noReadings() {
        let segments = FuriganaGenerator.generateSegments(from: "これはテストです")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        // Should have no brackets since no kanji
        #expect(!result.contains("["))
        #expect(!result.contains("]"))
    }

    @Test func ankiFormat_bracketStyle() {
        let segments = FuriganaGenerator.generateSegments(from: "漢字")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        let pattern = #"漢字\[.+\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(result.startIndex ..< result.endIndex, in: result)
        let match = regex?.firstMatch(in: result, range: range)
        #expect(match != nil)
    }

    // MARK: - Cloze Format

    @Test func clozeFormat_selectionInMiddle() {
        let text = "私は学校へ行く"
        let segments = FuriganaGenerator.generateSegments(from: text)

        // Select 学校
        let selectionStart = text.index(text.startIndex, offsetBy: 2) // after 私は
        let selectionEnd = text.index(selectionStart, offsetBy: 2) // 学校
        let selectionRange = selectionStart ..< selectionEnd

        let cloze = FuriganaGenerator.formatCloze(segments, selectionRange: selectionRange, in: text)

        #expect(!cloze.prefix.isEmpty)
        #expect(!cloze.body.isEmpty)
        #expect(!cloze.suffix.isEmpty)

        // Body should contain the selected kanji with reading
        #expect(cloze.body.contains("学校"))
    }

    // MARK: - Edge Cases

    @Test func latinText_passesThrough() {
        let segments = FuriganaGenerator.generateSegments(from: "Hello World")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        #expect(result == "Hello World")
    }

    @Test func numbersOnly_passesThrough() {
        let segments = FuriganaGenerator.generateSegments(from: "12345")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        #expect(result == "12345")
    }

    @Test func mixedLatinAndJapanese_handlesCorrectly() {
        let segments = FuriganaGenerator.generateSegments(from: "ABCは日本語です")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(result.contains("ABC"))
        #expect(result.contains("日本語[にほんご]"))
    }

    @Test func punctuation_preserved() {
        let segments = FuriganaGenerator.generateSegments(from: "今日は、天気がいい。")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(result.contains("、"))
        #expect(result.contains("。"))
    }

    @Test func spaces_preserved() {
        let segments = FuriganaGenerator.generateSegments(from: "日本 語")
        let result = FuriganaGenerator.formatAnkiStyle(segments)
        let hasSpace = result.contains(" 語") || result.contains("] 語")
        #expect(hasSpace || result.contains("日本") && result.contains("語"))
    }

    // MARK: - Complex Sentences

    @Test func fullSentence_私は日本語を勉強しています() {
        let segments = FuriganaGenerator.generateSegments(from: "私は日本語を勉強しています")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        // Should have readings for kanji words
        #expect(result.contains("私["))
        #expect(result.contains("日本語[にほんご]"))
        #expect(result.contains("勉強[べんきょう]"))
    }

    @Test func fullSentence_今日はいい天気ですね() {
        let segments = FuriganaGenerator.generateSegments(from: "今日はいい天気ですね")
        let result = FuriganaGenerator.formatAnkiStyle(segments)

        #expect(result.contains("今日[きょう]"))
        #expect(result.contains("天気[てんき]"))
    }
}
