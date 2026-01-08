// TermBankV3.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
        let encoder = JSONEncoder()

        let glossaryData = (try? encoder.encode(self.glossary)) ?? Data()
        let glossaryString = String(data: glossaryData, encoding: .utf8) ?? "[]"

        let definitionTagsData = self.definitionTags != nil ? (try? encoder.encode(self.definitionTags)) ?? Data() : Data()
        let definitionTagsString = String(data: definitionTagsData, encoding: .utf8) ?? "[]"

        let rulesData = (try? encoder.encode(self.rules)) ?? Data()
        let rulesString = String(data: rulesData, encoding: .utf8) ?? "[]"

        let termTagsData = (try? encoder.encode(self.termTags)) ?? Data()
        let termTagsString = String(data: termTagsData, encoding: .utf8) ?? "[]"

        return (.termEntry, [
            "expression": self.expression,
            "reading": self.reading,
            "definitionTags": definitionTagsString,
            "dictionaryID": dictionaryID,
            "glossary": glossaryString,
            "id": UUID(),
            "rules": rulesString,
            "score": self.score,
            "sequence": Int64(self.sequence),
            "termTags": termTagsString,
        ])
    }

    private static func split(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }.map(String.init)
    }
}
