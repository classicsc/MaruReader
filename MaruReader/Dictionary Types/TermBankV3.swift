//
//  TermBankV3.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

/// A single term entry from the TermBank V3 schema.
struct TermBankV3Entry: DictionaryDataBankEntry {
    let expression: String
    let reading: String
    let definitionTags: [String]? // null | space‑separated string
    let rules: [String] // space‑separated string
    let score: Double
    let glossary: [Definition]
    let sequence: Int
    let termTags: [String] // space‑separated string

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        expression = try container.decode(String.self)
        reading = try container.decode(String.self)

        // definitionTags: string or null
        if try container.decodeNil() {
            definitionTags = nil
        } else {
            let tagString = try container.decode(String.self)
            definitionTags = tagString.isEmpty ? [] : Self.split(tagString)
        }

        let rawRules = try container.decode(String.self)
        score = try container.decode(Double.self)
        glossary = try container.decode([Definition].self)
        sequence = try container.decode(Int.self)
        let rawTermTags = try container.decode(String.self)

        if !container.isAtEnd {
            throw DictionaryImportError.invalidData
        }

        rules = rawRules.isEmpty ? [] : Self.split(rawRules)
        termTags = rawTermTags.isEmpty ? [] : Self.split(rawTermTags)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(expression)
        try container.encode(reading)

        if let tags = definitionTags {
            try container.encode(tags.joined(separator: " "))
        } else {
            try container.encodeNil()
        }

        try container.encode(rules.joined(separator: " "))
        try container.encode(score)
        try container.encode(glossary)
        try container.encode(sequence)
        try container.encode(termTags.joined(separator: " "))
    }

    func toDataDictionary(dictionaryID: UUID) -> (DictionaryDataType, [String: any Sendable]) {
        let stringArrayTransformer = StringArrayTransformer()
        let definitionArrayTransformer = DefinitionArrayTransformer()
        return (.termEntry, [
            "expression": self.expression,
            "reading": self.reading,
            "definitionTags": stringArrayTransformer.transformedValue(self.definitionTags ?? []) as? Data ?? Data(),
            "dictionaryID": dictionaryID,
            "glossary": definitionArrayTransformer.transformedValue(self.glossary) as? Data ?? Data(),
            "id": UUID(),
            "rules": stringArrayTransformer.transformedValue(self.rules) as? Data ?? Data(),
            "score": self.score,
            "sequence": Int64(self.sequence),
            "termTags": stringArrayTransformer.transformedValue(self.termTags) as? Data ?? Data(),
        ])
    }

    private static func split(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }.map(String.init)
    }
}
