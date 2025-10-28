//
//  TextPreprocessor.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/9/25.
//
// This file is derived from japanese-text-preprocessors.js, part of the Yomitan project.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

import Foundation

// MARK: - Preprocessor Protocol

protocol TextPreprocessorRule {
    var name: String { get }
    var description: String { get }
    func process(_ text: String) -> String
}

// MARK: - Preprocessor Implementation

struct JapaneseTextPreprocessor {
    // MARK: - Properties

    private let maxVariants: Int
    private var cache: [String: [String]] = [:]
    private var rulesCache: [String: [String: [String]]] = [:]

    // MARK: - Initialization

    init(maxVariants: Int = 5) {
        self.maxVariants = maxVariants
    }

    // MARK: - Public Methods

    /// Generate text variants by applying preprocessor rules
    /// - Parameters:
    ///   - text: Input text to preprocess
    ///   - rules: Array of preprocessor rules to apply
    /// - Returns: Tuple containing array of text variants and mapping of variants to applied rules
    mutating func generateVariants(_ text: String, using rules: [TextPreprocessorRule]) -> (variants: [String], appliedRules: [String: [String]]) {
        // Check cache first
        let cacheKey = createCacheKey(text: text, rules: rules)
        if let cached = cache[cacheKey], let cachedRules = rulesCache[cacheKey] {
            return (cached, cachedRules)
        }

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
        cache[cacheKey] = result
        rulesCache[cacheKey] = appliedRules
        return (result, appliedRules)
    }

    /// Generate LookupCandidates by applying preprocessor rules, preserving original metadata
    /// - Parameters:
    ///   - candidate: Input LookupCandidate to preprocess
    ///   - rules: Array of preprocessor rules to apply
    /// - Returns: Array of LookupCandidates with preprocessing rules applied
    mutating func generateVariants(_ candidate: LookupCandidate, using rules: [TextPreprocessorRule]) -> [LookupCandidate] {
        let (variants, appliedRules) = generateVariants(candidate.text, using: rules)

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
                deinflectionOutputRules: candidate.deinflectionOutputRules
            )
        }
    }

    // MARK: - Private Methods

    private func createCacheKey(text: String, rules: [TextPreprocessorRule]) -> String {
        let ruleNames = rules.map(\.name).joined(separator: "|")
        return "\(text):\(ruleNames)"
    }
}

// MARK: - Supporting Types

/// Structure matching the JSON format for kanji mappings
struct KanjiMapping: Codable {
    let oyaji: String // Standard form
    let itaiji: [String] // Variant forms
}
