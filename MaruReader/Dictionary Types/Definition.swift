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
                return imageHTML(from: imageDef, baseURL: baseURL, devicePixelRatio: devicePixelRatio, baseFontSize: baseFontSize)
            }
        case let .deinflection(uninflected, rules):
            let escapedUninflected = escapeHTML(uninflected)
            let escapedRules = rules.map { escapeHTML($0) }.joined(separator: ", ")
            return "<p class=\"deinflection\">Uninflected: \(escapedUninflected) (Rules: \(escapedRules))</p>"
        }
    }

    private func wrapDefinitionText(_ text: String) -> String {
        let escapedText = escapeHTML(text).replacingOccurrences(of: "\n", with: "<br>")
        return "<p class=\"definition-text\">\(escapedText)</p>"
    }

    private func imageHTML(from image: ImageDef, baseURL: URL?, devicePixelRatio: CGFloat?, baseFontSize: CGFloat?) -> String {
        let (containerWidth, containerHeight) = calculateContainerDimensions(from: image)
        let (finalWidth, finalHeight) = calculateImageDimensions(from: image, devicePixelRatio: devicePixelRatio, baseFontSize: baseFontSize)
        let aspectRatioPadding = percentagePadding(forHeight: containerHeight, width: containerWidth)
        let resolvedSource = resolveImageSource(path: image.path, baseURL: baseURL)

        let linkAttributes = buildLinkAttributes(for: image)
        let containerAttributes = buildContainerAttributes(for: image, finalWidth: containerWidth, baseFontSize: baseFontSize ?? 14.0)
        let imageAttributes = buildImageAttributes(
            for: image,
            resolvedSource: resolvedSource,
            finalWidth: finalWidth,
            finalHeight: finalHeight
        )

        var html = "<a \(linkAttributes)>"
        html += "<span \(containerAttributes)>"
        html += "<span class=\"gloss-image-sizer\" style=\"padding-top: \(aspectRatioPadding)%\"></span>"
        html += "<span class=\"gloss-image-background\"></span>"
        html += "<span class=\"gloss-image-container-overlay\"></span>"
        html += "<img \(imageAttributes) />"
        html += "</span>"
        html += "<span class=\"gloss-image-link-text\">Image</span>"
        html += "</a>"

        if let description = image.description {
            html += " <span class=\"gloss-image-description\">\(escapeHTML(description))</span>"
        }

        return html
    }

    private func calculateContainerDimensions(from image: ImageDef) -> (width: Int, height: Int) {
        // Get base dimensions, fallback to 100x100 if not provided
        let baseWidth = image.width ?? 100
        let baseHeight = image.height ?? 100

        // Check if we have preferred dimensions for responsive sizing
        let hasPreferredWidth = image.preferredWidth != nil
        let hasPreferredHeight = image.preferredHeight != nil

        // Calculate aspect ratio (height/width for inverse aspect ratio like Yomitan)
        let invAspectRatio = if hasPreferredWidth, hasPreferredHeight {
            Double(image.preferredHeight!) / Double(image.preferredWidth!)
        } else {
            Double(baseHeight) / Double(baseWidth)
        }

        // Calculate final width based on preferences
        let finalWidth: Int = if let preferredWidth = image.preferredWidth {
            preferredWidth
        } else if let preferredHeight = image.preferredHeight {
            Int(Double(preferredHeight) / invAspectRatio)
        } else {
            baseWidth
        }

        // Calculate final height maintaining aspect ratio
        let finalHeight = Int(Double(finalWidth) * invAspectRatio)

        return (width: finalWidth, height: finalHeight)
    }

    private func calculateImageDimensions(from image: ImageDef, devicePixelRatio: CGFloat?, baseFontSize: CGFloat?) -> (width: Int, height: Int) {
        // Start with container dimensions
        let (containerWidth, containerHeight) = calculateContainerDimensions(from: image)

        // Check if we have preferred dimensions for responsive sizing
        let hasPreferredWidth = image.preferredWidth != nil
        let hasPreferredHeight = image.preferredHeight != nil

        // Apply device pixel ratio scaling for EM units (matching Yomitan behavior)
        // Only when both devicePixelRatio and baseFontSize are explicitly provided
        if let devicePixelRatio, let baseFontSize,
           image.sizeUnits == "em", hasPreferredWidth || hasPreferredHeight
        {
            let scaleFactor = 2.0 * devicePixelRatio
            let scaledWidth = Int(Double(containerWidth) * Double(baseFontSize) * scaleFactor)
            let scaledHeight = Int(Double(containerHeight) * Double(baseFontSize) * scaleFactor)
            return (width: scaledWidth, height: scaledHeight)
        }

        return (width: containerWidth, height: containerHeight)
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

    private func buildLinkAttributes(for image: ImageDef) -> String {
        var attributes: [String] = [
            "class=\"gloss-image-link\"",
            "target=\"_blank\"",
            "rel=\"noreferrer noopener\"",
            "data-path=\"\(escapeHTMLAttribute(image.path))\"",
            "data-image-load-state=\"not-loaded\"",
            "data-has-aspect-ratio=\"true\"",
            "data-image-rendering=\"\(escapeHTMLAttribute(image.imageRendering ?? (image.pixelated == true ? "pixelated" : "auto")))\"",
            "data-appearance=\"\(escapeHTMLAttribute(image.appearance ?? "auto"))\"",
            "data-background=\"\(escapeHTMLAttribute(String(image.background ?? true)))\"",
            "data-collapsed=\"\(escapeHTMLAttribute(String(image.collapsed ?? false)))\"",
            "data-collapsible=\"\(escapeHTMLAttribute(String(image.collapsible ?? true)))\"",
        ]

        if let verticalAlign = image.verticalAlign {
            attributes.append("data-vertical-align=\"\(escapeHTMLAttribute(verticalAlign))\"")
        }

        if let sizeUnits = image.sizeUnits, image.preferredWidth != nil || image.preferredHeight != nil {
            attributes.append("data-size-units=\"\(escapeHTMLAttribute(sizeUnits))\"")
        }

        return attributes.joined(separator: " ")
    }

    private func buildContainerAttributes(for image: ImageDef, finalWidth: Int, baseFontSize: CGFloat) -> String {
        var attributes = ["class=\"gloss-image-container\""]

        if let title = image.title {
            attributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        if let style = imageContainerStyle(from: image, finalWidth: finalWidth, baseFontSize: baseFontSize) {
            attributes.append("style=\"\(escapeHTMLAttribute(style))\"")
        }

        return attributes.joined(separator: " ")
    }

    private func buildImageAttributes(for image: ImageDef, resolvedSource: String?, finalWidth: Int, finalHeight: Int) -> String {
        var attributes = ["class=\"gloss-image\""]

        if let resolvedSource {
            attributes.append("src=\"\(escapeHTMLAttribute(resolvedSource))\"")
        }

        attributes.append("width=\"\(finalWidth)\"")
        attributes.append("height=\"\(finalHeight)\"")

        if let alt = image.alt {
            attributes.append("alt=\"\(escapeHTMLAttribute(alt))\"")
        }

        if let style = imageNodeStyle(from: image) {
            attributes.append("style=\"\(escapeHTMLAttribute(style))\"")
        }

        return attributes.joined(separator: " ")
    }

    private func imageNodeStyle(from image: ImageDef) -> String? {
        var styleComponents: [String] = []

        if let imageRendering = image.imageRendering {
            if imageRendering != "auto" {
                styleComponents.append("image-rendering: \(imageRendering)")
            }
        } else if image.pixelated == true {
            styleComponents.append("image-rendering: pixelated")
        }

        if let verticalAlign = image.verticalAlign {
            styleComponents.append("vertical-align: \(verticalAlign)")
        }

        return styleComponents.isEmpty ? nil : styleComponents.joined(separator: "; ")
    }

    private func imageContainerStyle(from image: ImageDef, finalWidth: Int, baseFontSize: CGFloat) -> String? {
        var styleComponents: [String] = []

        if let border = image.border {
            styleComponents.append("border: \(border)")
        }

        if let borderRadius = image.borderRadius {
            styleComponents.append("border-radius: \(borderRadius)")
        }

        styleComponents.append(containerWidthStyle(from: image, finalWidth: finalWidth, baseFontSize: baseFontSize))

        return styleComponents.joined(separator: "; ")
    }

    private func containerWidthStyle(from image: ImageDef, finalWidth: Int, baseFontSize: CGFloat) -> String {
        // Always use EM units for consistency with Yomitan (matching line 145 in structured-content-generator.js)
        if image.sizeUnits == "em" || (image.preferredWidth != nil || image.preferredHeight != nil) {
            return "width: \(finalWidth)em"
        }

        // Convert px to em using dynamic calculation for legacy support
        let emWidth = Double(finalWidth) / Double(baseFontSize)
        return "width: \(formatNumber(emWidth))em"
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func percentagePadding(forHeight height: Int, width: Int) -> String {
        let width = max(width, 1)
        let value = Double(height) * 100.0 / Double(width)
        guard value.isFinite else { return "0" }

        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = false

        return formatter.string(from: NSNumber(value: value)) ?? "0"
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
        let itemsHTML = self.map { "<li>\($0.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, baseFontSize: baseFontSize))</li>" }.joined()
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
