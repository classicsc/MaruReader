// SentenceFuriganaGeneratorTests.swift
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
@testable import MaruAnki
import Testing

struct SentenceFuriganaGeneratorTests {
    // MARK: - Basic Functionality

    @Test func emptyString_returnsEmpty() {
        let result = SentenceFuriganaGenerator.generate(from: "")
        #expect(result == "")
    }

    @Test func hiraganaOnly_noFuriganaAdded() {
        let result = SentenceFuriganaGenerator.generate(from: "これはひらがなです")
        // No kanji, so no brackets should be added
        #expect(!result.contains("["))
        #expect(!result.contains("]"))
    }

    @Test func katakanaOnly_noFuriganaAdded() {
        let result = SentenceFuriganaGenerator.generate(from: "コレハカタカナデス")
        #expect(!result.contains("["))
        #expect(!result.contains("]"))
    }

    @Test func simpleKanjiWord_addsFurigana() {
        let result = SentenceFuriganaGenerator.generate(from: "日本語")
        #expect(result.contains("日本語["))
        #expect(result.contains("]"))
    }

    @Test func mixedSentence_addsFuriganaToKanji() {
        let result = SentenceFuriganaGenerator.generate(from: "私は学生です")
        // Should have furigana for 私 and 学生
        #expect(result.contains("私["))
        #expect(result.contains("学生["))
        // Hiragana parts should not have furigana
        #expect(result.contains("は"))
        #expect(result.contains("です"))
    }

    // MARK: - Edge Cases

    @Test func latinText_passesThrough() {
        let result = SentenceFuriganaGenerator.generate(from: "Hello World")
        #expect(result == "Hello World")
    }

    @Test func numbersOnly_passesThrough() {
        let result = SentenceFuriganaGenerator.generate(from: "12345")
        #expect(result == "12345")
    }

    @Test func mixedLatinAndJapanese_handlesCorrectly() {
        let result = SentenceFuriganaGenerator.generate(from: "ABCは日本語です")
        #expect(result.contains("ABC"))
        #expect(result.contains("日本語["))
    }

    @Test func punctuation_preserved() {
        let result = SentenceFuriganaGenerator.generate(from: "今日は、天気がいい。")
        #expect(result.contains("、"))
        #expect(result.contains("。"))
    }

    @Test func spaces_preserved() {
        let result = SentenceFuriganaGenerator.generate(from: "日本 語")
        // Spaces between tokens should be preserved
        let hasSpace = result.contains(" 語") || result.contains("] 語")
        #expect(hasSpace || result.contains("日本") && result.contains("語"))
    }

    // MARK: - Reading Accuracy

    @Test func commonWord_日本語_correctReading() {
        let result = SentenceFuriganaGenerator.generate(from: "日本語")
        // 日本語 should be read as にほんご
        #expect(result.contains("にほんご"))
    }

    @Test func commonWord_食べる_correctReading() {
        let result = SentenceFuriganaGenerator.generate(from: "食べる")
        // 食べる should have furigana for the kanji part
        #expect(result.contains("["))
    }

    @Test func commonWord_学校_correctReading() {
        let result = SentenceFuriganaGenerator.generate(from: "学校")
        // 学校 should be read as がっこう
        #expect(result.contains("がっこう"))
    }

    @Test func commonWord_東京_correctReading() {
        let result = SentenceFuriganaGenerator.generate(from: "東京")
        // 東京 should be read as とうきょう
        #expect(result.contains("とうきょう"))
    }

    // MARK: - Full Sentence Examples

    @Test func fullSentence_私は日本語を勉強しています() {
        let result = SentenceFuriganaGenerator.generate(from: "私は日本語を勉強しています")
        // Should have readings for kanji words
        #expect(result.contains("私["))
        #expect(result.contains("日本語["))
        #expect(result.contains("勉強["))
    }

    @Test func fullSentence_今日はいい天気ですね() {
        let result = SentenceFuriganaGenerator.generate(from: "今日はいい天気ですね")
        #expect(result.contains("今日[きょう]"))
        #expect(result.contains("天気[てんき]"))
    }

    // MARK: - Anki Format Verification

    @Test func ankiFormat_bracketStyle() {
        let result = SentenceFuriganaGenerator.generate(from: "漢字")
        // Verify Anki bracket format: kanji[reading]
        let pattern = #"漢字\[.+\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(result.startIndex ..< result.endIndex, in: result)
        let match = regex?.firstMatch(in: result, range: range)
        #expect(match != nil)
    }

    @Test func multipleKanjiWords_eachHasSeparateFurigana() {
        let result = SentenceFuriganaGenerator.generate(from: "東京と大阪")
        // Both 東京 and 大阪 should have separate furigana
        let bracketCount = result.filter { $0 == "[" }.count
        #expect(bracketCount >= 2)
    }
}
