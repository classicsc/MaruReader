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
