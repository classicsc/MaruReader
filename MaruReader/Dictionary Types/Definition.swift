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

// MARK: - HTML Generation

extension StructuredElement {
    private static let selfClosingTags: Set<String> = ["img", "br", "hr", "input", "meta", "link"]

    func toHTML(baseURL: URL? = nil) -> String {
        var attributes: [String] = []

        // Add style attribute if present
        if let style {
            let cssString = style.toCSSString()
            if !cssString.isEmpty {
                attributes.append("style=\"\(escapeHTMLAttribute(cssString))\"")
            }
        }

        // Add language attribute
        if let lang {
            attributes.append("lang=\"\(escapeHTMLAttribute(lang))\"")
        }

        // Add tag-specific attributes
        switch tag {
        case "a":
            if let href {
                attributes.append("href=\"\(escapeHTMLAttribute(href))\"")
            }
        case "img":
            if let path {
                // Images in dictionary archives must use relative paths
                // Absolute URLs (with any scheme) should be treated as an error condition
                if let url = URL(string: path), url.scheme == nil {
                    // Valid relative path
                    let resolvedPath: String = if let baseURL {
                        // Resolve relative path to full URL
                        baseURL.appendingPathComponent(path).absoluteString
                    } else {
                        // No base URL provided, use path as-is
                        path
                    }
                    attributes.append("src=\"\(escapeHTMLAttribute(resolvedPath))\"")
                }
                // If path has a scheme, skip the src attribute but continue with other attributes
            }
            if let width {
                attributes.append("width=\"\(Int(width))\"")
            }
            if let height {
                attributes.append("height=\"\(Int(height))\"")
            }
            if let alt {
                attributes.append("alt=\"\(escapeHTMLAttribute(alt))\"")
            }
        case "td", "th":
            if let colSpan, colSpan > 1 {
                attributes.append("colspan=\"\(colSpan)\"")
            }
            if let rowSpan, rowSpan > 1 {
                attributes.append("rowspan=\"\(rowSpan)\"")
            }
        case "details":
            if let open, open {
                attributes.append("open")
            }
        default:
            break
        }

        // Add title attribute for any tag that has it
        if let title {
            attributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        // Add any custom data attributes
        if let data {
            for (key, value) in data {
                attributes.append("data-\(escapeHTMLAttribute(key))=\"\(escapeHTMLAttribute(value))\"")
            }
        }

        // Build the opening tag
        let attributeString = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")

        // Self-closing tags
        if Self.selfClosingTags.contains(tag) {
            return "<\(tag)\(attributeString) />"
        }

        // Generate content
        let contentHTML = generateContentHTML(baseURL: baseURL)

        return "<\(tag)\(attributeString)>\(contentHTML)</\(tag)>"
    }

    private func generateContentHTML(baseURL: URL?) -> String {
        guard let content else { return "" }
        return content.toHTML(baseURL: baseURL)
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

extension StructuredContent {
    func toHTML(baseURL: URL? = nil) -> String {
        switch self {
        case let .text(string):
            escapeHTML(string)
        case let .array(contents):
            contents.map { $0.toHTML(baseURL: baseURL) }.joined()
        case let .element(element):
            element.toHTML(baseURL: baseURL)
        }
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
