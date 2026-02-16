// ConvertAlphabeticToKanaRule.swift
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

/// Converts alphabetic characters to kana equivalents
/// Based on Yomitan's convertAlphabeticToKana function
struct ConvertAlphabeticToKanaRule: TextPreprocessorRule {
    let name = "convertAlphabeticToKana"
    let description = "Convert alphabetic text to kana: chikara → ちから"

    /// Romaji to Hiragana mapping dictionary (subset of full mapping for performance)
    private static let romajiToHiragana: [String: String] = [
        // Double letters - these create sokuon (っ) + base consonant sound
        "kk": "っ", "gg": "っ", "ss": "っ", "zz": "っ", "jj": "っ", "tt": "っ",
        "dd": "っ", "hh": "っ", "ff": "っ", "bb": "っ", "pp": "っ",
        "mm": "っ", "yy": "っ", "rr": "っ", "ww": "っ", "cc": "っ",

        // Length 4 - longest matches
        "hwyu": "ふゅ", "xtsu": "っ", "ltsu": "っ",

        // Length 3
        "vya": "ゔゃ", "vyi": "ゔぃ", "vyu": "ゔゅ", "vye": "ゔぇ", "vyo": "ゔょ",
        "kya": "きゃ", "kyi": "きぃ", "kyu": "きゅ", "kye": "きぇ", "kyo": "きょ",
        "gya": "ぎゃ", "gyi": "ぎぃ", "gyu": "ぎゅ", "gye": "ぎぇ", "gyo": "ぎょ",
        "sya": "しゃ", "syi": "しぃ", "syu": "しゅ", "sye": "しぇ", "syo": "しょ",
        "sha": "しゃ", "shi": "し", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
        "zya": "じゃ", "zyi": "じぃ", "zyu": "じゅ", "zye": "じぇ", "zyo": "じょ",
        "tya": "ちゃ", "tyi": "ちぃ", "tyu": "ちゅ", "tye": "ちぇ", "tyo": "ちょ",
        "cha": "ちゃ", "chi": "ち", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
        "cya": "ちゃ", "cyi": "ちぃ", "cyu": "ちゅ", "cye": "ちぇ", "cyo": "ちょ",
        "dya": "ぢゃ", "dyi": "ぢぃ", "dyu": "ぢゅ", "dye": "ぢぇ", "dyo": "ぢょ",
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "tha": "てゃ", "thi": "てぃ", "thu": "てゅ", "the": "てぇ", "tho": "てょ",
        "dha": "でゃ", "dhi": "でぃ", "dhu": "でゅ", "dhe": "でぇ", "dho": "でょ",
        "twa": "とぁ", "twi": "とぃ", "twu": "とぅ", "twe": "とぇ", "two": "とぉ",
        "dwa": "どぁ", "dwi": "どぃ", "dwu": "どぅ", "dwe": "どぇ", "dwo": "どぉ",
        "nya": "にゃ", "nyi": "にぃ", "nyu": "にゅ", "nye": "にぇ", "nyo": "にょ",
        "hya": "ひゃ", "hyi": "ひぃ", "hyu": "ひゅ", "hye": "ひぇ", "hyo": "ひょ",
        "bya": "びゃ", "byi": "びぃ", "byu": "びゅ", "bye": "びぇ", "byo": "びょ",
        "pya": "ぴゃ", "pyi": "ぴぃ", "pyu": "ぴゅ", "pye": "ぴぇ", "pyo": "ぴょ",
        "fya": "ふゃ", "fyu": "ふゅ", "fyo": "ふょ",
        "hwa": "ふぁ", "hwi": "ふぃ", "hwe": "ふぇ", "hwo": "ふぉ",
        "mya": "みゃ", "myi": "みぃ", "myu": "みゅ", "mye": "みぇ", "myo": "みょ",
        "rya": "りゃ", "ryi": "りぃ", "ryu": "りゅ", "rye": "りぇ", "ryo": "りょ",
        "lyi": "ぃ", "xyi": "ぃ", "lye": "ぇ", "xye": "ぇ",
        "xka": "ヵ", "xke": "ヶ", "lka": "ヵ", "lke": "ヶ",
        "kwa": "くぁ", "kwi": "くぃ", "kwu": "くぅ", "kwe": "くぇ", "kwo": "くぉ",
        "gwa": "ぐぁ", "gwi": "ぐぃ", "gwu": "ぐぅ", "gwe": "ぐぇ", "gwo": "ぐぉ",
        "swa": "すぁ", "swi": "すぃ", "swu": "すぅ", "swe": "すぇ", "swo": "すぉ",
        "zwa": "ずぁ", "zwi": "ずぃ", "zwu": "ずぅ", "zwe": "ずぇ", "zwo": "ずぉ",
        "jya": "じゃ", "jyi": "じぃ", "jyu": "じゅ", "jye": "じぇ", "jyo": "じょ",
        "tsu": "つ", "xtu": "っ", "ltu": "っ",
        "xya": "ゃ", "lya": "ゃ", "wyi": "ゐ",
        "xyu": "ゅ", "lyu": "ゅ", "wye": "ゑ",
        "xyo": "ょ", "lyo": "ょ",
        "xwa": "ゎ", "lwa": "ゎ",
        "wha": "うぁ", "whi": "うぃ", "whu": "う", "whe": "うぇ", "who": "うぉ",

        // Length 2
        "nn": "ん", "n'": "ん",
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        "xn": "ん", "wu": "う",
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ",
        "ye": "いぇ",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "sa": "さ", "si": "し", "su": "す", "se": "せ", "so": "そ",
        "ca": "か", "ci": "し", "cu": "く", "ce": "せ", "co": "こ",
        "qa": "くぁ", "qi": "くぃ", "qu": "く", "qe": "くぇ", "qo": "くぉ",
        "za": "ざ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ja": "じゃ", "ji": "じ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
        "ta": "た", "ti": "ち", "tu": "つ", "te": "て", "to": "と",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "ya": "や", "yu": "ゆ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",

        // Length 1 - shortest matches
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",

        // Special case - single 'n' -> 'ん'
        "n": "ん",
    ]

    /// Convert hiragana to katakana (reusing existing logic)
    private let hiraganaToKatakanaConverter = ConvertHiraganaToKatakanaRule()

    /// Converts romaji text to hiragana
    private func convertToHiragana(_ text: String) -> String {
        var result = ""
        let lowercaseText = text.lowercased()
        var i = 0

        while i < lowercaseText.count {
            let remainingText = String(lowercaseText.dropFirst(i))
            var matched = false

            // Check for double consonants first (special handling)
            // But exclude "nn" which has its own mapping
            if i + 1 < lowercaseText.count {
                let currentChar = lowercaseText[lowercaseText.index(lowercaseText.startIndex, offsetBy: i)]
                let nextChar = lowercaseText[lowercaseText.index(lowercaseText.startIndex, offsetBy: i + 1)]

                if currentChar == nextChar, currentChar != "n", "bcdfghjklmnpqrstvwxyz".contains(currentChar) {
                    // This is a double consonant (but not nn), produce sokuon and continue with single consonant
                    result += "っ"
                    i += 1 // Skip the first consonant, let the next iteration handle the second
                    matched = true
                }
            }

            if !matched {
                // Try to match longest sequences first (4 characters down to 1)
                for length in (1 ... min(4, remainingText.count)).reversed() {
                    let substring = String(remainingText.prefix(length))

                    if let hiragana = Self.romajiToHiragana[substring] {
                        result += hiragana
                        i += length
                        matched = true
                        break
                    }
                }
            }

            // If no match found, keep the original character
            if !matched {
                let char = lowercaseText[lowercaseText.index(lowercaseText.startIndex, offsetBy: i)]
                result.append(char)
                i += 1
            }
        }

        return result
    }

    /// Fills gaps in sokuons that single-pass replacement might miss
    private func fillSokuonGaps(_ text: String) -> String {
        var result = text
        // Fill hiragana sokuon gaps
        result = result.replacingOccurrences(
            of: "っ[a-z](?=っ)",
            with: "っっ",
            options: .regularExpression
        )
        // Fill katakana sokuon gaps
        result = result.replacingOccurrences(
            of: "ッ[A-Z](?=ッ)",
            with: "ッッ",
            options: .regularExpression
        )
        return result
    }

    func process(_ text: String) -> String {
        var part = ""
        var result = ""

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var normalizedCodePoint: UInt32

            switch codePoint {
            case 0x41 ... 0x5A: // ['A', 'Z'] - uppercase ASCII
                normalizedCodePoint = codePoint - 0x41 + 0x61 // Convert to lowercase
            case 0x61 ... 0x7A: // ['a', 'z'] - lowercase ASCII
                normalizedCodePoint = codePoint // Already lowercase
            case 0xFF21 ... 0xFF3A: // ['A', 'Z'] - fullwidth uppercase
                normalizedCodePoint = codePoint - 0xFF21 + 0x61 // Convert to lowercase ASCII
            case 0xFF41 ... 0xFF5A: // ['a', 'z'] - fullwidth lowercase
                normalizedCodePoint = codePoint - 0xFF41 + 0x61 // Convert to lowercase ASCII
            case 0x2D, 0xFF0D: // '-' or fullwidth dash
                normalizedCodePoint = 0x2D // Standard dash
            default:
                // Not an alphabetic character or dash - process any accumulated part
                if !part.isEmpty {
                    let convertedPart = convertToHiragana(part)
                    result += convertedPart
                    part = ""
                }
                result.append(char)
                continue
            }

            // Add normalized character to the current alphabetic part
            if let normalizedChar = UnicodeScalar(normalizedCodePoint) {
                part.append(Character(normalizedChar))
            }
        }

        // Process any remaining alphabetic part
        if !part.isEmpty {
            let convertedPart = convertToHiragana(part)
            result += convertedPart
        }

        return result
    }
}
