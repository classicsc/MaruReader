//
//  ContentStyle.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
import SwiftUI

struct ContentStyle: Codable {
    let fontStyle: String?
    let fontWeight: String?
    let fontSize: String?
    let color: String?
    let backgroundColor: String?
    let background: String?
    let textDecorationLine: Any? // Can be String or [String]
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
            textDecorationLine = singleDecoration
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

        // Encode textDecorationLine based on its type
        if let singleDecoration = textDecorationLine as? String {
            try container.encode(singleDecoration, forKey: .textDecorationLine)
        } else if let multipleDecorations = textDecorationLine as? [String] {
            try container.encode(multipleDecorations, forKey: .textDecorationLine)
        }

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
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
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
