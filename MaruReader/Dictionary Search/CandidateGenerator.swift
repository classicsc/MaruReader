//
//  CandidateGenerator.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import Foundation

/// Generates `LookupCandidate` objects from user input through substring generation,
/// preprocessing, and deinflection pipelines.
class DictionaryCandidateGenerator {
    // MARK: - Properties

    private let preprocessor: JapaneseTextPreprocessor
    private let deinflector: JapaneseDeinflector
    private let maxCandidates: Int

    // MARK: - Initialization

    /// Initialize candidate generator with configurable limits
    /// - Parameters:
    ///   - maxCandidates: Maximum number of candidates to generate (default: 1000)
    ///   - maxPreprocessorVariants: Maximum variants per preprocessing step (default: 5)
    init(maxCandidates: Int = 1000, maxPreprocessorVariants: Int = 5) {
        self.maxCandidates = maxCandidates
        self.preprocessor = JapaneseTextPreprocessor(maxVariants: maxPreprocessorVariants)
        self.deinflector = JapaneseDeinflector()
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
                    if var accumulator = candidatesByText[candidate.text] {
                        // Merge transformation chains
                        accumulator.addCandidate(candidate)
                        candidatesByText[candidate.text] = accumulator
                    } else {
                        // First occurrence of this text
                        candidatesByText[candidate.text] = CandidateAccumulator(candidate)
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
        // For now, we'll start with the base candidate as-is
        // This can be extended with actual preprocessing rules later
        [candidate]
    }

    /// Apply deinflection rules to generate potential dictionary forms
    /// - Parameter candidate: Preprocessed lookup candidate
    /// - Returns: Array of candidates with deinflection applied
    private func applyDeinflection(to candidate: LookupCandidate) -> [LookupCandidate] {
        deinflector.deinflect(candidate)
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
