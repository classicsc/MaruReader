// ConvertKanjiVariantsRule.swift
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

/// Normalizes kanji variant forms to their standard forms
/// Based on Yomitan's convertVariants function using itaiji data
struct ConvertKanjiVariantsRule: TextPreprocessorRule {
    let name = "convertKanjiVariants"
    let description = "Convert kanji variants to standard forms: 弌 → 一, 萬 → 万"

    private let conversionMap: [String: String]
    private let variantPattern: NSRegularExpression

    /// Initialize with kanji mapping data from JSON files
    init() {
        var tempConversionMap: [String: String] = [:]
        var variantCharacters: Set<String> = []

        // Load full_list.json for mappings
        if let url = Bundle.framework.url(forResource: "full_list", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let mappings = try? JSONDecoder().decode([KanjiMapping].self, from: data)
        {
            for mapping in mappings {
                for itaiji in mapping.itaiji {
                    tempConversionMap[itaiji] = mapping.oyaji
                    variantCharacters.insert(itaiji)
                }
            }
        }

        // Load itaiji_list.json for regex pattern (validation)
        if let url = Bundle.framework.url(forResource: "itaiji_list", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let itaijiList = try? JSONDecoder().decode([String].self, from: data)
        {
            // Verify our mapping includes all variants from the list
            for variant in itaijiList {
                variantCharacters.insert(variant)
            }
        }

        conversionMap = tempConversionMap

        // Create regex pattern for all variant characters
        let escapedVariants = variantCharacters.compactMap { variant in
            // Escape special regex characters if any
            NSRegularExpression.escapedPattern(for: variant)
        }.joined()

        // Create character class pattern
        let pattern = "[\(escapedVariants)]"
        variantPattern = (try? NSRegularExpression(pattern: pattern, options: [])) ??
            NSRegularExpression()
    }

    func process(_ text: String) -> String {
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = variantPattern.matches(in: text, options: [], range: range)

        var result = text
        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }
            let matchedString = String(result[matchRange])
            if let replacement = conversionMap[matchedString] {
                result.replaceSubrange(matchRange, with: replacement)
            }
        }

        return result
    }
}
