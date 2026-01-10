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
internal import IPADic
internal import Mecab_Swift

public enum SentenceFuriganaGenerator {
    /// Generates Anki-style furigana for an entire sentence.
    ///
    /// Uses MeCab with IPADic to tokenize Japanese text and retrieve readings.
    /// Tokens containing kanji are formatted as `kanji[reading]`.
    ///
    /// - Parameter sentence: The Japanese sentence to annotate.
    /// - Returns: The sentence with Anki-style furigana annotations.
    public static func generate(from sentence: String) -> String {
        guard !sentence.isEmpty else { return "" }

        guard let tokenizer = try? Tokenizer(dictionary: IPADic()) else {
            return sentence
        }

        let annotations = tokenizer.tokenize(text: sentence, transliteration: .hiragana)

        var result = ""
        var lastIndex = sentence.startIndex

        for annotation in annotations {
            // Append any text between the last token and this one
            if lastIndex < annotation.range.lowerBound {
                result += String(sentence[lastIndex ..< annotation.range.lowerBound])
            }

            if annotation.containsKanji {
                result += " \(annotation.base)[\(annotation.reading)]"
            } else {
                result += annotation.base
            }

            lastIndex = annotation.range.upperBound
        }

        // Append any remaining text after the last token
        if lastIndex < sentence.endIndex {
            result += String(sentence[lastIndex...])
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Generates Anki-style furigana for a sentence and splits it into cloze segments.
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

        guard let tokenizer = try? Tokenizer(dictionary: IPADic()) else {
            let prefix = String(sentence[..<selectionRange.lowerBound])
            let body = String(sentence[selectionRange])
            let suffix = String(sentence[selectionRange.upperBound...])
            return trimSegments(prefix: prefix, body: body, suffix: suffix)
        }

        let annotations = tokenizer.tokenize(text: sentence, transliteration: .hiragana)

        struct Piece {
            let range: Range<String.Index>
            let text: String
            let splittable: Bool
        }

        var pieces: [Piece] = []
        var lastIndex = sentence.startIndex

        for annotation in annotations {
            if lastIndex < annotation.range.lowerBound {
                let gap = String(sentence[lastIndex ..< annotation.range.lowerBound])
                pieces.append(Piece(range: lastIndex ..< annotation.range.lowerBound, text: gap, splittable: true))
            }

            let text: String = if annotation.containsKanji {
                " \(annotation.base)[\(annotation.reading)]"
            } else {
                annotation.base
            }

            pieces.append(Piece(range: annotation.range, text: text, splittable: !annotation.containsKanji))
            lastIndex = annotation.range.upperBound
        }

        if lastIndex < sentence.endIndex {
            let gap = String(sentence[lastIndex...])
            pieces.append(Piece(range: lastIndex ..< sentence.endIndex, text: gap, splittable: true))
        }

        var prefix = ""
        var body = ""
        var suffix = ""

        for piece in pieces {
            if piece.range.upperBound <= selectionRange.lowerBound {
                prefix += piece.text
                continue
            }

            if piece.range.lowerBound >= selectionRange.upperBound {
                suffix += piece.text
                continue
            }

            if piece.range.lowerBound >= selectionRange.lowerBound,
               piece.range.upperBound <= selectionRange.upperBound
            {
                body += piece.text
                continue
            }

            if piece.splittable {
                if piece.range.lowerBound < selectionRange.lowerBound {
                    prefix += String(sentence[piece.range.lowerBound ..< selectionRange.lowerBound])
                }

                let bodyStart = max(piece.range.lowerBound, selectionRange.lowerBound)
                let bodyEnd = min(piece.range.upperBound, selectionRange.upperBound)
                if bodyStart < bodyEnd {
                    body += String(sentence[bodyStart ..< bodyEnd])
                }

                if selectionRange.upperBound < piece.range.upperBound {
                    suffix += String(sentence[selectionRange.upperBound ..< piece.range.upperBound])
                }
            } else {
                body += piece.text
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

        for index in segments.indices {
            segments[index] = String(segments[index].drop(while: isTrimWhitespace))
            if !segments[index].isEmpty {
                break
            }
        }

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
