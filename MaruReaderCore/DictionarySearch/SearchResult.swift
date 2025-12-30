//
//  SearchResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

import Foundation

public struct SearchResult: Identifiable, Comparable, Sendable {
    public let candidate: LookupCandidate
    public let term: String
    public let reading: String?
    public let definitions: [Definition]
    public let frequency: Double?
    public let frequencies: [FrequencyInfo]
    public let pitchAccents: [PitchAccentResults]
    public let dictionaryTitle: String
    public let dictionaryUUID: UUID
    public let displayPriority: Int
    public let rankingCriteria: RankingCriteria
    public let termTags: [Tag]
    public let definitionTags: [Tag]
    public let deinflectionRules: [[String]]
    public let sequence: Int64
    public let score: Double

    public init(
        candidate: LookupCandidate,
        term: String,
        reading: String?,
        definitions: [Definition],
        frequency: Double?,
        frequencies: [FrequencyInfo],
        pitchAccents: [PitchAccentResults],
        dictionaryTitle: String,
        dictionaryUUID: UUID,
        displayPriority: Int,
        rankingCriteria: RankingCriteria,
        termTags: [Tag],
        definitionTags: [Tag],
        deinflectionRules: [[String]],
        sequence: Int64,
        score: Double
    ) {
        self.candidate = candidate
        self.term = term
        self.reading = reading
        self.definitions = definitions
        self.frequency = frequency
        self.frequencies = frequencies
        self.pitchAccents = pitchAccents
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryUUID = dictionaryUUID
        self.displayPriority = displayPriority
        self.rankingCriteria = rankingCriteria
        self.termTags = termTags
        self.definitionTags = definitionTags
        self.deinflectionRules = deinflectionRules
        self.sequence = sequence
        self.score = score
    }

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
