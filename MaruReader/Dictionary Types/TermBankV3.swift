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

    private static func split(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }.map(String.init)
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
    case element(StructuredElement)

    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(str)
            return
        }
        if let arr = try? decoder.singleValueContainer().decode([StructuredContent].self) {
            self = .array(arr)
            return
        }
        if let element = try? decoder.singleValueContainer().decode(StructuredElement.self) {
            self = .element(element)
            return // ensure we don't fall through to error
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath,
                                  debugDescription: "Invalid StructuredContent")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(str):
            var c = encoder.singleValueContainer(); try c.encode(str)
        case let .array(arr):
            var c = encoder.singleValueContainer(); try c.encode(arr)
        case let .element(elem):
            var c = encoder.singleValueContainer(); try c.encode(elem)
        }
    }
}

class StructuredElement: Codable {
    let tag: String
    let content: StructuredContent?
    let data: [String: String]?
    let style: ContentStyle?
    let lang: String?

    // Additional properties for specific tags
    let href: String? // for 'a' tags
    let path: String? // for 'img' tags
    let width: Double? // for 'img' tags
    let height: Double? // for 'img' tags
    let title: String?
    let alt: String?
    let colSpan: Int?
    let rowSpan: Int?
    let open: Bool? // for 'details' tags

    init(tag: String, content: StructuredContent?, data: [String: String]?, style: ContentStyle?, lang: String?, href: String?, path: String?, width: Double?, height: Double?, title: String?, alt: String?, colSpan: Int?, rowSpan: Int?, open: Bool?) {
        self.tag = tag
        self.content = content
        self.data = data
        self.style = style
        self.lang = lang
        self.href = href
        self.path = path
        self.width = width
        self.height = height
        self.title = title
        self.alt = alt
        self.colSpan = colSpan
        self.rowSpan = rowSpan
        self.open = open
    }
}
