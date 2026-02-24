// TextPreprocessor.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

// MARK: - Preprocessor Protocol

protocol TextPreprocessorRule {
    var name: String { get }
    var description: String { get }
    func process(_ text: String) -> String
}

// MARK: - Preprocessor Implementation

enum JapaneseTextPreprocessor {
    /// Generate text variants by applying preprocessor rules
    /// - Parameters:
    ///   - text: Input text to preprocess
    ///   - rules: Array of preprocessor rules to apply
    ///   - maxVariants: Maximum number of variants to generate
    /// - Returns: Tuple containing array of text variants and mapping of variants to applied rules
    static func generateVariants(_ text: String, using rules: [TextPreprocessorRule], maxVariants: Int) -> (variants: [String], appliedRules: [String: [String]]) {
        var variants: Set<String> = [text] // Start with original text
        var currentVariants = [text]
        var appliedRules: [String: [String]] = [text: []] // Track rules for each variant

        // Apply each rule to all current variants
        for rule in rules {
            var newVariants: [String] = []

            for variant in currentVariants {
                let processed = rule.process(variant)
                newVariants.append(processed)

                // If processing changed the text, add it as a new variant
                if processed != variant {
                    variants.insert(processed)

                    // Track which rules were applied to get this variant
                    let previousRules = appliedRules[variant] ?? []
                    appliedRules[processed] = previousRules + [rule.name]

                    // Limit variants to prevent explosion
                    if variants.count >= maxVariants {
                        break
                    }
                }
            }

            // Update current variants for next rule
            currentVariants = Array(variants)

            if variants.count >= maxVariants {
                break
            }
        }

        let result = Array(variants)
        return (result, appliedRules)
    }

    /// Generate LookupCandidates by applying preprocessor rules, preserving original metadata
    /// - Parameters:
    ///   - candidate: Input LookupCandidate to preprocess
    ///   - rules: Array of preprocessor rules to apply
    ///   - maxVariants: Maximum number of variants to generate
    /// - Returns: Array of LookupCandidates with preprocessing rules applied
    static func generateVariants(_ candidate: LookupCandidate, using rules: [TextPreprocessorRule], maxVariants: Int) -> [LookupCandidate] {
        let (variants, appliedRules) = generateVariants(candidate.text, using: rules, maxVariants: maxVariants)

        return variants.map { variant in
            // Add preprocessor rules for this variant
            let rulesForVariant = appliedRules[variant] ?? []
            let newPreprocessorRules = candidate.preprocessorRules + [rulesForVariant]

            // Create new LookupCandidate with preserved metadata
            return LookupCandidate(
                text: variant,
                originalSubstring: candidate.originalSubstring,
                preprocessorRules: newPreprocessorRules,
                deinflectionInputRules: candidate.deinflectionInputRules,
                deinflectionOutputRulesPerChain: candidate.deinflectionOutputRulesPerChain
            )
        }
    }
}

// MARK: - Supporting Types

/// Structure matching the JSON format for kanji mappings
struct KanjiMapping: Codable {
    let oyaji: String // Standard form
    let itaiji: [String] // Variant forms
}
