//
//  RankingCriteria.swift
//  MaruReader
//
//  Created by Claude on 9/23/25.
//

import Foundation
import MaruReaderCore

/// Encapsulates the 9-tier ranking criteria for search results
struct RankingCriteria: Comparable {
    // MARK: - Ranking Criteria (in order of precedence)

    /// 1. Source term length - longer originalSubstring wins
    let sourceTermLength: Int

    /// 2. Text processing chain length - shorter minimum chain length wins
    let textProcessingChainLength: Int

    /// 3. Inflection chain length - shorter minimum chain length wins
    let inflectionChainLength: Int

    /// 4. Source term exact match - more deinflection chains wins
    let deinflectionChainCount: Int

    /// 5. Frequency order - depends on frequency mode
    let frequencyValue: Double?
    let frequencyMode: String?

    /// 6. Dictionary order - higher termDisplayPriority wins
    let dictionaryPriority: Int

    /// 7. Term score - higher score wins (only comparable within same dictionary)
    let termScore: Double
    let dictionaryTitle: String // For ensuring scores are only compared within same dictionary

    /// 8. Definition count - more definitions wins
    let definitionCount: Int

    /// 9. Lexicographic order - fallback comparison
    let term: String

    // MARK: - Initialization

    init(
        candidate: LookupCandidate,
        term: String,
        entry: TermEntry,
        definitions: [Definition],
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

        // 3. Inflection chain length (minimum of all chain lengths)
        self.inflectionChainLength = candidate.deinflectionInputRules.isEmpty
            ? 0
            : candidate.deinflectionInputRules.map(\.count).min() ?? 0

        // 4. Deinflection chain count
        self.deinflectionChainCount = candidate.deinflectionInputRules.count

        // 5. Frequency
        self.frequencyValue = frequency.value
        self.frequencyMode = frequency.mode

        // 6. Dictionary priority
        self.dictionaryPriority = dictionaryPriority

        // 7. Term score and dictionary
        self.termScore = entry.score
        self.dictionaryTitle = dictionaryTitle

        // 8. Definition count
        self.definitionCount = definitions.count

        // 9. Term for lexicographic comparison
        self.term = term
    }

    /// Direct initializer for testing purposes
    init(
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
        term: String
    ) {
        self.sourceTermLength = sourceTermLength
        self.textProcessingChainLength = textProcessingChainLength
        self.inflectionChainLength = inflectionChainLength
        self.deinflectionChainCount = deinflectionChainCount
        self.frequencyValue = frequencyValue
        self.frequencyMode = frequencyMode
        self.dictionaryPriority = dictionaryPriority
        self.termScore = termScore
        self.dictionaryTitle = dictionaryTitle
        self.definitionCount = definitionCount
        self.term = term
    }

    // MARK: - Comparable Implementation

    static func < (lhs: RankingCriteria, rhs: RankingCriteria) -> Bool {
        // 1. Source term length - longer wins (reverse comparison)
        if lhs.sourceTermLength != rhs.sourceTermLength {
            return lhs.sourceTermLength < rhs.sourceTermLength
        }

        // 2. Text processing chain length - shorter wins
        if lhs.textProcessingChainLength != rhs.textProcessingChainLength {
            return lhs.textProcessingChainLength > rhs.textProcessingChainLength
        }

        // 3. Inflection chain length - shorter wins
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

        // 5. Frequency order - depends on mode
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
                let lhsMode = lhs.frequencyMode ?? "occurrence-based"
                let rhsMode = rhs.frequencyMode ?? "occurrence-based"

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

        // 6. Dictionary order - higher priority wins (reverse comparison)
        if lhs.dictionaryPriority != rhs.dictionaryPriority {
            return lhs.dictionaryPriority < rhs.dictionaryPriority
        }

        // 7. Term score - only compare if from same dictionary
        if lhs.dictionaryTitle == rhs.dictionaryTitle, lhs.termScore != rhs.termScore {
            return lhs.termScore < rhs.termScore // Higher score wins
        }

        // 8. Definition count - more wins (reverse comparison)
        if lhs.definitionCount != rhs.definitionCount {
            return lhs.definitionCount < rhs.definitionCount
        }

        // 9. Lexicographic order - fallback (earlier terms display first)
        return lhs.term > rhs.term
    }

    static func == (lhs: RankingCriteria, rhs: RankingCriteria) -> Bool {
        // Check criteria in the same order as the < comparison

        // 1-6: Check all criteria before term score
        if lhs.sourceTermLength != rhs.sourceTermLength ||
            lhs.textProcessingChainLength != rhs.textProcessingChainLength ||
            lhs.inflectionChainLength != rhs.inflectionChainLength ||
            lhs.deinflectionChainCount != rhs.deinflectionChainCount ||
            lhs.frequencyValue != rhs.frequencyValue ||
            lhs.frequencyMode != rhs.frequencyMode ||
            lhs.dictionaryPriority != rhs.dictionaryPriority
        {
            return false
        }

        // 7: Term score - only compare if from same dictionary
        if lhs.dictionaryTitle == rhs.dictionaryTitle, lhs.termScore != rhs.termScore {
            return false
        }

        // 8-9: Check remaining criteria
        return lhs.definitionCount == rhs.definitionCount &&
            lhs.term == rhs.term
    }
}
