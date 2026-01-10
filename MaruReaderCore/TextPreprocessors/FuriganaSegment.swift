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
internal import StringTools

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

/// Generates furigana segments for UI display and Anki export.
public enum FuriganaGenerator {
    /// Generates furigana segments from Japanese text for display with ruby annotations.
    ///
    /// Segments containing kanji will have their okurigana (trailing kana) stripped,
    /// producing separate segments for kanji and kana portions. For example,
    /// `食べる` produces two segments: `食[た]` and `べる` (without reading).
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

            // Process the token, splitting at okurigana boundaries if needed
            segments.append(contentsOf: segmentsForAnnotation(annotation, in: text))
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

    /// Splits an annotation into segments, separating kanji from okurigana.
    private static func segmentsForAnnotation(
        _ annotation: Annotation,
        in text: String
    ) -> [FuriganaSegment] {
        // Non-kanji tokens don't need special handling
        guard annotation.containsKanji else {
            return [FuriganaSegment(
                base: annotation.base,
                reading: nil,
                baseRange: annotation.range
            )]
        }

        // Get kanji-only furigana annotation (strips okurigana)
        guard let kanjiAnnotation = annotation.furiganaAnnotation(
            options: [.kanjiOnly],
            for: text
        ) else {
            // No kanji portion found (shouldn't happen given containsKanji check)
            return [FuriganaSegment(
                base: annotation.base,
                reading: annotation.reading,
                baseRange: annotation.range
            )]
        }

        var result: [FuriganaSegment] = []

        // Leading kana (before kanji portion)
        if annotation.range.lowerBound < kanjiAnnotation.range.lowerBound {
            let leadingText = String(text[annotation.range.lowerBound ..< kanjiAnnotation.range.lowerBound])
            result.append(FuriganaSegment(
                base: leadingText,
                reading: nil,
                baseRange: annotation.range.lowerBound ..< kanjiAnnotation.range.lowerBound
            ))
        }

        // Kanji portion with reading
        let kanjiText = String(text[kanjiAnnotation.range])
        result.append(FuriganaSegment(
            base: kanjiText,
            reading: kanjiAnnotation.reading,
            baseRange: kanjiAnnotation.range
        ))

        // Trailing kana (after kanji portion)
        if kanjiAnnotation.range.upperBound < annotation.range.upperBound {
            let trailingText = String(text[kanjiAnnotation.range.upperBound ..< annotation.range.upperBound])
            result.append(FuriganaSegment(
                base: trailingText,
                reading: nil,
                baseRange: kanjiAnnotation.range.upperBound ..< annotation.range.upperBound
            ))
        }

        return result
    }

    // MARK: - Anki Formatting

    /// Formats furigana segments as an Anki-style string with bracket notation.
    ///
    /// Segments with readings are formatted as ` kanji[reading]` (with leading space).
    /// Segments without readings are included as plain text.
    ///
    /// - Parameter segments: The furigana segments to format.
    /// - Returns: A string with Anki-style furigana notation.
    public static func formatAnkiStyle(_ segments: [FuriganaSegment]) -> String {
        var result = ""
        for segment in segments {
            if let reading = segment.reading {
                result += " \(segment.base)[\(reading)]"
            } else {
                result += segment.base
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Formats furigana segments as cloze deletion components.
    ///
    /// Splits the formatted text into prefix, body, and suffix based on a selection range.
    /// Each component is formatted with Anki-style furigana notation.
    ///
    /// - Parameters:
    ///   - segments: The furigana segments to format.
    ///   - selectionRange: The range in the original text that defines the cloze body.
    ///   - text: The original text used to generate the segments.
    /// - Returns: A tuple with prefix, body, and suffix strings.
    public static func formatCloze(
        _ segments: [FuriganaSegment],
        selectionRange: Range<String.Index>,
        in text: String
    ) -> (prefix: String, body: String, suffix: String) {
        var prefix = ""
        var body = ""
        var suffix = ""

        for segment in segments {
            let formatted: String = if let reading = segment.reading {
                " \(segment.base)[\(reading)]"
            } else {
                segment.base
            }

            // Determine which section this segment belongs to
            if segment.baseRange.upperBound <= selectionRange.lowerBound {
                // Entirely before selection
                prefix += formatted
            } else if segment.baseRange.lowerBound >= selectionRange.upperBound {
                // Entirely after selection
                suffix += formatted
            } else if segment.baseRange.lowerBound >= selectionRange.lowerBound,
                      segment.baseRange.upperBound <= selectionRange.upperBound
            {
                // Entirely within selection
                body += formatted
            } else if segment.reading != nil {
                // Partial overlap with kanji - include entirely in body
                // (can't split a kanji+reading segment)
                body += formatted
            } else {
                // Partial overlap with non-kanji - can split
                if segment.baseRange.lowerBound < selectionRange.lowerBound {
                    prefix += String(text[segment.baseRange.lowerBound ..< selectionRange.lowerBound])
                }

                let bodyStart = max(segment.baseRange.lowerBound, selectionRange.lowerBound)
                let bodyEnd = min(segment.baseRange.upperBound, selectionRange.upperBound)
                if bodyStart < bodyEnd {
                    body += String(text[bodyStart ..< bodyEnd])
                }

                if selectionRange.upperBound < segment.baseRange.upperBound {
                    suffix += String(text[selectionRange.upperBound ..< segment.baseRange.upperBound])
                }
            }
        }

        return trimSegments(prefix: prefix, body: body, suffix: suffix)
    }

    private static func trimSegments(
        prefix: String,
        body: String,
        suffix: String
    ) -> (prefix: String, body: String, suffix: String) {
        var segments = [prefix, body, suffix]

        // Trim leading whitespace from first non-empty segment
        for index in segments.indices {
            segments[index] = String(segments[index].drop(while: isTrimWhitespace))
            if !segments[index].isEmpty {
                break
            }
        }

        // Trim trailing whitespace from last non-empty segment
        for index in segments.indices.reversed() {
            segments[index] = String(segments[index].reversed().drop(while: isTrimWhitespace).reversed())
            if !segments[index].isEmpty {
                break
            }
        }

        return (segments[0], segments[1], segments[2])
    }

    private static func isTrimWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }
}
