// CandidateRankingKey.swift
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

/// Ranking key derived from LookupCandidate properties (RankingCriteria 1-4).
struct CandidateRankingKey: Hashable, Comparable, Sendable {
    let sourceTermLength: Int
    let textProcessingChainLength: Int
    let inflectionChainLength: Int
    let deinflectionChainCount: Int

    init(candidate: LookupCandidate) {
        sourceTermLength = candidate.originalSubstring.count
        textProcessingChainLength = candidate.preprocessorRules.isEmpty
            ? 0
            : candidate.preprocessorRules.map(\.count).min() ?? 0
        inflectionChainLength = candidate.deinflectionInputRules.isEmpty
            ? 0
            : candidate.deinflectionInputRules.map(\.count).min() ?? 0
        deinflectionChainCount = candidate.deinflectionInputRules.count
    }

    static func < (lhs: CandidateRankingKey, rhs: CandidateRankingKey) -> Bool {
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
            if lhs.deinflectionChainCount == 0 {
                return false
            }
            if rhs.deinflectionChainCount == 0 {
                return true
            }
            return lhs.deinflectionChainCount < rhs.deinflectionChainCount
        }

        return false
    }
}
