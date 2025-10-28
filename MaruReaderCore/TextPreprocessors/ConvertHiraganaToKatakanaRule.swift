//
//  ConvertHiraganaToKatakanaRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//
// This file is derived from japanese.js, part of the Yomitan project.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

import Foundation

/// Converts hiragana characters to katakana equivalents
/// Based on Yomitan's convertHiraganaToKatakana function
struct ConvertHiraganaToKatakanaRule: TextPreprocessorRule {
    let name = "convertHiraganaToKatakana"
    let description = "Convert hiragana to katakana: ひらがな → ヒラガナ"

    // Unicode ranges for conversion
    private static let hiraganaConversionRange: ClosedRange<UInt32> = 0x3041 ... 0x3096
    private static let katakanaConversionRange: ClosedRange<UInt32> = 0x30A1 ... 0x30F6

    func process(_ text: String) -> String {
        var result = ""
        let offset = Int(Self.katakanaConversionRange.lowerBound) - Int(Self.hiraganaConversionRange.lowerBound)

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var convertedChar = char

            // Convert hiragana in conversion range to katakana
            if Self.hiraganaConversionRange.contains(codePoint) {
                let newCodePoint = UInt32(Int(codePoint) + offset)
                convertedChar = Character(UnicodeScalar(newCodePoint)!)
            }

            result.append(convertedChar)
        }

        return result
    }
}
