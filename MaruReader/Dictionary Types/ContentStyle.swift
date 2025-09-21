//
//  ContentStyle.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
import SwiftUI

struct ContentStyle: Codable, Sendable {
    let fontStyle: String?
    let fontWeight: String?
    let fontSize: String?
    let color: String?
    let backgroundColor: String?
    let background: String?
    let textDecorationLine: [String]?
    let textDecorationStyle: String?
    let textDecorationColor: String?
    let listStyleType: String?
    let textAlign: String?
    let verticalAlign: String?
    let margin: String?
    let padding: String?
    let borderColor: String?
    let borderStyle: String?
    let borderRadius: String?
    let borderWidth: String?
    let textEmphasis: String?
    let textShadow: String?
    let whiteSpace: String?
    let wordBreak: String?

    init(
        fontStyle: String? = nil,
        fontWeight: String? = nil,
        fontSize: String? = nil,
        color: String? = nil,
        backgroundColor: String? = nil,
        background: String? = nil,
        textDecorationLine: [String]? = nil,
        textDecorationStyle: String? = nil,
        textDecorationColor: String? = nil,
        listStyleType: String? = nil,
        textAlign: String? = nil,
        verticalAlign: String? = nil,
        margin: String? = nil,
        padding: String? = nil,
        borderColor: String? = nil,
        borderStyle: String? = nil,
        borderRadius: String? = nil,
        borderWidth: String? = nil,
        textEmphasis: String? = nil,
        textShadow: String? = nil,
        whiteSpace: String? = nil,
        wordBreak: String? = nil
    ) {
        self.fontStyle = fontStyle
        self.fontWeight = fontWeight
        self.fontSize = fontSize
        self.color = color
        self.backgroundColor = backgroundColor
        self.background = background
        self.textDecorationLine = textDecorationLine
        self.textDecorationStyle = textDecorationStyle
        self.textDecorationColor = textDecorationColor
        self.listStyleType = listStyleType
        self.textAlign = textAlign
        self.verticalAlign = verticalAlign
        self.margin = margin
        self.padding = padding
        self.borderColor = borderColor
        self.borderStyle = borderStyle
        self.borderRadius = borderRadius
        self.borderWidth = borderWidth
        self.textEmphasis = textEmphasis
        self.textShadow = textShadow
        self.whiteSpace = whiteSpace
        self.wordBreak = wordBreak
    }

    // Custom decoding to handle textDecorationLine as String or [String]
    enum CodingKeys: String, CodingKey {
        case fontStyle
        case fontWeight
        case fontSize
        case color
        case backgroundColor
        case background
        case textDecorationLine
        case textDecorationStyle
        case textDecorationColor
        case listStyleType
        case textAlign
        case verticalAlign
        case margin
        case padding
        case borderColor
        case borderStyle
        case borderRadius
        case borderWidth
        case textEmphasis
        case textShadow
        case whiteSpace
        case wordBreak
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fontStyle = try container.decodeIfPresent(String.self, forKey: .fontStyle)
        fontWeight = try container.decodeIfPresent(String.self, forKey: .fontWeight)
        fontSize = try container.decodeIfPresent(String.self, forKey: .fontSize)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        background = try container.decodeIfPresent(String.self, forKey: .background)

        // Handle textDecorationLine as either String or [String]
        if let singleDecoration = try? container.decode(String.self, forKey: .textDecorationLine) {
            textDecorationLine = [singleDecoration]
        } else if let multipleDecorations = try? container.decode([String].self, forKey: .textDecorationLine) {
            textDecorationLine = multipleDecorations
        } else {
            textDecorationLine = nil
        }

        textDecorationStyle = try container.decodeIfPresent(String.self, forKey: .textDecorationStyle)
        textDecorationColor = try container.decodeIfPresent(String.self, forKey: .textDecorationColor)
        listStyleType = try container.decodeIfPresent(String.self, forKey: .listStyleType)
        textAlign = try container.decodeIfPresent(String.self, forKey: .textAlign)
        verticalAlign = try container.decodeIfPresent(String.self, forKey: .verticalAlign)
        margin = try container.decodeIfPresent(String.self, forKey: .margin)
        padding = try container.decodeIfPresent(String.self, forKey: .padding)
        borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        borderStyle = try container.decodeIfPresent(String.self, forKey: .borderStyle)
        borderRadius = try container.decodeIfPresent(String.self, forKey: .borderRadius)
        borderWidth = try container.decodeIfPresent(String.self, forKey: .borderWidth)
        textEmphasis = try container.decodeIfPresent(String.self, forKey: .textEmphasis)
        textShadow = try container.decodeIfPresent(String.self, forKey: .textShadow)
        whiteSpace = try container.decodeIfPresent(String.self, forKey: .whiteSpace)
        wordBreak = try container.decodeIfPresent(String.self, forKey: .wordBreak)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(fontStyle, forKey: .fontStyle)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encodeIfPresent(textDecorationLine, forKey: .textDecorationLine)
        try container.encodeIfPresent(textDecorationStyle, forKey: .textDecorationStyle)
        try container.encodeIfPresent(textDecorationColor, forKey: .textDecorationColor)
        try container.encodeIfPresent(listStyleType, forKey: .listStyleType)
        try container.encodeIfPresent(textAlign, forKey: .textAlign)
        try container.encodeIfPresent(verticalAlign, forKey: .verticalAlign)
        try container.encodeIfPresent(margin, forKey: .margin)
        try container.encodeIfPresent(padding, forKey: .padding)
        try container.encodeIfPresent(borderColor, forKey: .borderColor)
        try container.encodeIfPresent(borderStyle, forKey: .borderStyle)
        try container.encodeIfPresent(borderRadius, forKey: .borderRadius)
        try container.encodeIfPresent(borderWidth, forKey: .borderWidth)
        try container.encodeIfPresent(textEmphasis, forKey: .textEmphasis)
        try container.encodeIfPresent(textShadow, forKey: .textShadow)
        try container.encodeIfPresent(whiteSpace, forKey: .whiteSpace)
        try container.encodeIfPresent(wordBreak, forKey: .wordBreak)
    }

    func toCSSString() -> String {
        var cssProperties: [String] = []

        if let fontStyle {
            cssProperties.append("font-style: \(fontStyle)")
        }
        if let fontWeight {
            cssProperties.append("font-weight: \(fontWeight)")
        }
        if let fontSize {
            cssProperties.append("font-size: \(fontSize)")
        }
        if let color {
            cssProperties.append("color: \(color)")
        }
        if let backgroundColor {
            cssProperties.append("background-color: \(backgroundColor)")
        }
        if let background {
            cssProperties.append("background: \(background)")
        }
        if let textDecorationLine, !textDecorationLine.isEmpty {
            cssProperties.append("text-decoration-line: \(textDecorationLine.joined(separator: " "))")
        }
        if let textDecorationStyle {
            cssProperties.append("text-decoration-style: \(textDecorationStyle)")
        }
        if let textDecorationColor {
            cssProperties.append("text-decoration-color: \(textDecorationColor)")
        }
        if let listStyleType {
            cssProperties.append("list-style-type: \(listStyleType)")
        }
        if let textAlign {
            cssProperties.append("text-align: \(textAlign)")
        }
        if let verticalAlign {
            cssProperties.append("vertical-align: \(verticalAlign)")
        }
        if let margin {
            cssProperties.append("margin: \(margin)")
        }
        if let padding {
            cssProperties.append("padding: \(padding)")
        }
        if let borderColor {
            cssProperties.append("border-color: \(borderColor)")
        }
        if let borderStyle {
            cssProperties.append("border-style: \(borderStyle)")
        }
        if let borderRadius {
            cssProperties.append("border-radius: \(borderRadius)")
        }
        if let borderWidth {
            cssProperties.append("border-width: \(borderWidth)")
        }
        if let textEmphasis {
            cssProperties.append("text-emphasis: \(textEmphasis)")
        }
        if let textShadow {
            cssProperties.append("text-shadow: \(textShadow)")
        }
        if let whiteSpace {
            cssProperties.append("white-space: \(whiteSpace)")
        }
        if let wordBreak {
            cssProperties.append("word-break: \(wordBreak)")
        }

        return cssProperties.joined(separator: "; ")
    }
}

// MARK: - Style Extension

extension View {
    func applyStyle(_ style: ContentStyle?) -> some View {
        var view = AnyView(self)

        guard let style else { return view }

        if let fontWeight = style.fontWeight, fontWeight == "bold" {
            view = AnyView(view.fontWeight(.bold))
        }

        if let fontStyle = style.fontStyle, fontStyle == "italic" {
            view = AnyView(view.italic())
        }

        if let color = style.color {
            view = AnyView(view.foregroundStyle(Color(hex: color) ?? .primary))
        }

        if let backgroundColor = style.backgroundColor {
            view = AnyView(view.background(Color(hex: backgroundColor) ?? .clear))
        }

        // Add more style applications as needed

        return view
    }
}

// Helper for hex color parsing
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let int = UInt64(hex, radix: 16) else {
            return nil
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
