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
    let definitionTags: NSObject?
    let rules: String
    let score: Double
    let glossary: NSObject
    let sequence: Int64?
    let termTags: NSObject?

    /// Initialize from a TermBankV3Entry and dictionary URI.
    init(from entry: TermBankV3Entry) {
        self.expression = entry.expression
        self.reading = entry.reading
        self.definitionTags = StringArrayTransformer().transformedValue(entry.definitionTags) as? NSObject
        self.rules = entry.rules.joined(separator: " ")
        self.score = entry.score
        self.glossary = DefinitionArrayTransformer().transformedValue(entry.glossary) as? NSObject ?? Data() as NSObject
        self.sequence = Int64(entry.sequence)
        self.termTags = StringArrayTransformer().transformedValue(entry.termTags) as? NSObject
    }

    /// Initialize from a TermBankV1Entry and dictionary URI.
    init(from entry: TermBankV1Entry) {
        self.expression = entry.expression
        self.reading = entry.reading
        self.definitionTags = entry.definitionTags.isEmpty ? nil : StringArrayTransformer().transformedValue(entry.definitionTags) as? NSObject
        self.rules = entry.rules.joined(separator: " ")
        self.score = entry.score
        self.glossary = DefinitionArrayTransformer().transformedValue(entry.glossary) as? NSObject ?? Data() as NSObject
        self.sequence = nil
        self.termTags = nil
    }
}
