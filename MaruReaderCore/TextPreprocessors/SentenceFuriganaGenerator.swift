// SentenceFuriganaGenerator.swift
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

/// Generates Anki-style furigana strings from Japanese text.
///
/// - Note: This type is deprecated. Use `FuriganaGenerator` instead, which provides
///   both segment generation and Anki formatting in a unified API with proper okurigana handling.
@available(*, deprecated, message: "Use FuriganaGenerator.formatAnkiStyle() instead")
public enum SentenceFuriganaGenerator {
    /// Generates Anki-style furigana for an entire sentence.
    ///
    /// Uses MeCab with IPADic to tokenize Japanese text and retrieve readings.
    /// Tokens containing kanji are formatted as `kanji[reading]`.
    ///
    /// - Parameter sentence: The Japanese sentence to annotate.
    /// - Returns: The sentence with Anki-style furigana annotations.
    @available(*, deprecated, message: "Use FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from:)) instead")
    public static func generate(from sentence: String) -> String {
        FuriganaGenerator.formatAnkiStyle(FuriganaGenerator.generateSegments(from: sentence))
    }

    /// Generates Anki-style furigana for a sentence and splits it into cloze segments.
    @available(*, deprecated, message: "Use FuriganaGenerator.formatCloze() instead")
    public static func generateSegments(
        from sentence: String,
        selectionRange: Range<String.Index>
    ) -> (prefix: String, body: String, suffix: String) {
        guard !sentence.isEmpty else {
            return ("", "", "")
        }

        guard selectionRange.lowerBound >= sentence.startIndex,
              selectionRange.upperBound <= sentence.endIndex
        else {
            return ("", "", "")
        }

        let segments = FuriganaGenerator.generateSegments(from: sentence)
        return FuriganaGenerator.formatCloze(segments, selectionRange: selectionRange, in: sentence)
    }
}
