//
//  CandidateGenerator.swift
//  MaruReader
//
//  Coordinates text preprocessing and deinflection to generate lookup candidates.
//

import Foundation

/// Coordinates text preprocessing and deinflection to generate comprehensive lookup candidates
class CandidateGenerator {
    // MARK: - Properties

    private let textPreprocessor: JapaneseTextPreprocessor
    private let deinflector: JapaneseDeinflector
    private let preprocessorRules: [TextPreprocessorRule]

    // MARK: - Initialization

    init(
        textPreprocessor: JapaneseTextPreprocessor? = nil,
        deinflector: JapaneseDeinflector? = nil,
        preprocessorRules: [TextPreprocessorRule]? = nil
    ) {
        self.textPreprocessor = textPreprocessor ?? JapaneseTextPreprocessor()
        self.deinflector = deinflector ?? JapaneseDeinflector()
        self.preprocessorRules = preprocessorRules ?? Self.defaultPreprocessorRules()
    }

    // MARK: - Public Methods

    /// Generate all lookup candidates for a given text
    /// - Parameters:
    ///   - text: Input text to generate candidates for
    ///   - maxDeinflectionDepth: Maximum depth for deinflection processing
    /// - Returns: Array of lookup candidates with preprocessing and deinflection applied
    func generateCandidates(
        for text: String,
        maxDeinflectionDepth: Int = 10
    ) -> [LookupCandidate] {
        // Start with the original text as a base candidate
        let baseCandidate = LookupCandidate(from: text)
        var allCandidates: [LookupCandidate] = []

        // Step 1: Apply text preprocessing to generate variants
        let preprocessedCandidates = textPreprocessor.generateVariants(
            baseCandidate,
            using: preprocessorRules
        )

        // Step 2: Apply deinflection to each preprocessed candidate
        for preprocessedCandidate in preprocessedCandidates {
            let deinflectedCandidates = deinflector.deinflect(
                preprocessedCandidate,
                maxDepth: maxDeinflectionDepth
            )
            allCandidates.append(contentsOf: deinflectedCandidates)
        }

        // Remove duplicates based on text content while preserving the best candidate
        // (shortest processing chain for the same text)
        return removeDuplicates(from: allCandidates)
    }

    /// Generate candidates for multiple substring lengths
    /// - Parameters:
    ///   - originalText: Original input text
    ///   - maxDeinflectionDepth: Maximum depth for deinflection processing
    /// - Returns: Dictionary mapping substring to its candidates
    func generateCandidatesForSubstrings(
        of originalText: String,
        maxDeinflectionDepth: Int = 10
    ) -> [String: [LookupCandidate]] {
        var substringCandidates: [String: [LookupCandidate]] = [:]
        var currentText = originalText

        while !currentText.isEmpty {
            let candidates = generateCandidates(
                for: currentText,
                maxDeinflectionDepth: maxDeinflectionDepth
            )
            substringCandidates[currentText] = candidates

            // Remove the last character for next iteration
            currentText = String(currentText.dropLast())
        }

        return substringCandidates
    }

    // MARK: - Private Methods

    /// Remove duplicate candidates, keeping the one with shortest processing chain
    private func removeDuplicates(from candidates: [LookupCandidate]) -> [LookupCandidate] {
        var seenTexts: [String: LookupCandidate] = [:]

        for candidate in candidates {
            let key = candidate.text

            if let existing = seenTexts[key] {
                // Keep the candidate with shorter processing chain
                let candidateChainLength = candidate.preprocessorRules.count + candidate.deinflectionInputRules.count
                let existingChainLength = existing.preprocessorRules.count + existing.deinflectionInputRules.count

                if candidateChainLength < existingChainLength {
                    seenTexts[key] = candidate
                }
            } else {
                seenTexts[key] = candidate
            }
        }

        return Array(seenTexts.values)
    }

    /// Default set of text preprocessor rules for Japanese text
    private static func defaultPreprocessorRules() -> [TextPreprocessorRule] {
        [
            // Normalization rules (applied first for consistency)
            NormalizeCombiningCharactersRule(),
            NormalizeCJKCompatibilityCharactersRule(),

            // Character conversion rules
            ConvertKatakanaToHiraganaRule(),
            ConvertHiraganaToKatakanaRule(),
            ConvertHalfWidthCharactersRule(),
            ConvertFullWidthAlphanumericToNormalRule(),
            ConvertAlphanumericToFullWidthRule(),

            // Specialized conversion rules
            ConvertKanjiVariantsRule(),
            ConvertAlphabeticToKanaRule(),

            // Text cleanup rules (applied last)
            CollapseEmphaticSequencesRule(),
        ]
    }
}

// MARK: - Extensions

extension CandidateGenerator {
    /// Convenience method to get candidates for a specific substring length
    func generateCandidates(
        for text: String,
        substringLength: Int,
        maxDeinflectionDepth: Int = 10
    ) -> [LookupCandidate] {
        let substring = String(text.prefix(substringLength))
        return generateCandidates(for: substring, maxDeinflectionDepth: maxDeinflectionDepth)
    }

    /// Get statistics about candidate generation
    func getCandidateStatistics(for text: String) -> (
        originalLength: Int,
        preprocessedVariants: Int,
        totalCandidates: Int
    ) {
        let baseCandidate = LookupCandidate(from: text)
        let preprocessedCandidates = textPreprocessor.generateVariants(
            baseCandidate,
            using: preprocessorRules
        )

        var totalCandidates = 0
        for preprocessedCandidate in preprocessedCandidates {
            let deinflectedCandidates = deinflector.deinflect(preprocessedCandidate)
            totalCandidates += deinflectedCandidates.count
        }

        return (
            originalLength: text.count,
            preprocessedVariants: preprocessedCandidates.count,
            totalCandidates: totalCandidates
        )
    }
}
