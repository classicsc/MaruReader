//
//  GroupedSearchResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

struct GroupedSearchResults: Identifiable {
    let termKey: String
    let expression: String
    let reading: String?
    let dictionariesResults: [DictionaryResults]
    let termTags: [Tag]
    let deinflectionInfo: String?

    var id: String { termKey }

    var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }
}
