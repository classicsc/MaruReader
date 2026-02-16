// ConvertAlphanumericToFullWidthRule.swift
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

/// Converts normal-width alphanumeric characters to full-width equivalents
/// Based on Yomitan's convertAlphanumericToFullWidth function
struct ConvertAlphanumericToFullWidthRule: TextPreprocessorRule {
    let name = "convertAlphanumericToFullWidth"
    let description = "Convert normal alphanumeric to full width: abc123 → ａｂｃ１２３"

    func process(_ text: String) -> String {
        var result = ""

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var convertedCodePoint = codePoint

            switch codePoint {
            case 0x30 ... 0x39: // ['0', '9'] - ASCII digits
                convertedCodePoint = codePoint + (0xFF10 - 0x30) // Convert to full-width digits
            case 0x41 ... 0x5A: // ['A', 'Z'] - ASCII uppercase letters
                convertedCodePoint = codePoint + (0xFF21 - 0x41) // Convert to full-width uppercase
            case 0x61 ... 0x7A: // ['a', 'z'] - ASCII lowercase letters
                convertedCodePoint = codePoint + (0xFF41 - 0x61) // Convert to full-width lowercase
            default:
                // No conversion needed for other characters
                break
            }

            result.append(Character(UnicodeScalar(convertedCodePoint)!))
        }

        return result
    }
}
