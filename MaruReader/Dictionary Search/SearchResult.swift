//
//  SearchResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/23/25.
//

struct SearchResult: Identifiable {
    let candidate: LookupCandidate
    let term: String
    let reading: String?
    let definitions: [Definition]
    let frequency: Double?
    let dictionaryTitle: String
    let displayPriority: Int
    let rankScore: Double

    var html: String {
        definitions.toHTML()
    }

    // Unique identifier combining multiple properties
    var id: String {
        "\(term)|\(reading ?? "")|\(dictionaryTitle)|\(candidate.text)|\(candidate.originalSubstring)"
    }
}
