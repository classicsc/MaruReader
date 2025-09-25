//
//  StructuredElement.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/15/25.
//

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

    private func createImageElement(baseURL: URL? = nil, devicePixelRatio: Double? = nil, emSize: Double? = nil) -> String {
        guard let path else { return "" }

        let width = self.width ?? 100
        let height = self.height ?? 100

        let hasPreferredWidth = preferredWidth != nil
        let hasPreferredHeight = preferredHeight != nil

        let invAspectRatio: Double = if hasPreferredWidth, hasPreferredHeight {
            preferredHeight! / preferredWidth!
        } else {
            height / width
        }

        let usedWidth: Double = if hasPreferredWidth {
            preferredWidth!
        } else if hasPreferredHeight {
            preferredHeight! / invAspectRatio
        } else {
            width
        }

        let resolvedPath = resolveImagePath(path: path, baseURL: baseURL)

        var attributes: [String] = [
            "class=\"gloss-image-link\"",
            "target=\"_blank\"",
            "rel=\"noreferrer noopener\"",
        ]

        if let resolvedPath {
            attributes.append("href=\"\(escapeHTMLAttribute(resolvedPath))\"")
        }

        attributes.append("data-path=\"\(escapeHTMLAttribute(path))\"")
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
            attributes.append("data-vertical-align=\"\(escapeHTMLAttribute(verticalAlign))\"")
        }

        if let sizeUnits, hasPreferredWidth || hasPreferredHeight {
            attributes.append("data-size-units=\"\(escapeHTMLAttribute(sizeUnits))\"")
        }

        let attributeString = attributes.joined(separator: " ")

        // Calculate width in em units - use precision similar to the old implementation
        let widthInEm: String
        if sizeUnits == "em" || (hasPreferredWidth || hasPreferredHeight) {
            widthInEm = "\(formatNumber(usedWidth))em"
        } else {
            // Convert px to em using provided base font size or default 14px
            let baseFontSize = emSize ?? 14.0
            let emWidth = usedWidth / baseFontSize
            widthInEm = "\(formatNumber(emWidth))em"
        }

        var containerAttributes: [String] = []

        if let border {
            containerAttributes.append("data-border=\"\(escapeHTMLAttribute(border))\"")
        }
        if let borderRadius {
            containerAttributes.append("data-border-radius=\"\(escapeHTMLAttribute(borderRadius))\"")
        }
        containerAttributes.append("data-width-em=\"\(widthInEm)\"")
        if let title {
            containerAttributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        let paddingTopValue = invAspectRatio * 100
        containerAttributes.append("data-aspect-ratio=\"\(formatNumber(paddingTopValue))\"")

        let containerAttributeString = containerAttributes.isEmpty ? "" : " " + containerAttributes.joined(separator: " ")

        var imageHTML = ""

        var imageAttributes = ["class=\"gloss-image\""]

        if let resolvedPath {
            imageAttributes.append("src=\"\(escapeHTMLAttribute(resolvedPath))\"")
        }

        imageAttributes.append("style=\"width: 100%; height: 100%\"")

        if sizeUnits == "em", hasPreferredWidth || hasPreferredHeight,
           let devicePixelRatio, let emSize
        {
            let scaleFactor = 2 * devicePixelRatio
            imageAttributes.append("width=\"\(Int(usedWidth * emSize * scaleFactor))\"")
            imageAttributes.append("height=\"\(Int(usedWidth * invAspectRatio * emSize * scaleFactor))\"")
        } else {
            imageAttributes.append("width=\"\(Int(usedWidth))\"")
            imageAttributes.append("height=\"\(Int(usedWidth * invAspectRatio))\"")
        }

        if let alt {
            imageAttributes.append("alt=\"\(escapeHTMLAttribute(alt))\"")
        }

        if let verticalAlign {
            imageAttributes.append("data-vertical-align=\"\(escapeHTMLAttribute(verticalAlign))\"")
        }

        // Image rendering handled via data-image-rendering attr already
        // Vertical align now in data-vertical-align attr

        imageHTML = "<img \(imageAttributes.joined(separator: " ")) />"

        return """
        <a \(attributeString)>
            <span class="gloss-image-container"\(containerAttributeString) style="width: \(widthInEm)">
                <span class="gloss-image-sizer" style="padding-top: \(formatNumber(paddingTopValue))%"></span>
                <span class="gloss-image-background"></span>
                \(imageHTML)
                <span class="gloss-image-container-overlay"></span>
            </span>
            <span class="gloss-image-link-text">Image</span>
        </a>
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

    private func createElementByType(baseURL: URL?, devicePixelRatio: Double?, emSize: Double?) -> String {
        let isSelfClosing = Self.selfClosingTags.contains(tag)

        var attributes: [String] = []

        // Add language attribute
        if let lang {
            attributes.append("lang=\"\(escapeHTMLAttribute(lang))\"")
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
                attributes.append("href=\"\(escapeHTMLAttribute(href))\"")
                attributes.append("data-external=\"\(isInternal ? "false" : "true")\"")
            }
        case "img":
            return createImageElement(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)
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
            attributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        // Add data attrs
        attributes.append(contentsOf: transformedDataAttrs(data: data))

        let attributeString = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")

        if isSelfClosing {
            return "<\(tag)\(attributeString) />"
        }

        let contentHTML = generateContentHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)

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

    func toHTML(baseURL: URL? = nil, devicePixelRatio: Double? = nil, emSize: Double? = nil) -> String {
        if tag == "img" {
            return createImageElement(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)
        }
        return createElementByType(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)
    }

    private func generateContentHTML(baseURL: URL?, devicePixelRatio: Double?, emSize: Double?) -> String {
        guard let content else { return "" }
        return content.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)
    }

    private func escapeHTMLAttribute(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&#39;")
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

    private func keyToCamelCase(_ key: String) -> String {
        let lowerKey = key.lowercased()
        let parts = lowerKey.components(separatedBy: "-").filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "" }
        let camelParts = parts.enumerated().map { index, part -> String in
            if index == 0 {
                return part
            } else {
                guard part.count > 0 else { return "" }
                return String(part.prefix(1)).uppercased() + part.dropFirst()
            }
        }
        let camel = camelParts.joined(separator: "")
        guard camel.count > 0 else { return "" }
        return String(camel.prefix(1)).uppercased() + camel.dropFirst()
    }

    private func transformedDataAttrs(data: [String: String]?) -> [String] {
        guard let data, !data.isEmpty else { return [] }
        var attrs: [String] = []
        for (key, value) in data {
            if key.isEmpty { continue }
            let camel = keyToCamelCase(key)
            if !camel.isEmpty {
                let scKey = "sc\(camel)"
                let attr = "data-\(scKey)=\"\(escapeHTMLAttribute(value))\""
                attrs.append(attr)
            }
        }
        return attrs
    }
}
