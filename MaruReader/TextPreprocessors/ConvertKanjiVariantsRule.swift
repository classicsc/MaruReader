//
//  ConvertKanjiVariantsRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//

import Foundation

/// Normalizes kanji variant forms to their standard forms
/// Based on Yomitan's convertVariants function using itaiji data
class ConvertKanjiVariantsRule: TextPreprocessorRule {
    let name = "convertKanjiVariants"
    let description = "Convert kanji variants to standard forms: 弌 → 一, 萬 → 万"

    private let conversionMap: [String: String]
    private let variantPattern: NSRegularExpression

    /// Initialize with kanji mapping data from JSON files
    init() {
        var tempConversionMap: [String: String] = [:]
        var variantCharacters: Set<String> = []

        // Load full_list.json for mappings
        if let url = Bundle.main.url(forResource: "full_list", withExtension: "json"),
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
        if let url = Bundle.main.url(forResource: "itaiji_list", withExtension: "json"),
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
