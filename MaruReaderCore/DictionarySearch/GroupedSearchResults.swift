//
//  GroupedSearchResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

public struct GroupedSearchResults: Identifiable, Sendable {
    let termKey: String
    let expression: String
    let reading: String?
    let dictionariesResults: [DictionaryResults]
    let pitchAccentResults: [PitchAccentResults]
    let termTags: [Tag]
    let deinflectionInfo: String?

    public var id: String { termKey }

    public var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }
}
