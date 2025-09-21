//
//  Definition.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/14/25.
//

import Foundation

/// A definition can take several shapes per schema.
enum Definition: Codable, Sendable {
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
enum DefinitionDetailed: Codable, Sendable {
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

// MARK: - HTML Conversion

extension Definition {
    func toHTML(baseURL: URL? = nil) -> String {
        switch self {
        case let .text(text):
            return wrapDefinitionText(text)
        case let .detailed(detail):
            switch detail {
            case let .text(textDef):
                return wrapDefinitionText(textDef.text)
            case let .structured(structuredDef):
                return structuredDef.content.toHTML(baseURL: baseURL)
            case let .image(imageDef):
                return imageHTML(from: imageDef, baseURL: baseURL)
            }
        case let .deinflection(uninflected, rules):
            let escapedUninflected = escapeHTML(uninflected)
            let escapedRules = rules.map { escapeHTML($0) }.joined(separator: ", ")
            return "<p class=\"deinflection\">Uninflected: \(escapedUninflected) (Rules: \(escapedRules))</p>"
        }
    }

    private func wrapDefinitionText(_ text: String) -> String {
        "<p class=\"definition-text\">\(escapeHTML(text))</p>"
    }

    private func imageHTML(from image: ImageDef, baseURL: URL?) -> String {
        var attributes: [String] = []

        if let resolvedSource = resolveImageSource(path: image.path, baseURL: baseURL) {
            attributes.append("src=\"\(escapeHTMLAttribute(resolvedSource))\"")
        }

        if let width = image.width {
            attributes.append("width=\"\(width)\"")
        }

        if let height = image.height {
            attributes.append("height=\"\(height)\"")
        }

        if let alt = image.alt {
            attributes.append("alt=\"\(escapeHTMLAttribute(alt))\"")
        }

        if let title = image.title {
            attributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        if let style = imageStyle(from: image) {
            attributes.append("style=\"\(escapeHTMLAttribute(style))\"")
        }

        let attributeString = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")
        return "<img\(attributeString) />"
    }

    private func resolveImageSource(path: String, baseURL: URL?) -> String? {
        guard let url = URL(string: path) else {
            return nil
        }

        // If the path has a scheme, it should be treated as invalid per schema rules.
        guard url.scheme == nil else {
            return nil
        }

        if let baseURL {
            return baseURL.appendingPathComponent(path).absoluteString
        }

        return path
    }

    private func imageStyle(from image: ImageDef) -> String? {
        var styleComponents: [String] = []

        if let imageRendering = image.imageRendering {
            if imageRendering != "auto" {
                styleComponents.append("image-rendering: \(imageRendering)")
            }
        } else if image.pixelated == true {
            styleComponents.append("image-rendering: pixelated")
        }

        return styleComponents.isEmpty ? nil : styleComponents.joined(separator: "; ")
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func escapeHTMLAttribute(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

/// Render arrays of definitions as ordered lists in HTML.
extension [Definition] {
    func toHTML(baseURL: URL? = nil) -> String {
        let itemsHTML = self.map { "<li>\($0.toHTML(baseURL: baseURL))</li>" }.joined()
        return "<ol class=\"glossary-list\">\(itemsHTML)</ol>"
    }
}

/// Text definition
struct TextDef: Codable, Sendable {
    let type: String // always "text"
    let text: String
}

/// Structured-content definition
struct StructuredContentDef: Codable, Sendable {
    let type: String // always "structured-content"
    let content: StructuredContent
}

/// Image definition
struct ImageDef: Codable, Sendable {
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
