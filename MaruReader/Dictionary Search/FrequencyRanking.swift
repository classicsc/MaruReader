//
//  FrequencyRanking.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/16/25.
//

import CoreData
import Foundation

/// Represents frequency ranking data
struct FrequencyRanking {
    let value: FrequencyData
    let mode: String
    let dictionary: NSManagedObjectID
}

extension FrequencyRanking: Comparable {
    /// The comparison operator for frequency ranking representation. If `A < B`, the more frequent item is `A`, same as sort order in rank-based frequency lists.
    /// Generally, you should not compare frequency rankings from different dictionaries, but if you do, it will fall back to comparing dictionary IDs.
    static func < (lhs: FrequencyRanking, rhs: FrequencyRanking) -> Bool {
        // Only compare within same dictionary
        guard lhs.dictionary == rhs.dictionary else {
            // For different frequency dictionaries (hopefully rare), fall back to dictionary ID comparison to have a tie-breaker
            return lhs.dictionary.uriRepresentation().absoluteString < rhs.dictionary.uriRepresentation().absoluteString
        }

        // Same dictionary - compare based on mode
        switch (lhs.mode, rhs.mode) {
        case ("rank-based", "rank-based"):
            return lhs.value < rhs.value // Lower rank is better
        case ("occurrence-based", "occurrence-based"):
            return lhs.value > rhs.value // Higher count is better (reverse order)
        case ("rank-based", "occurrence-based"):
            return true // Rank-based is always "less than" (better than) occurrence-based
        case ("occurrence-based", "rank-based"):
            return false // Occurrence-based is never "less than" rank-based
        default:
            return lhs.value < rhs.value // Default to rank-based logic
        }
    }

    static func == (lhs: FrequencyRanking, rhs: FrequencyRanking) -> Bool {
        lhs.dictionary == rhs.dictionary &&
            lhs.mode == rhs.mode &&
            lhs.value == rhs.value
    }
}
