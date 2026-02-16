// ConvertHiraganaToKatakanaRule.swift
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

// Portions of this file were derived from japanese.js.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

import Foundation

/// Converts hiragana characters to katakana equivalents
/// Based on Yomitan's convertHiraganaToKatakana function
struct ConvertHiraganaToKatakanaRule: TextPreprocessorRule {
    let name = "convertHiraganaToKatakana"
    let description = "Convert hiragana to katakana: ひらがな → ヒラガナ"

    // Unicode ranges for conversion
    private static let hiraganaConversionRange: ClosedRange<UInt32> = 0x3041 ... 0x3096
    private static let katakanaConversionRange: ClosedRange<UInt32> = 0x30A1 ... 0x30F6

    func process(_ text: String) -> String {
        var result = ""
        let offset = Int(Self.katakanaConversionRange.lowerBound) - Int(Self.hiraganaConversionRange.lowerBound)

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var convertedChar = char

            // Convert hiragana in conversion range to katakana
            if Self.hiraganaConversionRange.contains(codePoint) {
                let newCodePoint = UInt32(Int(codePoint) + offset)
                convertedChar = Character(UnicodeScalar(newCodePoint)!)
            }

            result.append(convertedChar)
        }

        return result
    }
}
