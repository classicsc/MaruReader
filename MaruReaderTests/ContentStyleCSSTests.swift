//
//  ContentStyleCSSTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/14/25.
//

import Foundation
@testable import MaruReader
import Testing

struct ContentStyleCSSTests {
    @Test func toCSSString_AllPropertiesSet_ReturnsCompleteCSS() throws {
        let style = ContentStyle(
            fontStyle: "italic",
            fontWeight: "bold",
            fontSize: "16px",
            color: "#000000",
            backgroundColor: "#ffffff",
            background: "linear-gradient(red, blue)",
            textDecorationLine: ["underline", "overline"],
            textDecorationStyle: "solid",
            textDecorationColor: "#ff0000",
            listStyleType: "disc",
            textAlign: "center",
            verticalAlign: "middle",
            margin: "10px",
            padding: "5px",
            borderColor: "#cccccc",
            borderStyle: "solid",
            borderRadius: "4px",
            borderWidth: "1px",
            textEmphasis: "filled circle",
            textShadow: "2px 2px 4px rgba(0,0,0,0.5)",
            whiteSpace: "nowrap",
            wordBreak: "break-all"
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("font-style: italic"))
        #expect(cssString.contains("font-weight: bold"))
        #expect(cssString.contains("font-size: 16px"))
        #expect(cssString.contains("color: #000000"))
        #expect(cssString.contains("background-color: #ffffff"))
        #expect(cssString.contains("background: linear-gradient(red, blue)"))
        #expect(cssString.contains("text-decoration-line: underline overline"))
        #expect(cssString.contains("text-decoration-style: solid"))
        #expect(cssString.contains("text-decoration-color: #ff0000"))
        #expect(cssString.contains("list-style-type: disc"))
        #expect(cssString.contains("text-align: center"))
        #expect(cssString.contains("vertical-align: middle"))
        #expect(cssString.contains("margin: 10px"))
        #expect(cssString.contains("padding: 5px"))
        #expect(cssString.contains("border-color: #cccccc"))
        #expect(cssString.contains("border-style: solid"))
        #expect(cssString.contains("border-radius: 4px"))
        #expect(cssString.contains("border-width: 1px"))
        #expect(cssString.contains("text-emphasis: filled circle"))
        #expect(cssString.contains("text-shadow: 2px 2px 4px rgba(0,0,0,0.5)"))
        #expect(cssString.contains("white-space: nowrap"))
        #expect(cssString.contains("word-break: break-all"))
    }

    @Test func toCSSString_PartialProperties_ReturnsPartialCSS() throws {
        let style = ContentStyle(
            fontStyle: nil,
            fontWeight: "bold",
            fontSize: "16px",
            color: nil,
            backgroundColor: "#ffffff",
            background: nil,
            textDecorationLine: nil,
            textDecorationStyle: nil,
            textDecorationColor: nil,
            listStyleType: nil,
            textAlign: "center",
            verticalAlign: nil,
            margin: nil,
            padding: "5px",
            borderColor: nil,
            borderStyle: nil,
            borderRadius: nil,
            borderWidth: nil,
            textEmphasis: nil,
            textShadow: nil,
            whiteSpace: nil,
            wordBreak: nil
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("font-weight: bold"))
        #expect(cssString.contains("font-size: 16px"))
        #expect(cssString.contains("background-color: #ffffff"))
        #expect(cssString.contains("text-align: center"))
        #expect(cssString.contains("padding: 5px"))

        #expect(!cssString.contains("font-style"))
        #expect(!cssString.hasPrefix("color:") && !cssString.contains("; color:"))
        #expect(!cssString.contains("text-decoration"))
        #expect(!cssString.contains("margin"))
    }

    @Test func toCSSString_EmptyStyle_ReturnsEmptyString() throws {
        let style = ContentStyle(
            fontStyle: nil,
            fontWeight: nil,
            fontSize: nil,
            color: nil,
            backgroundColor: nil,
            background: nil,
            textDecorationLine: nil,
            textDecorationStyle: nil,
            textDecorationColor: nil,
            listStyleType: nil,
            textAlign: nil,
            verticalAlign: nil,
            margin: nil,
            padding: nil,
            borderColor: nil,
            borderStyle: nil,
            borderRadius: nil,
            borderWidth: nil,
            textEmphasis: nil,
            textShadow: nil,
            whiteSpace: nil,
            wordBreak: nil
        )

        let cssString = style.toCSSString()

        #expect(cssString.isEmpty)
    }

    @Test func toCSSString_EmptyTextDecorationLine_IgnoresProperty() throws {
        let style = ContentStyle(
            fontStyle: nil,
            fontWeight: "bold",
            fontSize: nil,
            color: nil,
            backgroundColor: nil,
            background: nil,
            textDecorationLine: [],
            textDecorationStyle: nil,
            textDecorationColor: nil,
            listStyleType: nil,
            textAlign: nil,
            verticalAlign: nil,
            margin: nil,
            padding: nil,
            borderColor: nil,
            borderStyle: nil,
            borderRadius: nil,
            borderWidth: nil,
            textEmphasis: nil,
            textShadow: nil,
            whiteSpace: nil,
            wordBreak: nil
        )

        let cssString = style.toCSSString()

        #expect(cssString == "font-weight: bold")
        #expect(!cssString.contains("text-decoration-line"))
    }

    @Test func toCSSString_SingleTextDecorationLine_FormatsCorrectly() throws {
        let style = ContentStyle(
            fontStyle: nil,
            fontWeight: nil,
            fontSize: nil,
            color: nil,
            backgroundColor: nil,
            background: nil,
            textDecorationLine: ["underline"],
            textDecorationStyle: nil,
            textDecorationColor: nil,
            listStyleType: nil,
            textAlign: nil,
            verticalAlign: nil,
            margin: nil,
            padding: nil,
            borderColor: nil,
            borderStyle: nil,
            borderRadius: nil,
            borderWidth: nil,
            textEmphasis: nil,
            textShadow: nil,
            whiteSpace: nil,
            wordBreak: nil
        )

        let cssString = style.toCSSString()

        #expect(cssString == "text-decoration-line: underline")
    }
}
