//
//  Definition.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/14/25.
//

import Foundation

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
