//
//  TermBankV3.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

/// A single term entry from the TermBank V3 schema.
struct TermBankV3Entry: Codable {
    let expression: String
    let reading: String
    let definitionTags: [String]? // nullable in schema
    let rules: [String]
    let score: Double
    let glossary: [Definition]
    let sequence: Int
    let termTags: [String]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 8 else { throw DictionaryImportError.invalidData }
        expression = try container.decode(String.self)
        reading = try container.decode(String.self)
        let rawDefinitionTags = try container.decodeIfPresent(String.self)
        let rawRules = try container.decode(String.self)
        score = try container.decode(Double.self)
        glossary = try container.decode([Definition].self)
        sequence = try container.decode(Int.self)
        let rawTermTags = try container.decode(String.self)
        if !container.isAtEnd {
            throw DictionaryImportError.invalidData
        }
        definitionTags = rawDefinitionTags.map { Self.splitSpaceSeparated($0) }
        rules = Self.splitSpaceSeparated(rawRules)
        termTags = Self.splitSpaceSeparated(rawTermTags)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(expression)
        try container.encode(reading)
        try container.encode(definitionTags)
        try container.encode(rules)
        try container.encode(score)
        try container.encode(glossary)
        try container.encode(sequence)
        try container.encode(termTags)
    }

    private static func splitSpaceSeparated(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }
            .map { String($0) }
    }
}

/// A definition can take several shapes per schema.
enum Definition: Codable {
    case text(String)
    case detailed(DefinitionDetailed)
    case deinflection(uninflected: String, rules: [String])

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(single)
            return
        }

        if var arr = try? decoder.unkeyedContainer() {
            let uninflected = try arr.decode(String.self)
            let rules = try arr.decode([String].self)
            self = .deinflection(uninflected: uninflected, rules: rules)
            return
        }

        if let obj = try? decoder.singleValueContainer().decode(DefinitionDetailed.self) {
            self = .detailed(obj)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath,
                                  debugDescription: "Invalid Definition format")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(str):
            var c = encoder.singleValueContainer()
            try c.encode(str)
        case let .detailed(detail):
            var c = encoder.singleValueContainer()
            try c.encode(detail)
        case let .deinflection(base, rules):
            var arr = encoder.unkeyedContainer()
            try arr.encode(base)
            try arr.encode(rules)
        }
    }
}

/// Detailed definition object (text, structured-content, or image).
enum DefinitionDetailed: Codable {
    case text(TextDef)
    case structured(StructuredContentDef)
    case image(ImageDef)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = try .text(TextDef(from: decoder))
        case "structured-content":
            self = try .structured(StructuredContentDef(from: decoder))
        case "image":
            self = try .image(ImageDef(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Unknown type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(t): try t.encode(to: encoder)
        case let .structured(s): try s.encode(to: encoder)
        case let .image(i): try i.encode(to: encoder)
        }
    }
}

/// Text definition
struct TextDef: Codable {
    let type: String // always "text"
    let text: String
}

/// Structured-content definition
struct StructuredContentDef: Codable {
    let type: String // always "structured-content"
    let content: StructuredContent
}

/// Image definition
struct ImageDef: Codable {
    let type: String // always "image"
    let path: String
    let width: Int?
    let height: Int?
    let title: String?
    let alt: String?
    let description: String?
    let pixelated: Bool?
    let imageRendering: String?
    let appearance: String?
    let background: Bool?
    let collapsed: Bool?
    let collapsible: Bool?
}

/// Recursive structured content type
enum StructuredContent: Codable {
    case text(String)
    case array([StructuredContent])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(str)
            return
        }
        if let arr = try? decoder.singleValueContainer().decode([StructuredContent].self) {
            self = .array(arr)
            return
        }
        if let dict = try? decoder.singleValueContainer().decode([String: AnyCodable].self) {
            self = .object(dict)
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath,
                                  debugDescription: "Invalid StructuredContent")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(str):
            var c = encoder.singleValueContainer()
            try c.encode(str)
        case let .array(arr):
            var c = encoder.singleValueContainer()
            try c.encode(arr)
        case let .object(dict):
            var c = encoder.singleValueContainer()
            try c.encode(dict)
        }
    }
}

/// Utility type for heterogenous JSON objects
struct AnyCodable: Codable {
    let value: Any

    init(_ value: (some Any)?) {
        self.value = value ?? ()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { value = b; return }
        if let i = try? container.decode(Int.self) { value = i; return }
        if let d = try? container.decode(Double.self) { value = d; return }
        if let s = try? container.decode(String.self) { value = s; return }
        if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value); return
        }
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }; return
        }
        value = ()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let arr as [Any]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}
