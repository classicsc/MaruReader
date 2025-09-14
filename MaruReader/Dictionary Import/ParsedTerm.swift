//
//  ParsedTerm.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation

/// Intermediate representation of a Term from dictionary import, before Core Data insertion.
struct ParsedTerm {
    let expression: String
    let reading: String
    let definitionTags: [String]?
    let rules: String
    let score: Double
    let glossary: [Definition]
    let sequence: Int?
    let termTags: [String]?
    let dictionary: URL

    /// Initialize from a TermBankV3Entry and dictionary URI.
    init(from entry: TermBankV3Entry, dictionary: URL) {
        self.expression = entry.expression
        self.reading = entry.reading
        self.definitionTags = entry.definitionTags
        self.rules = entry.rules.joined(separator: " ")
        self.score = entry.score
        self.glossary = entry.glossary
        self.sequence = entry.sequence
        self.termTags = entry.termTags
        self.dictionary = dictionary
    }

    /// Initialize from a TermBankV1Entry and dictionary URI.
    init(from entry: TermBankV1Entry, dictionary: URL) {
        self.expression = entry.expression
        self.reading = entry.reading
        self.definitionTags = entry.definitionTags.isEmpty ? nil : entry.definitionTags
        self.rules = entry.rules.joined(separator: " ")
        self.score = entry.score
        self.glossary = entry.glossary
        self.sequence = nil
        self.termTags = nil
        self.dictionary = dictionary
    }
}
