//
//  ContentStyle.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation

enum CSSValue: Codable, Sendable, Equatable {
    case numeric(Double)
    case string(String)

    var cssString: String {
        switch self {
        case let .numeric(value):
            "\(value)em"
        case let .string(value):
            value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            self = .numeric(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(CSSValue.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected Double or String"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .numeric(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        }
    }
}

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

    // Individual margin properties
    let marginTop: CSSValue?
    let marginLeft: CSSValue?
    let marginRight: CSSValue?
    let marginBottom: CSSValue?

    // Individual padding properties
    let paddingTop: String?
    let paddingLeft: String?
    let paddingRight: String?
    let paddingBottom: String?

    // Advanced CSS properties
    let clipPath: String?
    let cursor: String?

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
        wordBreak: String? = nil,
        marginTop: CSSValue? = nil,
        marginLeft: CSSValue? = nil,
        marginRight: CSSValue? = nil,
        marginBottom: CSSValue? = nil,
        paddingTop: String? = nil,
        paddingLeft: String? = nil,
        paddingRight: String? = nil,
        paddingBottom: String? = nil,
        clipPath: String? = nil,
        cursor: String? = nil
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
        self.marginTop = marginTop
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.marginBottom = marginBottom
        self.paddingTop = paddingTop
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
        self.paddingBottom = paddingBottom
        self.clipPath = clipPath
        self.cursor = cursor
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
        case marginTop
        case marginLeft
        case marginRight
        case marginBottom
        case paddingTop
        case paddingLeft
        case paddingRight
        case paddingBottom
        case clipPath
        case cursor
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
        marginTop = try container.decodeIfPresent(CSSValue.self, forKey: .marginTop)
        marginLeft = try container.decodeIfPresent(CSSValue.self, forKey: .marginLeft)
        marginRight = try container.decodeIfPresent(CSSValue.self, forKey: .marginRight)
        marginBottom = try container.decodeIfPresent(CSSValue.self, forKey: .marginBottom)
        paddingTop = try container.decodeIfPresent(String.self, forKey: .paddingTop)
        paddingLeft = try container.decodeIfPresent(String.self, forKey: .paddingLeft)
        paddingRight = try container.decodeIfPresent(String.self, forKey: .paddingRight)
        paddingBottom = try container.decodeIfPresent(String.self, forKey: .paddingBottom)
        clipPath = try container.decodeIfPresent(String.self, forKey: .clipPath)
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
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
        try container.encodeIfPresent(marginTop, forKey: .marginTop)
        try container.encodeIfPresent(marginLeft, forKey: .marginLeft)
        try container.encodeIfPresent(marginRight, forKey: .marginRight)
        try container.encodeIfPresent(marginBottom, forKey: .marginBottom)
        try container.encodeIfPresent(paddingTop, forKey: .paddingTop)
        try container.encodeIfPresent(paddingLeft, forKey: .paddingLeft)
        try container.encodeIfPresent(paddingRight, forKey: .paddingRight)
        try container.encodeIfPresent(paddingBottom, forKey: .paddingBottom)
        try container.encodeIfPresent(clipPath, forKey: .clipPath)
        try container.encodeIfPresent(cursor, forKey: .cursor)
    }

    func toCSSString() -> String {
        var cssProperties: [String] = []

        // Font and text styling
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

        // Background styling
        if let backgroundColor {
            cssProperties.append("background-color: \(backgroundColor)")
        }
        if let background {
            cssProperties.append("background: \(background)")
        }

        // Text decoration
        if let textDecorationLine, !textDecorationLine.isEmpty {
            cssProperties.append("text-decoration-line: \(textDecorationLine.joined(separator: " "))")
        }
        if let textDecorationStyle {
            cssProperties.append("text-decoration-style: \(textDecorationStyle)")
        }
        if let textDecorationColor {
            cssProperties.append("text-decoration-color: \(textDecorationColor)")
        }

        // Text alignment and emphasis
        if let textAlign {
            cssProperties.append("text-align: \(textAlign)")
        }
        if let verticalAlign {
            cssProperties.append("vertical-align: \(verticalAlign)")
        }
        if let textEmphasis {
            cssProperties.append("text-emphasis: \(textEmphasis)")
        }
        if let textShadow {
            cssProperties.append("text-shadow: \(textShadow)")
        }

        // Margin handling - individual properties take precedence over shorthand
        let hasIndividualMargins = marginTop != nil || marginLeft != nil || marginRight != nil || marginBottom != nil
        if hasIndividualMargins {
            if let marginTop {
                cssProperties.append("margin-top: \(marginTop.cssString)")
            }
            if let marginLeft {
                cssProperties.append("margin-left: \(marginLeft.cssString)")
            }
            if let marginRight {
                cssProperties.append("margin-right: \(marginRight.cssString)")
            }
            if let marginBottom {
                cssProperties.append("margin-bottom: \(marginBottom.cssString)")
            }
        } else if let margin {
            cssProperties.append("margin: \(margin)")
        }

        // Padding handling - individual properties take precedence over shorthand
        let hasIndividualPaddings = paddingTop != nil || paddingLeft != nil || paddingRight != nil || paddingBottom != nil
        if hasIndividualPaddings {
            if let paddingTop {
                cssProperties.append("padding-top: \(paddingTop)")
            }
            if let paddingLeft {
                cssProperties.append("padding-left: \(paddingLeft)")
            }
            if let paddingRight {
                cssProperties.append("padding-right: \(paddingRight)")
            }
            if let paddingBottom {
                cssProperties.append("padding-bottom: \(paddingBottom)")
            }
        } else if let padding {
            cssProperties.append("padding: \(padding)")
        }

        // Border properties
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

        // Advanced CSS properties
        if let clipPath {
            cssProperties.append("clip-path: \(clipPath)")
        }
        if let cursor {
            cssProperties.append("cursor: \(cursor)")
        }

        // Text behavior
        if let whiteSpace {
            cssProperties.append("white-space: \(whiteSpace)")
        }
        if let wordBreak {
            cssProperties.append("word-break: \(wordBreak)")
        }

        // List styling
        if let listStyleType {
            cssProperties.append("list-style-type: \(listStyleType)")
        }

        return cssProperties.joined(separator: "; ")
    }

    func toDataAttributes() -> [String: String] {
        var attributes: [String: String] = [:]

        // Generate data attributes for styling metadata
        if fontStyle != nil || fontWeight != nil || fontSize != nil {
            attributes["data-font-styled"] = "true"
        }

        if color != nil || backgroundColor != nil || background != nil {
            attributes["data-color-styled"] = "true"
        }

        if textDecorationLine != nil || textDecorationStyle != nil || textDecorationColor != nil {
            attributes["data-text-decorated"] = "true"
        }

        if marginTop != nil || marginLeft != nil || marginRight != nil || marginBottom != nil || margin != nil {
            attributes["data-has-margin"] = "true"
        }

        if paddingTop != nil || paddingLeft != nil || paddingRight != nil || paddingBottom != nil || padding != nil {
            attributes["data-has-padding"] = "true"
        }

        if borderColor != nil || borderStyle != nil || borderRadius != nil || borderWidth != nil {
            attributes["data-has-border"] = "true"
        }

        if clipPath != nil {
            attributes["data-has-clip-path"] = "true"
        }

        if cursor != nil {
            attributes["data-has-cursor"] = "true"
        }

        return attributes
    }

    func toCSSClasses() -> [String] {
        var classes: [String] = []

        // Add semantic classes based on styling properties
        if fontWeight != nil {
            classes.append("styled-font-weight")
        }

        if fontStyle != nil {
            classes.append("styled-font-style")
        }

        if textDecorationLine != nil && !textDecorationLine!.isEmpty {
            classes.append("styled-text-decoration")
            // Add specific decoration classes
            for decoration in textDecorationLine! {
                switch decoration.lowercased() {
                case "underline":
                    classes.append("text-underlined")
                case "line-through":
                    classes.append("text-strikethrough")
                case "overline":
                    classes.append("text-overlined")
                default:
                    break
                }
            }
        }

        if backgroundColor != nil || background != nil {
            classes.append("styled-background")
        }

        if borderStyle != nil || borderWidth != nil || borderColor != nil {
            classes.append("styled-border")
        }

        if marginTop != nil || marginLeft != nil || marginRight != nil || marginBottom != nil || margin != nil {
            classes.append("styled-margin")
        }

        if paddingTop != nil || paddingLeft != nil || paddingRight != nil || paddingBottom != nil || padding != nil {
            classes.append("styled-padding")
        }

        if textAlign != nil {
            classes.append("styled-text-align")
            switch textAlign!.lowercased() {
            case "center":
                classes.append("text-center")
            case "right":
                classes.append("text-right")
            case "justify":
                classes.append("text-justify")
            default:
                break
            }
        }

        if verticalAlign != nil {
            classes.append("styled-vertical-align")
        }

        if clipPath != nil {
            classes.append("styled-clip-path")
        }

        if cursor != nil {
            classes.append("styled-cursor")
        }

        return classes
    }
}
