// NormalizeCombiningCharactersRule.swift
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

/// Normalizes combining dakuten and handakuten characters
/// Based on Yomitan's normalizeCombiningCharacters function
struct NormalizeCombiningCharactersRule: TextPreprocessorRule {
    let name = "normalizeCombiningCharacters"
    let description = "Normalize combining dakuten/handakuten: が → が, ぱ → ぱ"

    // Unicode code points for combining diacritics
    private static let combiningVoicedSoundMark: UInt32 = 0x3099 // ゙ (dakuten)
    private static let combiningSemiVoicedSoundMark: UInt32 = 0x309A // ゚ (handakuten)

    /// Check if a code point can take dakuten (voiced sound mark)
    /// Based on Yomitan's dakutenAllowed function
    private func dakutenAllowed(_ codePoint: UInt32) -> Bool {
        // か-と (hiragana: ka-to)
        // カ-ト (katakana: ka-to)
        // は-ほ (hiragana: ha-ho)
        // ハ-ホ (katakana: ha-ho)
        (codePoint >= 0x304B && codePoint <= 0x3068) ||
            (codePoint >= 0x306F && codePoint <= 0x307B) ||
            (codePoint >= 0x30AB && codePoint <= 0x30C8) ||
            (codePoint >= 0x30CF && codePoint <= 0x30DB)
    }

    /// Check if a code point can take handakuten (semi-voiced sound mark)
    /// Based on Yomitan's handakutenAllowed function
    private func handakutenAllowed(_ codePoint: UInt32) -> Bool {
        // は-ほ (hiragana: ha-ho)
        // ハ-ホ (katakana: ha-ho)
        (codePoint >= 0x306F && codePoint <= 0x307B) ||
            (codePoint >= 0x30CF && codePoint <= 0x30DB)
    }

    func process(_ text: String) -> String {
        var result = ""
        let scalars = Array(text.unicodeScalars)
        var i = scalars.count - 1

        // Process from right to left (ignoring first character intentionally)
        while i > 0 {
            let currentScalar = scalars[i]
            let previousScalar = scalars[i - 1]

            switch currentScalar.value {
            case Self.combiningVoicedSoundMark:
                // Check if previous character can take dakuten
                if dakutenAllowed(previousScalar.value) {
                    let newCodePoint = previousScalar.value + 1
                    result = String(UnicodeScalar(newCodePoint)!) + result
                    i -= 2 // Skip both characters
                    continue
                }
            case Self.combiningSemiVoicedSoundMark:
                // Check if previous character can take handakuten
                if handakutenAllowed(previousScalar.value) {
                    let newCodePoint = previousScalar.value + 2
                    result = String(UnicodeScalar(newCodePoint)!) + result
                    i -= 2 // Skip both characters
                    continue
                }
            default:
                break
            }

            // Add current character as-is
            result = String(currentScalar) + result
            i -= 1
        }

        // Add first character if we haven't processed it yet (i === 0)
        if i == 0 {
            result = String(scalars[0]) + result
        }

        return result
    }
}
