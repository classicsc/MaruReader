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

    private func createImageElement(baseURL: URL? = nil, devicePixelRatio: Double = 2.0, emSize: Double = 14.0) -> String {
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

        var attributes: [String] = [
            "class=\"gloss-image-link\"",
            "target=\"_blank\"",
            "rel=\"noreferrer noopener\"",
        ]

        if let resolvedPath = resolveImagePath(path: path, baseURL: baseURL) {
            attributes.append("href=\"\(escapeHTMLAttribute(resolvedPath))\"")
        }

        attributes.append("data-path=\"\(escapeHTMLAttribute(path))\"")
        attributes.append("data-image-load-state=\"loaded\"")
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

        var containerStyle = ["width: \(usedWidth)em"]
        var containerAttributes: [String] = []

        if let border {
            containerStyle.append("border: \(border)")
        }
        if let borderRadius {
            containerStyle.append("border-radius: \(borderRadius)")
        }
        if let title {
            containerAttributes.append("title=\"\(escapeHTMLAttribute(title))\"")
        }

        let containerStyleString = containerStyle.joined(separator: "; ")
        let containerAttributeString = containerAttributes.isEmpty ? "" : " " + containerAttributes.joined(separator: " ")

        let sizerStyle = "padding-top: \(invAspectRatio * 100)%"

        var imageHTML = ""
        if let resolvedPath = resolveImagePath(path: path, baseURL: baseURL) {
            var imageAttributes: [String] = [
                "class=\"gloss-image\"",
                "src=\"\(escapeHTMLAttribute(resolvedPath))\"",
                "style=\"width: 100%; height: 100%\"",
            ]

            if sizeUnits == "em", hasPreferredWidth || hasPreferredHeight {
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

            imageHTML = "<img \(imageAttributes.joined(separator: " ")) />"
        }

        let descriptionHTML = title.map { "<span class=\"gloss-image-description\">\(escapeHTMLAttribute($0))</span>" } ?? ""

        return """
        <a \(attributeString)>
            <span class="gloss-image-container" style="\(containerStyleString)"\(containerAttributeString)>
                <span class="gloss-image-sizer" style="\(sizerStyle)"></span>
                <span class="gloss-image-background"></span>
                \(imageHTML)
                <span class="gloss-image-container-overlay"></span>
            </span>
            <span class="gloss-image-link-text">Image</span>
            \(descriptionHTML)
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
            return createImageElement(baseURL: baseURL)
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
