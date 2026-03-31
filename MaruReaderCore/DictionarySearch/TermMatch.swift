// TermMatch.swift
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

/// Lightweight search match carrying ranking metadata and compressed glossary data.
/// Used in the match/rank/group phase of the search pipeline. Glossary decompression
/// and auxiliary data fetches (pitch accents, tags) are deferred to materialization.
public struct TermMatch: Comparable, Sendable {
    public let candidate: LookupCandidate
    public let term: String
    public let reading: String?
    public let glossaryData: Data
    public let definitionCount: Int
    public let rankingFrequency: FrequencyInfo?
    public let dictionaryTitle: String
    public let dictionaryUUID: UUID
    public let displayPriority: Int
    public let rankingCriteria: RankingCriteria
    public let termTagsRaw: String?
    public let definitionTagsRaw: String?
    public let deinflectionRules: [[String]]
    public let sequence: Int64
    public let score: Double

    public init(
        candidate: LookupCandidate,
        term: String,
        reading: String?,
        glossaryData: Data,
        definitionCount: Int,
        rankingFrequency: FrequencyInfo?,
        dictionaryTitle: String,
        dictionaryUUID: UUID,
        displayPriority: Int,
        rankingCriteria: RankingCriteria,
        termTagsRaw: String?,
        definitionTagsRaw: String?,
        deinflectionRules: [[String]],
        sequence: Int64,
        score: Double
    ) {
        self.candidate = candidate
        self.term = term
        self.reading = reading
        self.glossaryData = glossaryData
        self.definitionCount = definitionCount
        self.rankingFrequency = rankingFrequency
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryUUID = dictionaryUUID
        self.displayPriority = displayPriority
        self.rankingCriteria = rankingCriteria
        self.termTagsRaw = termTagsRaw
        self.definitionTagsRaw = definitionTagsRaw
        self.deinflectionRules = deinflectionRules
        self.sequence = sequence
        self.score = score
    }

    // MARK: - Comparable

    public static func < (lhs: TermMatch, rhs: TermMatch) -> Bool {
        lhs.rankingCriteria < rhs.rankingCriteria
    }

    public static func == (lhs: TermMatch, rhs: TermMatch) -> Bool {
        lhs.rankingCriteria == rhs.rankingCriteria
    }
}
