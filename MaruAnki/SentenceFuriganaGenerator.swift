//
//  SentenceFuriganaGenerator.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/29/25.
//

internal import IPADic
internal import Mecab_Swift
import Foundation

enum SentenceFuriganaGenerator {
    /// Generates Anki-style furigana for an entire sentence.
    ///
    /// Uses MeCab with IPADic to tokenize Japanese text and retrieve readings.
    /// Tokens containing kanji are formatted as `kanji[reading]`.
    ///
    /// - Parameter sentence: The Japanese sentence to annotate.
    /// - Returns: The sentence with Anki-style furigana annotations.
    static func generate(from sentence: String) -> String {
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
}
