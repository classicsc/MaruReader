// CollapseEmphaticSequencesRule.swift
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

/// Collapses emphatic character sequences (small tsu, prolonged sound marks)
/// Based on Yomitan's collapseEmphaticSequences function
struct CollapseEmphaticSequencesRule: TextPreprocessorRule {
    let name = "collapseEmphaticSequences"
    let description = "Collapse emphatic sequences: っっっ → っ, ーーー → ー"

    private let fullCollapse: Bool

    // Unicode code points for emphatic characters
    private static let hiraganaSmallTsuCodePoint: UInt32 = 0x3063
    private static let katakanaSmallTsuCodePoint: UInt32 = 0x30C3
    private static let kanaProlongedSoundMarkCodePoint: UInt32 = 0x30FC

    init(fullCollapse: Bool = false) {
        self.fullCollapse = fullCollapse
    }

    /// Check if a code point represents an emphatic character
    private func isEmphaticCodePoint(_ codePoint: UInt32) -> Bool {
        codePoint == Self.hiraganaSmallTsuCodePoint ||
            codePoint == Self.katakanaSmallTsuCodePoint ||
            codePoint == Self.kanaProlongedSoundMarkCodePoint
    }

    func process(_ text: String) -> String {
        let characters = Array(text)
        let textLength = characters.count

        guard textLength > 0 else { return text }

        // Find leading emphatic characters
        var left = 0
        while left < textLength {
            guard let codePoint = characters[left].unicodeScalars.first?.value,
                  isEmphaticCodePoint(codePoint)
            else {
                break
            }
            left += 1
        }

        // Find trailing emphatic characters
        var right = textLength - 1
        while right >= 0 {
            guard let codePoint = characters[right].unicodeScalars.first?.value,
                  isEmphaticCodePoint(codePoint)
            else {
                break
            }
            right -= 1
        }

        // If whole string is emphatic, return as-is
        if left > right {
            return text
        }

        let leadingEmphatics = String(characters[0 ..< left])
        let trailingEmphatics = String(characters[(right + 1) ..< textLength])
        var middle = ""
        var currentCollapsedCodePoint: UInt32 = 0

        // Process middle section
        for i in left ... right {
            let char = characters[i]
            guard let codePoint = char.unicodeScalars.first?.value else {
                currentCollapsedCodePoint = 0
                middle.append(char)
                continue
            }

            if isEmphaticCodePoint(codePoint) {
                if currentCollapsedCodePoint != codePoint {
                    currentCollapsedCodePoint = codePoint
                    if !fullCollapse {
                        middle.append(char)
                        continue
                    }
                }
                // Skip repeated emphatic characters (either in fullCollapse mode or same type)
            } else {
                currentCollapsedCodePoint = 0
                middle.append(char)
            }
        }

        return leadingEmphatics + middle + trailingEmphatics
    }
}
