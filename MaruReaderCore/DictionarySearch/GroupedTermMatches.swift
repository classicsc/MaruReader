// GroupedTermMatches.swift
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

/// Lightweight grouped term matches for the ranking/grouping phase.
/// Holds compressed glossary data and raw tag strings — no decompression or
/// auxiliary Core Data fetches have occurred yet.
public struct GroupedTermMatches: Identifiable, Sendable {
    public let termKey: String
    public let expression: String
    public let reading: String?
    public let dictionaryMatches: [DictionaryTermMatches]
    public let topRankingCriteria: RankingCriteria
    public let deinflectionRules: [[String]]

    public var id: String {
        termKey
    }

    public init(
        termKey: String,
        expression: String,
        reading: String?,
        dictionaryMatches: [DictionaryTermMatches],
        topRankingCriteria: RankingCriteria,
        deinflectionRules: [[String]]
    ) {
        self.termKey = termKey
        self.expression = expression
        self.reading = reading
        self.dictionaryMatches = dictionaryMatches
        self.topRankingCriteria = topRankingCriteria
        self.deinflectionRules = deinflectionRules
    }
}

/// Per-dictionary sub-group within a GroupedTermMatches.
public struct DictionaryTermMatches: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryUUID: UUID
    public let displayPriority: Int
    public let sequence: Int64
    public let score: Double
    public let matches: [TermMatch]

    public var id: String {
        "\(dictionaryUUID)|\(sequence)"
    }

    public init(
        dictionaryTitle: String,
        dictionaryUUID: UUID,
        displayPriority: Int,
        sequence: Int64,
        score: Double,
        matches: [TermMatch]
    ) {
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryUUID = dictionaryUUID
        self.displayPriority = displayPriority
        self.sequence = sequence
        self.score = score
        self.matches = matches
    }
}
