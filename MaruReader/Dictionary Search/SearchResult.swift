//
//  SearchResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import Foundation

struct SearchResult: Identifiable, Comparable {
    let candidate: LookupCandidate
    let term: String
    let reading: String?
    let definitions: [Definition]
    let frequency: Double?
    let dictionaryTitle: String
    let dictionaryUUID: UUID
    let displayPriority: Int
    let rankingCriteria: RankingCriteria
    let termTags: [Tag]
    let definitionTags: [Tag]
    let deinflectionRules: [[String]]

    var html: String {
        definitions.toHTML()
    }

    // Unique identifier combining multiple properties
    var id: String {
        "\(term)|\(reading ?? "")|\(dictionaryTitle)|\(candidate.text)|\(candidate.originalSubstring)"
    }

    // MARK: - Comparable Implementation

    static func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.rankingCriteria < rhs.rankingCriteria
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.rankingCriteria == rhs.rankingCriteria
    }
}
