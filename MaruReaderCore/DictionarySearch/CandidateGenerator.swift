// CandidateGenerator.swift
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

import Foundation

/// Generates `LookupCandidate` objects from user input through substring generation,
/// preprocessing, and deinflection pipelines.
struct DictionaryCandidateGenerator {
    // MARK: - Constants

    static let defaultMaxCandidates = 1000
    static let defaultMaxPreprocessorVariants = 5

    // MARK: - Properties

    private let maxCandidates: Int
    private let maxPreprocessorVariants: Int

    // MARK: - Initialization

    /// Initialize candidate generator with configurable limits
    /// - Parameters:
    ///   - maxCandidates: Maximum number of candidates to generate (default: 1000)
    ///   - maxPreprocessorVariants: Maximum variants per preprocessing step (default: 5)
    init(maxCandidates: Int = DictionaryCandidateGenerator.defaultMaxCandidates, maxPreprocessorVariants: Int = DictionaryCandidateGenerator.defaultMaxPreprocessorVariants) {
        self.maxCandidates = maxCandidates
        self.maxPreprocessorVariants = maxPreprocessorVariants
    }

    // MARK: - Public Methods

    /// Generate lookup candidates from user input
    /// - Parameter query: User search string
    /// - Returns: Array of `LookupCandidate` objects with full transformation provenance
    func generateCandidates(from query: String) -> [LookupCandidate] {
        guard !query.isEmpty else { return [] }

        var candidatesByText: [String: CandidateAccumulator] = [:]
        let candidatesPerSubstring = maxCandidates / 10 // Limit candidates per substring

        // Generate substrings from longest to shortest for relevance
        let substrings = generateSubstrings(from: query)

        for substring in substrings {
            var substringCandidateCount = 0

            // Create initial candidate
            let baseCandidate = LookupCandidate(from: substring)

            // Apply preprocessing pipeline
            let preprocessedCandidates = applyPreprocessing(to: baseCandidate)

            // Apply deinflection pipeline to each preprocessed candidate
            for preprocessedCandidate in preprocessedCandidates {
                let deinflectedCandidates = applyDeinflection(to: preprocessedCandidate)

                // Accumulate candidates by text, preserving all transformation chains
                for candidate in deinflectedCandidates {
                    // Skip empty candidates
                    guard !candidate.text.isEmpty else { continue }

                    let candidateKey = candidate.text + "|" + (candidate.deinflectionOutputRules.isEmpty ? "exact" : "deinflected")

                    if var accumulator = candidatesByText[candidateKey] {
                        // Merge transformation chains only for candidates of the same type
                        accumulator.addCandidate(candidate)
                        candidatesByText[candidateKey] = accumulator
                    } else {
                        // First occurrence of this text+type combination
                        candidatesByText[candidateKey] = CandidateAccumulator(candidate)
                        substringCandidateCount += 1
                    }

                    // Limit candidates per substring to ensure variety
                    if substringCandidateCount >= candidatesPerSubstring {
                        break
                    }
                }

                if substringCandidateCount >= candidatesPerSubstring {
                    break
                }
            }

            // Global limit check
            if candidatesByText.count >= maxCandidates {
                break
            }
        }

        return candidatesByText.values.map { $0.toLookupCandidate() }
    }

    // MARK: - Private Methods

    /// Generate substrings that start from the beginning of the query
    /// - Parameter query: Input string
    /// - Returns: Array of substrings ordered by length (longest first)
    private func generateSubstrings(from query: String) -> [String] {
        var substrings: [String] = []
        let characters = Array(query)

        // Generate substrings from start position only
        for endIndex in 1 ... characters.count {
            let substring = String(characters[0 ..< endIndex])
            substrings.append(substring)
        }

        // Sort by length descending for relevance (longer matches first)
        return substrings.sorted { $0.count > $1.count }
    }

    /// Apply text preprocessing rules to generate variants
    /// - Parameter candidate: Base lookup candidate
    /// - Returns: Array of candidates with preprocessing applied
    private func applyPreprocessing(to candidate: LookupCandidate) -> [LookupCandidate] {
        // Preprocessor config for Japanese, currently all rules enabled
        let defaultTextPreprocessorRules: [TextPreprocessorRule] = [
            NormalizeCJKCompatibilityCharactersRule(),
            NormalizeCombiningCharactersRule(),
            ConvertKanjiVariantsRule(),
            CollapseEmphaticSequencesRule(),
            ConvertHalfWidthCharactersRule(),
            ConvertAlphabeticToKanaRule(),
            ConvertHiraganaToKatakanaRule(),
            ConvertKatakanaToHiraganaRule(),
            ConvertFullWidthAlphanumericToNormalRule(),
            ConvertAlphanumericToFullWidthRule(),
        ]
        return JapaneseTextPreprocessor.generateVariants(candidate, using: defaultTextPreprocessorRules, maxVariants: maxPreprocessorVariants)
    }

    /// Apply deinflection rules to generate potential dictionary forms
    /// - Parameter candidate: Preprocessed lookup candidate
    /// - Returns: Array of candidates with deinflection applied
    private func applyDeinflection(to candidate: LookupCandidate) -> [LookupCandidate] {
        JapaneseDeinflector.deinflect(candidate)
    }
}

// MARK: - Supporting Types

/// Accumulates multiple candidates with the same text but different transformation chains
private struct CandidateAccumulator {
    let text: String
    let originalSubstring: String
    var preprocessorRules: [[String]]
    var deinflectionInputRules: [[String]]
    var deinflectionOutputRules: Set<String>

    init(_ candidate: LookupCandidate) {
        self.text = candidate.text
        self.originalSubstring = candidate.originalSubstring
        self.preprocessorRules = candidate.preprocessorRules
        self.deinflectionInputRules = candidate.deinflectionInputRules
        self.deinflectionOutputRules = Set(candidate.deinflectionOutputRules)
    }

    mutating func addCandidate(_ candidate: LookupCandidate) {
        // Merge all transformation chains
        preprocessorRules.append(contentsOf: candidate.preprocessorRules)
        deinflectionInputRules.append(contentsOf: candidate.deinflectionInputRules)
        deinflectionOutputRules.formUnion(candidate.deinflectionOutputRules)
    }

    func toLookupCandidate() -> LookupCandidate {
        LookupCandidate(
            text: text,
            originalSubstring: originalSubstring,
            preprocessorRules: preprocessorRules,
            deinflectionInputRules: deinflectionInputRules,
            deinflectionOutputRules: Array(deinflectionOutputRules)
        )
    }
}
