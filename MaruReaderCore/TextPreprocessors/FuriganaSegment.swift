// FuriganaSegment.swift
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
internal import IPADic
internal import Mecab_Swift

/// A segment of text with optional furigana reading for UI display.
public struct FuriganaSegment: Sendable {
    /// The displayed text (kanji, kana, or other characters).
    public let base: String

    /// Furigana reading in hiragana. Nil if base is already kana or non-Japanese.
    public let reading: String?

    /// The range of this segment in the original string.
    public let baseRange: Range<String.Index>

    public init(base: String, reading: String?, baseRange: Range<String.Index>) {
        self.base = base
        self.reading = reading
        self.baseRange = baseRange
    }
}

/// Generates furigana segments for UI display.
public enum FuriganaGenerator {
    /// Generates furigana segments from Japanese text for display with ruby annotations.
    ///
    /// - Parameter text: The Japanese text to process.
    /// - Returns: An array of segments, each with base text and optional reading.
    public static func generateSegments(from text: String) -> [FuriganaSegment] {
        guard !text.isEmpty else { return [] }

        guard let tokenizer = try? Tokenizer(dictionary: IPADic()) else {
            // Fallback: return the entire text as a single segment without reading
            return [FuriganaSegment(base: text, reading: nil, baseRange: text.startIndex ..< text.endIndex)]
        }

        let annotations = tokenizer.tokenize(text: text, transliteration: .hiragana)
        var segments: [FuriganaSegment] = []
        var lastIndex = text.startIndex

        for annotation in annotations {
            // Handle any gap between tokens (whitespace, punctuation, etc.)
            if lastIndex < annotation.range.lowerBound {
                let gapText = String(text[lastIndex ..< annotation.range.lowerBound])
                segments.append(FuriganaSegment(
                    base: gapText,
                    reading: nil,
                    baseRange: lastIndex ..< annotation.range.lowerBound
                ))
            }

            // Add the token segment
            let reading: String? = annotation.containsKanji ? annotation.reading : nil
            segments.append(FuriganaSegment(
                base: annotation.base,
                reading: reading,
                baseRange: annotation.range
            ))

            lastIndex = annotation.range.upperBound
        }

        // Handle any remaining text after the last token
        if lastIndex < text.endIndex {
            let remainingText = String(text[lastIndex...])
            segments.append(FuriganaSegment(
                base: remainingText,
                reading: nil,
                baseRange: lastIndex ..< text.endIndex
            ))
        }

        return segments
    }
}
