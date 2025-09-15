//
//  NormalizeCJKCompatibilityCharactersRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//

import Foundation

/// Normalizes CJK compatibility characters using NFKD normalization
/// Based on Yomitan's normalizeCJKCompatibilityCharacters function
class NormalizeCJKCompatibilityCharactersRule: TextPreprocessorRule {
    let name = "normalizeCJKCompatibilityCharacters"
    let description = "Normalize CJK compatibility characters: ㌀ → アパート, ㍻ → 平成"

    // Unicode range for CJK Compatibility characters
    // Based on CJK_COMPATIBILITY constant from CJK-util.js
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
