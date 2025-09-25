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

        // Semantic classes based on styling properties, using Yomitan-like specific classes (gloss- prefix)
        if let fontWeight {
            // Yomitan-like specific classes
            let weight = fontWeight.lowercased()
            if weight == "bold" || weight == "700" {
                classes.append("gloss-font-bold")
            } else if weight == "normal" || weight == "400" {
                classes.append("gloss-font-normal")
            } else if weight.contains("light") || weight == "300" {
                classes.append("gloss-font-light")
            }
        }

        if let fontStyle {
            if fontStyle.lowercased() == "italic" {
                classes.append("gloss-font-italic")
            } else if fontStyle.lowercased() == "oblique" {
                classes.append("gloss-font-oblique")
            }
        }

        if let textDecorationLine, !textDecorationLine.isEmpty {
            // Add specific decoration classes
            for decoration in textDecorationLine {
                let dec = decoration.lowercased()
                switch dec {
                case "underline":
                    classes.append("gloss-text-underline")
                case "line-through":
                    classes.append("gloss-text-strikethrough")
                case "overline":
                    classes.append("gloss-text-overline")
                default:
                    classes.append("gloss-text-decoration-\(dec)")
                }
            }
        }

        if backgroundColor != nil || background != nil {
            classes.append("gloss-background")
        }

        if let borderStyle, let borderWidth, let borderColor {
            classes.append("gloss-border")
        } else if borderStyle != nil || borderWidth != nil || borderColor != nil {
            classes.append("gloss-border-partial")
        }

        if marginTop != nil || marginLeft != nil || marginRight != nil || marginBottom != nil || margin != nil {
            classes.append("gloss-margin")
        }

        if paddingTop != nil || paddingLeft != nil || paddingRight != nil || paddingBottom != nil || padding != nil {
            classes.append("gloss-padding")
        }

        if let textAlign {
            let align = textAlign.lowercased()
            switch align {
            case "center":
                classes.append("gloss-text-center")
            case "right":
                classes.append("gloss-text-right")
            case "justify":
                classes.append("gloss-text-justify")
            case "left":
                classes.append("gloss-text-left")
            default:
                break
            }
        }

        if let verticalAlign {
            let align = verticalAlign.lowercased()
            switch align {
            case "baseline":
                classes.append("gloss-vertical-align-baseline")
            case "sub":
                classes.append("gloss-vertical-align-sub")
            case "super":
                classes.append("gloss-vertical-align-super")
            case "text-top":
                classes.append("gloss-vertical-align-text-top")
            case "text-bottom":
                classes.append("gloss-vertical-align-text-bottom")
            case "middle":
                classes.append("gloss-vertical-align-middle")
            case "top":
                classes.append("gloss-vertical-align-top")
            case "bottom":
                classes.append("gloss-vertical-align-bottom")
            default:
                classes.append("gloss-vertical-align")
            }
        }

        if clipPath != nil {
            classes.append("gloss-clip-path")
        }

        if cursor != nil {
            let cur = cursor!.lowercased()
            if cur == "pointer" {
                classes.append("gloss-cursor-pointer")
            } else if cur == "default" {
                classes.append("gloss-cursor-default")
            }
        }

        // Additional Yomitan-like classes for complex properties
        if let listStyleType {
            let cleanType = listStyleType
                .lowercased()
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "\"", with: "")

            // Only add class for standard types, custom quoted ones will use inline styles
            if !listStyleType.contains("'"), !listStyleType.contains("\"") {
                classes.append("gloss-list-\(cleanType)")
            }
        }

        if let whiteSpace {
            let ws = whiteSpace.lowercased()
            if ws == "nowrap" {
                classes.append("gloss-text-nowrap")
            } else if ws == "pre" {
                classes.append("gloss-text-pre")
            }
        }

        if let wordBreak {
            let wb = wordBreak.lowercased()
            if wb == "break-all" {
                classes.append("gloss-word-break-all")
            }
        }

        return classes
    }

    /// Generates a full inline style attribute string for direct HTML use, e.g., style="color: red; font-weight: bold;"
    func toInlineStyles() -> String {
        let css = toCSSString()
        if css.isEmpty {
            return ""
        }
        return "style=\"\(css)\""
    }

    /// Generates specific styles for image containers, incorporating relevant properties
    /// Similar to Yomitan's gloss-image-container styles
    func toImageContainerStyles() -> String {
        var cssProperties: [String] = []

        // Border properties for container
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

        // Background for image background
        if let backgroundColor {
            cssProperties.append("background-color: \(backgroundColor)")
        }
        if let background {
            cssProperties.append("background: \(background)")
        }

        // Vertical alignment
        if let verticalAlign {
            cssProperties.append("vertical-align: \(verticalAlign)")
        }

        // Margins and padding
        if let margin {
            cssProperties.append("margin: \(margin)")
        } else {
            if let marginTop { cssProperties.append("margin-top: \(marginTop.cssString)") }
            if let marginLeft { cssProperties.append("margin-left: \(marginLeft.cssString)") }
            if let marginRight { cssProperties.append("margin-right: \(marginRight.cssString)") }
            if let marginBottom { cssProperties.append("margin-bottom: \(marginBottom.cssString)") }
        }

        if let padding {
            cssProperties.append("padding: \(padding)")
        } else {
            if let paddingTop { cssProperties.append("padding-top: \(paddingTop)") }
            if let paddingLeft { cssProperties.append("padding-left: \(paddingLeft)") }
            if let paddingRight { cssProperties.append("padding-right: \(paddingRight)") }
            if let paddingBottom { cssProperties.append("padding-bottom: \(paddingBottom)") }
        }

        // Clip path if applicable to container
        if let clipPath {
            cssProperties.append("clip-path: \(clipPath)")
        }

        let css = cssProperties.joined(separator: "; ")
        return css.isEmpty ? "" : "style=\"\(css)\""
    }

    /// Validates CSS values for common invalid or unsupported configurations
    /// Returns true if valid, false otherwise with a description of issues
    func validate() -> (valid: Bool, issues: [String]) {
        var issues: [String] = []

        // Validate fontWeight (common values: normal, bold, lighter, bolder, 100-900)
        if let fontWeight {
            let weight = fontWeight.lowercased()
            if !["normal", "bold", "bolder", "lighter"].contains(weight), weight.range(of: "^[1-9]00$", options: .regularExpression) == nil {
                issues.append("Invalid font-weight: \(fontWeight) should be normal/bold or 100-900")
            }
        }

        // Validate colors (simple check for hex, rgb, or named)
        let colorPattern = "^(#[0-9a-fA-F]{3,6}|rgb\\((\\d{1,3},\\s?){2}\\d{1,3}\\)|\\/\\/\\w+)$"
        if let color, color.range(of: colorPattern, options: .regularExpression) == nil {
            issues.append("Invalid color: \(color)")
        }
        if let backgroundColor, backgroundColor.range(of: colorPattern, options: .regularExpression) == nil {
            issues.append("Invalid background-color: \(backgroundColor)")
        }
        if let borderColor, borderColor.range(of: colorPattern, options: .regularExpression) == nil {
            issues.append("Invalid border-color: \(borderColor)")
        }
        if let textDecorationColor, textDecorationColor.range(of: colorPattern, options: .regularExpression) == nil {
            issues.append("Invalid text-decoration-color: \(textDecorationColor)")
        }

        // Validate textDecorationLine (common values)
        if let textDecorationLine {
            let validDecorations = ["underline", "overline", "line-through", "blink", "none"]
            for line in textDecorationLine {
                if !validDecorations.contains(line.lowercased()) {
                    issues.append("Invalid text-decoration-line value: \(line)")
                }
            }
        }

        // Validate textDecorationStyle
        if let textDecorationStyle {
            let validStyles = ["solid", "double", "dotted", "dashed", "wavy", "none"]
            if !validStyles.contains(textDecorationStyle.lowercased()) {
                issues.append("Invalid text-decoration-style: \(textDecorationStyle)")
            }
        }

        // Validate borderStyle
        if let borderStyle {
            let validBorders = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
            if !validBorders.contains(borderStyle.lowercased()) {
                issues.append("Invalid border-style: \(borderStyle)")
            }
        }

        // Validate textAlign
        if let textAlign {
            let validAligns = ["left", "right", "center", "justify", "start", "end"]
            if !validAligns.contains(textAlign.lowercased()) {
                issues.append("Invalid text-align: \(textAlign)")
            }
        }

        // Validate verticalAlign (common values)
        if let verticalAlign {
            let validVerticals = ["baseline", "sub", "super", "text-top", "text-bottom", "middle", "top", "bottom"]
            if !validVerticals.contains(verticalAlign.lowercased()) {
                issues.append("Invalid vertical-align: \(verticalAlign)")
            }
        }

        // Check for conflicting properties, e.g., margin shorthand with individuals (but allow, as individuals take precedence)
        // For clipPath, basic check if it's a valid path (simple regex for common types)
        if let clipPath, clipPath.range(of: "^(inset\\(|circle\\(|ellipse\\(|polygon\\(|path\\(|none)$", options: .regularExpression) == nil {
            issues.append("Potentially invalid clip-path: \(clipPath)")
        }

        return (issues.isEmpty, issues)
    }
}
