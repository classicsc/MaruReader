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
    func toHTML(baseURL: URL? = nil, devicePixelRatio: CGFloat? = nil, baseFontSize: CGFloat? = nil) -> String {
        // Convert CGFloat parameters to Double for consistency
        let devicePixelRatioDouble = devicePixelRatio.map(Double.init)
        let emSizeDouble = baseFontSize.map(Double.init)

        switch self {
        case let .text(text):
            return wrapDefinitionText(text)
        case let .detailed(detail):
            switch detail {
            case let .text(textDef):
                return wrapDefinitionText(textDef.text)
            case let .structured(structuredDef):
                return structuredDef.content.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatioDouble, emSize: emSizeDouble)
            case let .image(imageDef):
                let imageElement = imageDef.toStructuredElement()
                let html = imageElement.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatioDouble, emSize: emSizeDouble)

                // Add description if present (StructuredElement doesn't handle this since it uses title for tooltip)
                if let description = imageDef.description {
                    return "<div class=\"gloss-image-def\"><div class=\"gloss-image-main\">\(html)</div><span class=\"gloss-image-desc\">\(escapeHTML(description))</span></div>"
                }

                return "<div class=\"gloss-image-def\">\(html)</div>"
            }
        case let .deinflection(uninflected, rules):
            let escapedUninflected = escapeHTML(uninflected)
            let escapedRules = rules.map { escapeHTML($0) }.joined(separator: ", ")
            return "<p class=\"gloss-deinflection\" data-uninflected=\"\(escapedUninflected)\" data-rules=\"\(escapedRules)\">Uninflected: \(escapedUninflected) (Rules: \(escapedRules))</p>"
        }
    }

    private func wrapDefinitionText(_ text: String) -> String {
        let escapedText = escapeHTML(text).replacingOccurrences(of: "\n", with: "<br>")
        return "<p class=\"gloss-definition-text\">\(escapedText)</p>"
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
    func toHTML(baseURL: URL? = nil, devicePixelRatio: CGFloat? = nil, baseFontSize: CGFloat? = nil) -> String {
        let itemsHTML = self.enumerated().map { index, definition in
            let definitionHTML = definition.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, baseFontSize: baseFontSize)

            // Determine if content should have structured-content class
            let contentClass = definition.isStructuredContent ? "gloss-content structured-content" : "gloss-content"

            return "<li class=\"gloss-item click-scannable\" data-index=\"\(index)\"><span class=\"gloss-separator\"> </span><span class=\"\(contentClass)\">\(definitionHTML)</span></li>"
        }.joined()
        return "<ul class=\"gloss-glossary-list\" data-count=\"\(self.count)\">\(itemsHTML)</ul>"
    }
}

private extension Definition {
    /// Check if this definition contains structured content
    var isStructuredContent: Bool {
        switch self {
        case .text:
            false
        case let .detailed(detail):
            switch detail {
            case .text:
                false
            case .structured, .image:
                true
            }
        case .deinflection:
            false
        }
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
    let preferredWidth: Int?
    let preferredHeight: Int?
    let title: String?
    let alt: String?
    let description: String?
    let pixelated: Bool?
    let imageRendering: String?
    let appearance: String?
    let background: Bool?
    let collapsed: Bool?
    let collapsible: Bool?
    let verticalAlign: String?
    let border: String?
    let borderRadius: String?
    let sizeUnits: String?
}

extension ImageDef {
    func toStructuredElement() -> StructuredElement {
        StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: path,
            width: width.map(Double.init),
            height: height.map(Double.init),
            preferredWidth: preferredWidth.map(Double.init),
            preferredHeight: preferredHeight.map(Double.init),
            title: title,
            alt: alt,
            pixelated: pixelated,
            imageRendering: imageRendering,
            appearance: appearance,
            background: background,
            collapsed: collapsed,
            collapsible: collapsible,
            verticalAlign: verticalAlign,
            border: border,
            borderRadius: borderRadius,
            sizeUnits: sizeUnits,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )
    }
}
