// StructuredElement.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

final class StructuredElement: Codable, Sendable {
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
    let preferredWidth: Double? // for 'img' tags
    let preferredHeight: Double? // for 'img' tags
    let title: String?
    let alt: String?
    let pixelated: Bool? // for 'img' tags
    let imageRendering: String? // for 'img' tags
    let appearance: String? // for 'img' tags
    let background: Bool? // for 'img' tags
    let collapsed: Bool? // for 'img' tags
    let collapsible: Bool? // for 'img' tags
    let verticalAlign: String? // for 'img' tags
    let border: String? // for 'img' tags
    let borderRadius: String? // for 'img' tags
    let sizeUnits: String? // for 'img' tags
    let colSpan: Int?
    let rowSpan: Int?
    let open: Bool? // for 'details' tags

    init(tag: String, content: StructuredContent?, data: [String: String]?, style: ContentStyle?, lang: String?, href: String?, path: String?, width: Double?, height: Double?, preferredWidth: Double? = nil, preferredHeight: Double? = nil, title: String?, alt: String?, pixelated: Bool? = nil, imageRendering: String? = nil, appearance: String? = nil, background: Bool? = nil, collapsed: Bool? = nil, collapsible: Bool? = nil, verticalAlign: String? = nil, border: String? = nil, borderRadius: String? = nil, sizeUnits: String? = nil, colSpan: Int?, rowSpan: Int?, open: Bool?) {
        self.tag = tag
        self.content = content
        self.data = data
        self.style = style
        self.lang = lang
        self.href = href
        self.path = path
        self.width = width
        self.height = height
        self.preferredWidth = preferredWidth
        self.preferredHeight = preferredHeight
        self.title = title
        self.alt = alt
        self.pixelated = pixelated
        self.imageRendering = imageRendering
        self.appearance = appearance
        self.background = background
        self.collapsed = collapsed
        self.collapsible = collapsible
        self.verticalAlign = verticalAlign
        self.border = border
        self.borderRadius = borderRadius
        self.sizeUnits = sizeUnits
        self.colSpan = colSpan
        self.rowSpan = rowSpan
        self.open = open
    }
}

// MARK: - HTML Generation

extension StructuredElement {
    private static let selfClosingTags: Set<String> = ["img", "br", "hr", "input", "meta", "link"]

    private func createImageElement(baseURL: URL? = nil, devicePixelRatio: Double? = nil, emSize: Double? = nil, insideAnchor: Bool = false) -> String {
        guard let path else { return "" }

        // Get original dimensions with defaults
        let originalWidth = self.width ?? 380.0
        let originalHeight = self.height ?? 380.0

        let hasPreferredWidth = preferredWidth != nil
        let hasPreferredHeight = preferredHeight != nil

        // Calculate effective dimensions based on preferences and original aspect ratio
        let effectiveWidth: Double
        let effectiveHeight: Double

        if hasPreferredWidth && hasPreferredHeight {
            // Both preferred dimensions specified - use them directly
            effectiveWidth = preferredWidth!
            effectiveHeight = preferredHeight!
        } else if hasPreferredWidth {
            // Only preferred width specified - calculate height maintaining original aspect ratio
            effectiveWidth = preferredWidth!
            let originalAspectRatio = originalHeight / originalWidth
            effectiveHeight = effectiveWidth * originalAspectRatio
        } else if hasPreferredHeight {
            // Only preferred height specified - calculate width maintaining original aspect ratio
            effectiveHeight = preferredHeight!
            let originalAspectRatio = originalHeight / originalWidth
            effectiveWidth = effectiveHeight / originalAspectRatio
        } else if sizeUnits == "em" {
            // For em units without preferred dimensions, handle missing dimensions
            let hasDirectWidth = width != nil
            let hasDirectHeight = height != nil

            if hasDirectWidth, hasDirectHeight {
                effectiveWidth = originalWidth
                effectiveHeight = originalHeight
            } else if hasDirectWidth {
                // Only width specified, assume square (1:1 aspect ratio)
                effectiveWidth = originalWidth
                effectiveHeight = originalWidth
            } else if hasDirectHeight {
                // Only height specified, assume square (1:1 aspect ratio)
                effectiveWidth = originalHeight
                effectiveHeight = originalHeight
            } else {
                // Neither specified, use 1em default
                effectiveWidth = 1.0
                effectiveHeight = 1.0
            }
        } else {
            // No preferences, use original dimensions
            effectiveWidth = originalWidth
            effectiveHeight = originalHeight
        }

        let invAspectRatio = effectiveHeight / effectiveWidth
        let usedWidth = effectiveWidth

        let resolvedPath = resolveImagePath(path: path, baseURL: baseURL)

        // When inside an anchor, use span to avoid invalid nested anchors
        let wrapperTag = insideAnchor ? "span" : "a"

        var attributes: [String] = [
            "class=\"gloss-image-link\"",
        ]

        if !insideAnchor {
            attributes.append("target=\"_blank\"")
            attributes.append("rel=\"noreferrer noopener\"")
        } else {
            // Make span behave like an interactive element
            attributes.append("role=\"button\"")
            attributes.append("tabindex=\"0\"")
        }

        if let resolvedPath {
            if insideAnchor {
                attributes.append("data-href=\"\(escapeHTML(resolvedPath))\"")
            } else {
                attributes.append("href=\"\(escapeHTML(resolvedPath))\"")
            }
        }

        attributes.append("data-path=\"\(escapeHTML(path))\"")
        let loadState = "not-loaded"
        attributes.append("data-image-load-state=\"\(loadState)\"")
        attributes.append("data-has-aspect-ratio=\"true\"")

        let imageRenderingValue = imageRendering ?? (pixelated == true ? "pixelated" : "auto")
        attributes.append("data-image-rendering=\"\(imageRenderingValue)\"")

        let appearanceValue = appearance ?? "auto"
        attributes.append("data-appearance=\"\(appearanceValue)\"")

        let backgroundValue = background ?? true
        attributes.append("data-background=\"\(backgroundValue)\"")

        let collapsedValue = collapsed ?? false
        attributes.append("data-collapsed=\"\(collapsedValue)\"")

        let collapsibleValue = collapsible ?? true
        attributes.append("data-collapsible=\"\(collapsibleValue)\"")

        if let verticalAlign {
            attributes.append("data-vertical-align=\"\(escapeHTML(verticalAlign))\"")
        }

        if let sizeUnits {
            attributes.append("data-size-units=\"\(escapeHTML(sizeUnits))\"")
        }

        let attributeString = attributes.joined(separator: " ")

        let widthValue = "\(formatNumber(usedWidth))em"

        var containerAttributes: [String] = []

        if let border {
            containerAttributes.append("data-border=\"\(escapeHTML(border))\"")
        }
        if let borderRadius {
            containerAttributes.append("data-border-radius=\"\(escapeHTML(borderRadius))\"")
        }
        containerAttributes.append("data-width=\"\(widthValue)\"")
        if let title {
            containerAttributes.append("title=\"\(escapeHTML(title))\"")
        }

        let paddingTopValue = invAspectRatio * 100
        containerAttributes.append("data-aspect-ratio=\"\(formatNumber(paddingTopValue))\"")

        let containerAttributeString = containerAttributes.isEmpty ? "" : " " + containerAttributes.joined(separator: " ")

        var imageHTML = ""

        var imageAttributes = ["class=\"gloss-image\""]

        if let resolvedPath {
            imageAttributes.append("src=\"\(escapeHTML(resolvedPath))\"")
        }

        imageAttributes.append("style=\"width: 100%; height: 100%\"")

        if sizeUnits == "em", let devicePixelRatio, let emSize {
            let scaleFactor = 2 * devicePixelRatio
            imageAttributes.append("width=\"\(Int(effectiveWidth * emSize * scaleFactor))\"")
            imageAttributes.append("height=\"\(Int(effectiveHeight * emSize * scaleFactor))\"")
        } else if hasPreferredWidth || hasPreferredHeight, let devicePixelRatio, let emSize {
            let scaleFactor = 2 * devicePixelRatio
            imageAttributes.append("width=\"\(Int(effectiveWidth * emSize * scaleFactor))\"")
            imageAttributes.append("height=\"\(Int(effectiveHeight * emSize * scaleFactor))\"")
        } else {
            imageAttributes.append("width=\"\(Int(effectiveWidth))\"")
            imageAttributes.append("height=\"\(Int(effectiveHeight))\"")
        }

        if let alt {
            imageAttributes.append("alt=\"\(escapeHTML(alt))\"")
        }

        if let verticalAlign {
            imageAttributes.append("data-vertical-align=\"\(escapeHTML(verticalAlign))\"")
        }

        // Image rendering handled via data-image-rendering attr already
        // Vertical align now in data-vertical-align attr

        imageHTML = "<img \(imageAttributes.joined(separator: " ")) />"

        return """
        <\(wrapperTag) \(attributeString)>
            <span class="gloss-image-container"\(containerAttributeString) style="width: \(widthValue)">
                <span class="gloss-image-sizer" style="padding-top: \(formatNumber(paddingTopValue))%"></span>
                <span class="gloss-image-background"></span>
                \(imageHTML)
                <span class="gloss-image-container-overlay"></span>
            </span>
            <span class="gloss-image-link-text">\(FrameworkLocalization.string("dictionary.image.link", defaultValue: "Image"))</span>
        </\(wrapperTag)>
        """
    }

    private func resolveImagePath(path: String, baseURL: URL?) -> String? {
        if let url = URL(string: path), url.scheme == nil {
            if let baseURL {
                return baseURL.appendingPathComponent(path).absoluteString
            } else {
                return path
            }
        }
        return nil
    }

    private func createElementByType(baseURL: URL?, devicePixelRatio: Double?, emSize: Double?, insideAnchor: Bool = false) -> String {
        let isSelfClosing = Self.selfClosingTags.contains(tag)

        var attributes: [String] = []

        // Add language attribute
        if let lang {
            attributes.append("lang=\"\(escapeHTML(lang))\"")
        }

        // Add base class with style classes
        let baseClass = if tag == "a" {
            "gloss-link"
        } else {
            "gloss-sc-\(tag)"
        }
        let extraClasses = style?.toCSSClasses().joined(separator: " ") ?? ""
        let fullClass = [baseClass, extraClasses].filter { !$0.isEmpty }.joined(separator: " ")
        attributes.append("class=\"\(fullClass)\"")

        // Add inline styles if present
        if let style, !style.toCSSString().isEmpty {
            attributes.append("style=\"\(escapeHTML(style.toCSSString()))\"")
        }

        // Track if we're entering an anchor element
        let isAnchorElement = tag == "a"
        let childInsideAnchor = insideAnchor || isAnchorElement

        // Specialized handling
        switch tag {
        case "table":
            // Will wrap later
            fallthrough
        case "br", "ruby", "rt", "rp", "div", "span", "ol", "ul", "li", "summary", "thead", "tbody", "tfoot", "tr":
            // Simple/styled elements: base class applied
            break
        case "th", "td":
            if let colSpan, colSpan > 1 {
                attributes.append("colspan=\"\(colSpan)\"")
            }
            if let rowSpan, rowSpan > 1 {
                attributes.append("rowspan=\"\(rowSpan)\"")
            }
        case "a":
            if let href {
                let isInternal = href.hasPrefix("?")
                attributes.append("href=\"\(escapeHTML(href))\"")
                attributes.append("data-external=\"\(isInternal ? "false" : "true")\"")
            }
        case "img":
            return createImageElement(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize, insideAnchor: insideAnchor)
        case "details":
            if let open, open {
                attributes.append("open")
            }
        default:
            // Generic handling
            break
        }

        // Add title
        if let title {
            attributes.append("title=\"\(escapeHTML(title))\"")
        }

        // Add data attrs
        attributes.append(contentsOf: transformedDataAttrs(data: data))

        let attributeString = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")

        if isSelfClosing {
            return "<\(tag)\(attributeString) />"
        }

        let contentHTML = generateContentHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize, insideAnchor: childInsideAnchor)

        let fullContent: String
        if tag == "a" {
            let textSpan = "<span class=\"gloss-link-text\">\(contentHTML)</span>"
            if let href, !href.hasPrefix("?") {
                fullContent = "\(textSpan)<span class=\"gloss-link-external-icon icon\" data-icon=\"external-link\"></span>"
            } else {
                fullContent = textSpan
            }
        } else {
            fullContent = contentHTML
        }

        let elementHTML = "<\(tag)\(attributeString)>\(fullContent)</\(tag)>"

        if tag == "table" {
            return "<div class=\"gloss-sc-table-container\">\(elementHTML)</div>"
        } else {
            return elementHTML
        }
    }

    func toHTML(baseURL: URL? = nil, devicePixelRatio: Double? = nil, emSize: Double? = nil, insideAnchor: Bool = false) -> String {
        if tag == "img" {
            return createImageElement(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize, insideAnchor: insideAnchor)
        }
        return createElementByType(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize, insideAnchor: insideAnchor)
    }

    /// Generate Anki-compatible HTML with CSS classes for styling via embedded stylesheets.
    /// Uses the same class structure as Yomitan for compatibility with existing Anki card templates.
    /// Images use Anki's flat filename structure for media files.
    func toAnkiHTML(mediaBaseURL: URL? = nil) -> String {
        if tag == "img" {
            return createAnkiImageElement(mediaBaseURL: mediaBaseURL)
        }
        return createAnkiElementByType(mediaBaseURL: mediaBaseURL)
    }

    private func createAnkiImageElement(mediaBaseURL _: URL? = nil) -> String {
        guard let path else { return "" }

        // For Anki, use just the filename since Anki stores media files flat.
        // The actual file will be uploaded separately via the picture/audio/video arrays.
        let filename = (path as NSString).lastPathComponent

        // Get original dimensions with defaults
        let originalWidth = self.width ?? 380.0
        let originalHeight = self.height ?? 380.0

        let hasPreferredWidth = preferredWidth != nil
        let hasPreferredHeight = preferredHeight != nil

        // Calculate effective dimensions based on preferences and original aspect ratio
        let effectiveWidth: Double
        let effectiveHeight: Double

        if hasPreferredWidth, hasPreferredHeight {
            effectiveWidth = preferredWidth!
            effectiveHeight = preferredHeight!
        } else if hasPreferredWidth {
            effectiveWidth = preferredWidth!
            let originalAspectRatio = originalHeight / originalWidth
            effectiveHeight = effectiveWidth * originalAspectRatio
        } else if hasPreferredHeight {
            effectiveHeight = preferredHeight!
            let originalAspectRatio = originalHeight / originalWidth
            effectiveWidth = effectiveHeight / originalAspectRatio
        } else if sizeUnits == "em" {
            let hasDirectWidth = width != nil
            let hasDirectHeight = height != nil

            if hasDirectWidth, hasDirectHeight {
                effectiveWidth = originalWidth
                effectiveHeight = originalHeight
            } else if hasDirectWidth {
                effectiveWidth = originalWidth
                effectiveHeight = originalWidth
            } else if hasDirectHeight {
                effectiveWidth = originalHeight
                effectiveHeight = originalHeight
            } else {
                effectiveWidth = 1.0
                effectiveHeight = 1.0
            }
        } else {
            effectiveWidth = originalWidth
            effectiveHeight = originalHeight
        }

        let invAspectRatio = effectiveHeight / effectiveWidth
        let usedWidth = effectiveWidth

        // Build link attributes with data attributes for CSS targeting
        var linkAttributes: [String] = [
            "class=\"gloss-image-link\"",
        ]

        linkAttributes.append("data-path=\"\(escapeHTML(path))\"")
        linkAttributes.append("data-has-aspect-ratio=\"true\"")

        let imageRenderingValue = imageRendering ?? (pixelated == true ? "pixelated" : "auto")
        linkAttributes.append("data-image-rendering=\"\(imageRenderingValue)\"")

        let appearanceValue = appearance ?? "auto"
        linkAttributes.append("data-appearance=\"\(appearanceValue)\"")

        let backgroundValue = background ?? true
        linkAttributes.append("data-background=\"\(backgroundValue)\"")

        let collapsedValue = collapsed ?? false
        linkAttributes.append("data-collapsed=\"\(collapsedValue)\"")

        if let verticalAlign {
            linkAttributes.append("data-vertical-align=\"\(escapeHTML(verticalAlign))\"")
        }

        if let sizeUnits {
            linkAttributes.append("data-size-units=\"\(escapeHTML(sizeUnits))\"")
        }

        // Container attributes
        var containerAttributes = ["class=\"gloss-image-container\""]

        if let border {
            containerAttributes.append("data-border=\"\(escapeHTML(border))\"")
        }
        if let borderRadius {
            containerAttributes.append("data-border-radius=\"\(escapeHTML(borderRadius))\"")
        }
        if let title {
            containerAttributes.append("title=\"\(escapeHTML(title))\"")
        }

        // Container inline style for width
        let widthValue = "\(formatNumber(usedWidth))em"
        containerAttributes.append("style=\"width: \(widthValue)\"")

        // Aspect ratio for sizer
        let paddingTopValue = invAspectRatio * 100

        // Build image element
        var imageAttributes = [
            "class=\"gloss-image\"",
            "src=\"\(escapeHTML(filename))\"",
            "style=\"width: 100%; height: 100%\"",
        ]

        if sizeUnits == "em" {
            imageAttributes.append("width=\"\(Int(effectiveWidth * 16 * 2))\"")
            imageAttributes.append("height=\"\(Int(effectiveHeight * 16 * 2))\"")
        } else {
            imageAttributes.append("width=\"\(Int(effectiveWidth))\"")
            imageAttributes.append("height=\"\(Int(effectiveHeight))\"")
        }

        if let alt {
            imageAttributes.append("alt=\"\(escapeHTML(alt))\"")
        }

        if let verticalAlign {
            imageAttributes.append("data-vertical-align=\"\(escapeHTML(verticalAlign))\"")
        }

        let linkAttrString = linkAttributes.joined(separator: " ")
        let containerAttrString = containerAttributes.joined(separator: " ")
        let imageAttrString = imageAttributes.joined(separator: " ")

        return """
        <a \(linkAttrString)>\
        <span \(containerAttrString)>\
        <span class="gloss-image-sizer" style="padding-top: \(formatNumber(paddingTopValue))%"></span>\
        <span class="gloss-image-background"></span>\
        <img \(imageAttrString)>\
        <span class="gloss-image-container-overlay"></span>\
        </span>\
        <span class="gloss-image-link-text">\(FrameworkLocalization.string("dictionary.image.link", defaultValue: "Image"))</span>\
        </a>
        """
    }

    private func createAnkiElementByType(mediaBaseURL: URL?) -> String {
        let isSelfClosing = Self.selfClosingTags.contains(tag)

        var attributes: [String] = []

        // Add language attribute
        if let lang {
            attributes.append("lang=\"\(escapeHTML(lang))\"")
        }

        // Add base class with style classes (same as toHTML)
        let baseClass = if tag == "a" {
            "gloss-link"
        } else {
            "gloss-sc-\(tag)"
        }
        let extraClasses = style?.toCSSClasses().joined(separator: " ") ?? ""
        let fullClass = [baseClass, extraClasses].filter { !$0.isEmpty }.joined(separator: " ")
        attributes.append("class=\"\(fullClass)\"")

        // Add inline styles from ContentStyle if present (for custom colors, margins, etc.)
        if let style, !style.toCSSString().isEmpty {
            attributes.append("style=\"\(escapeHTML(style.toCSSString()))\"")
        }

        // Specialized handling
        switch tag {
        case "br":
            return "<br>"
        case "ruby", "rt", "rp", "div", "span", "ol", "ul", "li", "summary", "thead", "tbody", "tfoot", "tr":
            // Simple elements: base class applied above
            break
        case "table":
            // Will wrap in container below
            break
        case "th", "td":
            if let colSpan, colSpan > 1 {
                attributes.append("colspan=\"\(colSpan)\"")
            }
            if let rowSpan, rowSpan > 1 {
                attributes.append("rowspan=\"\(rowSpan)\"")
            }
        case "a":
            // Keep href for Anki (external links can still work)
            if let href {
                let isInternal = href.hasPrefix("?")
                if !isInternal {
                    attributes.append("href=\"\(escapeHTML(href))\"")
                }
                attributes.append("data-external=\"\(isInternal ? "false" : "true")\"")
            }
        case "details":
            if let open, open {
                attributes.append("open")
            }
        case "img":
            return createAnkiImageElement(mediaBaseURL: mediaBaseURL)
        default:
            break
        }

        if let title {
            attributes.append("title=\"\(escapeHTML(title))\"")
        }

        // Add data attributes (important for Lapis/Yomitan compatibility)
        attributes.append(contentsOf: transformedDataAttrs(data: data))

        let attributeString = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")

        if isSelfClosing {
            return "<\(tag)\(attributeString)>"
        }

        let contentHTML = content?.toAnkiHTML(mediaBaseURL: mediaBaseURL) ?? ""

        // For 'details' tag in Anki, render content without the wrapper (Anki may not support <details>)
        if tag == "details" {
            return contentHTML
        }

        let elementHTML = "<\(tag)\(attributeString)>\(contentHTML)</\(tag)>"

        // Wrap tables in a container for overflow handling
        if tag == "table" {
            return "<div class=\"gloss-sc-table-container\">\(elementHTML)</div>"
        }

        return elementHTML
    }

    private func generateContentHTML(baseURL: URL?, devicePixelRatio: Double?, emSize: Double?, insideAnchor: Bool = false) -> String {
        guard let content else { return "" }
        return content.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize, insideAnchor: insideAnchor)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = .halfEven
        let string = formatter.string(from: NSNumber(value: value)) ?? "0"
        // Trim trailing zeros after decimal if present
        if let decimalIndex = string.firstIndex(where: { $0 == "." }) {
            let integerPart = String(string[..<decimalIndex])
            let decimalPart = String(string[string.index(after: decimalIndex)...])
            let trimmedDecimal = decimalPart.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmedDecimal.isEmpty {
                return integerPart
            } else {
                return integerPart + "." + trimmedDecimal
            }
        }
        return string
    }

    private func dataAttributeName(for key: String) -> String? {
        guard !key.isEmpty else { return nil }
        let normalizedKey = key.prefix(1).uppercased() + key.dropFirst()
        let scKey = "sc\(normalizedKey)"
        var kebab = ""
        for character in scKey {
            if character.isUppercase {
                if !kebab.isEmpty {
                    kebab.append("-")
                }
                kebab.append(character.lowercased())
            } else {
                kebab.append(character)
            }
        }
        return "data-\(kebab)"
    }

    private func transformedDataAttrs(data: [String: String]?) -> [String] {
        guard let data, !data.isEmpty else { return [] }
        var attrs: [String] = []
        for (key, value) in data {
            guard let attributeName = dataAttributeName(for: key) else { continue }
            let attr = "\(attributeName)=\"\(escapeHTML(value))\""
            attrs.append(attr)
        }
        return attrs
    }

    /// Extracts all image paths from this element and its children.
    func extractImagePaths() -> [String] {
        var paths: [String] = []

        if tag == "img", let path {
            paths.append(path)
        }

        if let content {
            paths.append(contentsOf: content.extractImagePaths())
        }

        return paths
    }
}
