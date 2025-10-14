//
//  DictionaryResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

import Foundation

struct DictionaryResults: Identifiable {
    let dictionaryTitle: String
    let dictionaryUUID: UUID
    let sequence: Int64
    let results: [SearchResult]
    let combinedHTML: String

    var id: String { "\(dictionaryUUID)|\(sequence)" }
}
