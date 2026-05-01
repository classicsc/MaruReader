// RankingCriteria.swift
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

/// Encapsulates the 11-tier ranking criteria for search results.
public struct RankingCriteria: Comparable, Sendable {
    // MARK: - Ranking Criteria (in order of precedence)

    /// 1. Source term length - longer originalSubstring wins
    let sourceTermLength: Int

    /// 2. Text processing chain length - shorter minimum chain length wins
    let textProcessingChainLength: Int

    /// 3. Deconjugation priority - lower generated candidate priority wins
    let inflectionChainLength: Int

    /// 4. Source term exact match - exact forms win, then more compatible paths win
    let deinflectionChainCount: Int

    /// 5. Candidate term length - longer generated lookup terms win
    let candidateTermLength: Int

    /// 6. Expression exact match - expression matches win over reading-only matches
    let exactExpressionMatch: Bool

    /// 7. Frequency order - depends on frequency mode
    let frequencyValue: Double?
    let frequencyMode: String?

    /// 8. Dictionary order - higher termDisplayPriority wins
    let dictionaryPriority: Int

    /// 9. Term score - higher score wins (only comparable within same dictionary)
    let termScore: Double
    let dictionaryTitle: String // For ensuring scores are only compared within same dictionary

    /// 10. Definition count - more definitions wins
    let definitionCount: Int

    /// 11. Lexicographic order - fallback comparison
    let term: String

    // MARK: - Initialization

    init(
        candidate: LookupCandidate,
        validatedDeconjugationPaths: [LookupCandidateDeconjugation],
        term: String,
        termScore: Double,
        definitionCount: Int,
        frequency: (value: Double?, mode: String?),
        dictionaryTitle: String,
        dictionaryPriority: Int
    ) {
        // 1. Source term length
        self.sourceTermLength = candidate.originalSubstring.count

        // 2. Text processing chain length (minimum of all chain lengths)
        self.textProcessingChainLength = candidate.preprocessorRules.isEmpty
            ? 0
            : candidate.preprocessorRules.map(\.count).min() ?? 0

        // 3. Deconjugation priority
        self.inflectionChainLength = validatedDeconjugationPaths.isEmpty
            ? 0
            : validatedDeconjugationPaths.map(\.priority).min() ?? 0

        // 4. Deconjugation path count
        self.deinflectionChainCount = validatedDeconjugationPaths.count

        // 5. Candidate term length
        self.candidateTermLength = candidate.text.count

        // 6. Expression exact match
        self.exactExpressionMatch = term == candidate.text

        // 7. Frequency
        self.frequencyValue = frequency.value
        self.frequencyMode = frequency.mode

        // 8. Dictionary priority
        self.dictionaryPriority = dictionaryPriority

        // 9. Term score and dictionary
        self.termScore = termScore
        self.dictionaryTitle = dictionaryTitle

        // 10. Definition count
        self.definitionCount = definitionCount

        // 11. Term for lexicographic comparison
        self.term = term
    }

    init(
        candidate: LookupCandidate,
        term: String,
        termScore: Double,
        definitionCount: Int,
        frequency: (value: Double?, mode: String?),
        dictionaryTitle: String,
        dictionaryPriority: Int
    ) {
        self.init(
            candidate: candidate,
            validatedDeconjugationPaths: candidate.deconjugationPaths,
            term: term,
            termScore: termScore,
            definitionCount: definitionCount,
            frequency: frequency,
            dictionaryTitle: dictionaryTitle,
            dictionaryPriority: dictionaryPriority
        )
    }

    init(
        candidate: LookupCandidate,
        validatedDeinflectionChains: [[String]],
        term: String,
        termScore: Double,
        definitionCount: Int,
        frequency: (value: Double?, mode: String?),
        dictionaryTitle: String,
        dictionaryPriority: Int
    ) {
        self.init(
            candidate: candidate,
            validatedDeconjugationPaths: validatedDeinflectionChains.map {
                LookupCandidateDeconjugation(process: $0, tags: [], priority: $0.count)
            },
            term: term,
            termScore: termScore,
            definitionCount: definitionCount,
            frequency: frequency,
            dictionaryTitle: dictionaryTitle,
            dictionaryPriority: dictionaryPriority
        )
    }

    /// Direct initializer for testing purposes
    public init(
        sourceTermLength: Int,
        textProcessingChainLength: Int,
        inflectionChainLength: Int,
        deinflectionChainCount: Int,
        frequencyValue: Double?,
        frequencyMode: String?,
        dictionaryPriority: Int,
        termScore: Double,
        dictionaryTitle: String,
        definitionCount: Int,
        term: String,
        candidateTermLength: Int? = nil,
        exactExpressionMatch: Bool = false
    ) {
        self.sourceTermLength = sourceTermLength
        self.textProcessingChainLength = textProcessingChainLength
        self.inflectionChainLength = inflectionChainLength
        self.deinflectionChainCount = deinflectionChainCount
        self.candidateTermLength = candidateTermLength ?? term.count
        self.exactExpressionMatch = exactExpressionMatch
        self.frequencyValue = frequencyValue
        self.frequencyMode = frequencyMode
        self.dictionaryPriority = dictionaryPriority
        self.termScore = termScore
        self.dictionaryTitle = dictionaryTitle
        self.definitionCount = definitionCount
        self.term = term
    }

    // MARK: - Comparable Implementation

    public static func < (lhs: RankingCriteria, rhs: RankingCriteria) -> Bool {
        // 1. Source term length - longer wins (reverse comparison)
        if lhs.sourceTermLength != rhs.sourceTermLength {
            return lhs.sourceTermLength < rhs.sourceTermLength
        }

        // 2. Text processing chain length - shorter wins
        if lhs.textProcessingChainLength != rhs.textProcessingChainLength {
            return lhs.textProcessingChainLength > rhs.textProcessingChainLength
        }

        // 3. Deconjugation priority - lower wins
        if lhs.inflectionChainLength != rhs.inflectionChainLength {
            return lhs.inflectionChainLength > rhs.inflectionChainLength
        }

        // 4. Deinflection chain count - exact matches (0) win, then more chains win
        if lhs.deinflectionChainCount != rhs.deinflectionChainCount {
            // Exact matches (0 chains) always win
            if lhs.deinflectionChainCount == 0 {
                return false // lhs wins
            }
            if rhs.deinflectionChainCount == 0 {
                return true // rhs wins
            }
            // Both have chains - more chains win
            return lhs.deinflectionChainCount < rhs.deinflectionChainCount
        }

        // 5. Candidate term length - longer generated lookup terms win
        if lhs.candidateTermLength != rhs.candidateTermLength {
            return lhs.candidateTermLength < rhs.candidateTermLength
        }

        // 6. Expression exact match - exact expression matches win
        if lhs.exactExpressionMatch != rhs.exactExpressionMatch {
            return !lhs.exactExpressionMatch
        }

        // 7. Frequency order - depends on mode
        let lhsFreq = lhs.frequencyValue
        let rhsFreq = rhs.frequencyValue

        if lhsFreq != rhsFreq {
            // Handle nil frequencies (nil is always worse)
            switch (lhsFreq, rhsFreq) {
            case (nil, nil):
                break // Continue to next criteria
            case (nil, _):
                return true // lhs is worse
            case (_, nil):
                return false // rhs is worse
            case let (lVal?, rVal?):
                // Both have frequency values, compare based on mode
                let lhsMode = lhs.frequencyMode ?? "rank-based"
                let rhsMode = rhs.frequencyMode ?? "rank-based"

                // If modes differ, prefer the one with a valid mode
                if lhsMode != rhsMode {
                    // This is an edge case - typically all results should have same mode
                    // Default to occurrence-based comparison
                    return lVal < rVal
                }

                if lhsMode == "rank-based" {
                    // Lower rank number is better
                    return lVal > rVal
                } else {
                    // occurrence-based: higher occurrence is better
                    return lVal < rVal
                }
            }
        }

        // 8. Dictionary order - higher priority wins (reverse comparison)
        if lhs.dictionaryPriority != rhs.dictionaryPriority {
            return lhs.dictionaryPriority < rhs.dictionaryPriority
        }

        // 9. Term score - only compare if from same dictionary
        if lhs.dictionaryTitle == rhs.dictionaryTitle, lhs.termScore != rhs.termScore {
            return lhs.termScore < rhs.termScore // Higher score wins
        }

        // 10. Definition count - more wins (reverse comparison)
        if lhs.definitionCount != rhs.definitionCount {
            return lhs.definitionCount < rhs.definitionCount
        }

        // 11. Lexicographic order - fallback (earlier terms display first)
        return lhs.term > rhs.term
    }

    public static func == (lhs: RankingCriteria, rhs: RankingCriteria) -> Bool {
        // Check criteria in the same order as the < comparison

        // 1-8: Check all criteria before term score
        if lhs.sourceTermLength != rhs.sourceTermLength ||
            lhs.textProcessingChainLength != rhs.textProcessingChainLength ||
            lhs.inflectionChainLength != rhs.inflectionChainLength ||
            lhs.deinflectionChainCount != rhs.deinflectionChainCount ||
            lhs.candidateTermLength != rhs.candidateTermLength ||
            lhs.exactExpressionMatch != rhs.exactExpressionMatch ||
            lhs.frequencyValue != rhs.frequencyValue ||
            lhs.frequencyMode != rhs.frequencyMode ||
            lhs.dictionaryPriority != rhs.dictionaryPriority
        {
            return false
        }

        // 9: Term score - only compare if from same dictionary
        if lhs.dictionaryTitle == rhs.dictionaryTitle, lhs.termScore != rhs.termScore {
            return false
        }

        // 10-11: Check remaining criteria
        return lhs.definitionCount == rhs.definitionCount &&
            lhs.term == rhs.term
    }
}
