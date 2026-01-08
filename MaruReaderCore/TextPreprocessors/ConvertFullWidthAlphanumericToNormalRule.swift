// ConvertFullWidthAlphanumericToNormalRule.swift
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

/// Converts full-width alphanumeric characters to normal-width equivalents
/// Based on Yomitan's convertFullWidthAlphanumericToNormal function
struct ConvertFullWidthAlphanumericToNormalRule: TextPreprocessorRule {
    let name = "convertFullWidthAlphanumericToNormal"
    let description = "Convert full width alphanumeric to normal: ａｂｃ１２３ → abc123"

    func process(_ text: String) -> String {
        var result = ""

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var convertedCodePoint = codePoint

            switch codePoint {
            case 0xFF10 ... 0xFF19: // ['０', '９'] - Full-width digits
                convertedCodePoint = codePoint - (0xFF10 - 0x30) // Convert to ASCII digits
            case 0xFF21 ... 0xFF3A: // ['Ａ', 'Ｚ'] - Full-width uppercase letters
                convertedCodePoint = codePoint - (0xFF21 - 0x41) // Convert to ASCII uppercase
            case 0xFF41 ... 0xFF5A: // ['ａ', 'ｚ'] - Full-width lowercase letters
                convertedCodePoint = codePoint - (0xFF41 - 0x61) // Convert to ASCII lowercase
            default:
                // No conversion needed for other characters
                break
            }

            result.append(Character(UnicodeScalar(convertedCodePoint)!))
        }

        return result
    }
}
