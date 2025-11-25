//
//  SearchResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import Foundation

public struct SearchResult: Identifiable, Comparable, Sendable {
    let candidate: LookupCandidate
    let term: String
    let reading: String?
    let definitions: [Definition]
    let frequency: Double?
    let frequencies: [FrequencyInfo]
    let dictionaryTitle: String
    let dictionaryUUID: UUID
    let displayPriority: Int
    let rankingCriteria: RankingCriteria
    let termTags: [Tag]
    let definitionTags: [Tag]
    let deinflectionRules: [[String]]
    let sequence: Int64
    let score: Double

    public var html: String {
        definitions.toHTML()
    }

    // Unique identifier combining multiple properties
    public var id: String {
        "\(term)|\(reading ?? "")|\(dictionaryTitle)|\(candidate.text)|\(candidate.originalSubstring)|\(sequence)"
    }

    // MARK: - Comparable Implementation

    public static func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.rankingCriteria < rhs.rankingCriteria
    }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.rankingCriteria == rhs.rankingCriteria
    }
}
