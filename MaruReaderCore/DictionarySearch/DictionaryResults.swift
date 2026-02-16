// DictionaryResults.swift
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

public struct DictionaryResults: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryUUID: UUID
    public let sequence: Int64
    public let score: Double
    public let results: [SearchResult]

    public var combinedHTML: String {
        results.generateCombinedHTML(dictionaryUUID: dictionaryUUID)
    }

    public var id: String {
        "\(dictionaryUUID)|\(sequence)"
    }

    public init(
        dictionaryTitle: String,
        dictionaryUUID: UUID,
        sequence: Int64,
        score: Double,
        results: [SearchResult]
    ) {
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryUUID = dictionaryUUID
        self.sequence = sequence
        self.score = score
        self.results = results
    }
}
