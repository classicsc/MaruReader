// NormalizeCJKCompatibilityCharactersRule.swift
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

/// Normalizes CJK compatibility characters using NFKD normalization
/// Based on Yomitan's normalizeCJKCompatibilityCharacters function
struct NormalizeCJKCompatibilityCharactersRule: TextPreprocessorRule {
    let name = "normalizeCJKCompatibilityCharacters"
    let description = "Normalize CJK compatibility characters: ㌀ → アパート, ㍻ → 平成"

    /// Unicode range for CJK Compatibility characters
    /// Based on CJK_COMPATIBILITY constant from CJK-util.js
    private static let cjkCompatibilityRange: ClosedRange<UInt32> = 0x3300 ... 0x33FF

    /// Check if a code point is in the CJK compatibility range
    private func isCJKCompatibilityCharacter(_ codePoint: UInt32) -> Bool {
        Self.cjkCompatibilityRange.contains(codePoint)
    }

    func process(_ text: String) -> String {
        var result = ""

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            if isCJKCompatibilityCharacter(codePoint) {
                // Apply NFKD normalization to CJK compatibility characters
                result += String(char).precomposedStringWithCompatibilityMapping
            } else {
                result.append(char)
            }
        }

        return result
    }
}
