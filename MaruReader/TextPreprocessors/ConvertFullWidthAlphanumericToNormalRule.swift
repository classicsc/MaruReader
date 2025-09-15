//
//  ConvertFullWidthAlphanumericToNormalRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//

import Foundation

/// Converts full-width alphanumeric characters to normal-width equivalents
/// Based on Yomitan's convertFullWidthAlphanumericToNormal function
class ConvertFullWidthAlphanumericToNormalRule: TextPreprocessorRule {
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
