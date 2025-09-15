//
//  ConvertAlphanumericToFullWidthRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//

import Foundation

/// Converts normal-width alphanumeric characters to full-width equivalents
/// Based on Yomitan's convertAlphanumericToFullWidth function
class ConvertAlphanumericToFullWidthRule: TextPreprocessorRule {
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
