//
//  StructuredContent.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/15/25.
//

import Foundation

/// Recursive structured content type
enum StructuredContent: Codable, Sendable {
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

// MARK: - HTML Conversion

extension StructuredContent {
    func toHTML(baseURL: URL? = nil, devicePixelRatio: Double? = nil, emSize: Double? = nil) -> String {
        switch self {
        case let .text(string):
            escapeHTML(string)
        case let .array(contents):
            contents.map { $0.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize) }.joined()
        case let .element(element):
            element.toHTML(baseURL: baseURL, devicePixelRatio: devicePixelRatio, emSize: emSize)
        }
    }

    /// Generate Anki-compatible HTML with inline styles (no CSS class dependencies).
    func toAnkiHTML(mediaBaseURL: URL? = nil) -> String {
        switch self {
        case let .text(string):
            escapeAnkiHTML(string)
        case let .array(contents):
            contents.map { $0.toAnkiHTML(mediaBaseURL: mediaBaseURL) }.joined()
        case let .element(element):
            element.toAnkiHTML(mediaBaseURL: mediaBaseURL)
        }
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\n", with: "<br class=\"gloss-sc-br\">")
    }

    private func escapeAnkiHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    /// Extracts all image paths from this structured content.
    func extractImagePaths() -> [String] {
        switch self {
        case .text:
            []
        case let .array(contents):
            contents.flatMap { $0.extractImagePaths() }
        case let .element(element):
            element.extractImagePaths()
        }
    }
}
