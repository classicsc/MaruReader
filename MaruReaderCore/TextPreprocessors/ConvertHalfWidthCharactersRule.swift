// ConvertHalfWidthCharactersRule.swift
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

// Portions of this file were derived from japanese.js.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

import Foundation

/// Converts half-width katakana characters to full-width equivalents
/// Based on Yomitan's convertHalfWidthKanaToFullWidth function
struct ConvertHalfWidthCharactersRule: TextPreprocessorRule {
    let name = "convertHalfWidthCharacters"
    let description = "Convert half width characters to full width: ﾖﾐﾁｬﾝ → ヨミチャン"

    // Half-width to full-width katakana mapping
    // Format: "base dakuten handakuten" where '-' means invalid/unused
    private static let halfWidthKatakanaMapping: [Character: String] = [
        "･": "・--",
        "ｦ": "ヲヺ-",
        "ｧ": "ァ--",
        "ｨ": "ィ--",
        "ｩ": "ゥ--",
        "ｪ": "ェ--",
        "ｫ": "ォ--",
        "ｬ": "ャ--",
        "ｭ": "ュ--",
        "ｮ": "ョ--",
        "ｯ": "ッ--",
        "ｰ": "ー--",
        "ｱ": "ア--",
        "ｲ": "イ--",
        "ｳ": "ウヴ-",
        "ｴ": "エ--",
        "ｵ": "オ--",
        "ｶ": "カガ-",
        "ｷ": "キギ-",
        "ｸ": "クグ-",
        "ｹ": "ケゲ-",
        "ｺ": "コゴ-",
        "ｻ": "サザ-",
        "ｼ": "シジ-",
        "ｽ": "スズ-",
        "ｾ": "セゼ-",
        "ｿ": "ソゾ-",
        "ﾀ": "タダ-",
        "ﾁ": "チヂ-",
        "ﾂ": "ツヅ-",
        "ﾃ": "テデ-",
        "ﾄ": "トド-",
        "ﾅ": "ナ--",
        "ﾆ": "ニ--",
        "ﾇ": "ヌ--",
        "ﾈ": "ネ--",
        "ﾉ": "ノ--",
        "ﾊ": "ハバパ",
        "ﾋ": "ヒビピ",
        "ﾌ": "フブプ",
        "ﾍ": "ヘベペ",
        "ﾎ": "ホボポ",
        "ﾏ": "マ--",
        "ﾐ": "ミ--",
        "ﾑ": "ム--",
        "ﾒ": "メ--",
        "ﾓ": "モ--",
        "ﾔ": "ヤ--",
        "ﾕ": "ユ--",
        "ﾖ": "ヨ--",
        "ﾗ": "ラ--",
        "ﾘ": "リ--",
        "ﾙ": "ル--",
        "ﾚ": "レ--",
        "ﾛ": "ロ--",
        "ﾜ": "ワ--",
        "ﾝ": "ン--",
    ]

    // Dakuten and handakuten Unicode code points
    private static let dakutenCodePoint: UInt16 = 0xFF9E
    private static let handakutenCodePoint: UInt16 = 0xFF9F

    func process(_ text: String) -> String {
        var result = ""
        let scalars = Array(text.unicodeScalars)
        var i = 0

        while i < scalars.count {
            let currentScalar = scalars[i]
            let currentChar = Character(currentScalar)

            // Check if current character has a mapping
            guard let mapping = Self.halfWidthKatakanaMapping[currentChar] else {
                result.append(currentChar)
                i += 1
                continue
            }

            var mappingIndex = 0 // Default to base form (index 0)

            // Check for dakuten or handakuten on next scalar
            if i + 1 < scalars.count {
                let nextScalar = scalars[i + 1]

                switch UInt16(nextScalar.value) {
                case Self.dakutenCodePoint:
                    mappingIndex = 1 // Dakuten form
                case Self.handakutenCodePoint:
                    mappingIndex = 2 // Handakuten form
                default:
                    break
                }
            }

            // Get the converted character from the mapping string
            let charIndex = mapping.index(mapping.startIndex, offsetBy: mappingIndex)
            var convertedChar = mapping[charIndex]

            // Handle invalid combinations (marked with '-')
            let consumedDiacritic = mappingIndex > 0
            if mappingIndex > 0, convertedChar == "-" {
                // Fall back to base form but still consume the diacritic
                convertedChar = mapping[mapping.startIndex]
            }

            result.append(convertedChar)

            // Skip the diacritic if we found one (even if invalid)
            if consumedDiacritic {
                i += 2 // Skip both the base character and the diacritic
            } else {
                i += 1 // Skip only the base character
            }
        }

        return result
    }
}
