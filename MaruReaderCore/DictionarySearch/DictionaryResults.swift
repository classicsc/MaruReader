//
//  DictionaryResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

import Foundation

public struct DictionaryResults: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryUUID: UUID
    public let sequence: Int64
    public let score: Double
    public let results: [SearchResult]
    public let combinedHTML: String

    public var id: String { "\(dictionaryUUID)|\(sequence)" }

    public init(
        dictionaryTitle: String,
        dictionaryUUID: UUID,
        sequence: Int64,
        score: Double,
        results: [SearchResult],
        combinedHTML: String
    ) {
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryUUID = dictionaryUUID
        self.sequence = sequence
        self.score = score
        self.results = results
        self.combinedHTML = combinedHTML
    }
}
