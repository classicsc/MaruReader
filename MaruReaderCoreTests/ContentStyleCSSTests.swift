// ContentStyleCSSTests.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
@testable import MaruReaderCore
import Testing

struct ContentStyleCSSTests {
    @Test func toCSSString_AllPropertiesSet_ReturnsCompleteCSS() {
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

    @Test func toCSSString_PartialProperties_ReturnsPartialCSS() {
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

    @Test func toCSSString_EmptyStyle_ReturnsEmptyString() {
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

    @Test func toCSSString_EmptyTextDecorationLine_IgnoresProperty() {
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

    @Test func toCSSString_SingleTextDecorationLine_FormatsCorrectly() {
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

    // MARK: - CSSValue Tests

    @Test func cssValue_numericValue_returnsEmSuffix() {
        let value = CSSValue.numeric(1.5)
        #expect(value.cssString == "1.5em")
    }

    @Test func cssValue_stringValue_returnsUnmodified() {
        let value = CSSValue.string("10px")
        #expect(value.cssString == "10px")
    }

    @Test func cssValue_numericCoding_encodesAndDecodesCorrectly() throws {
        let original = CSSValue.numeric(2.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CSSValue.self, from: data)

        #expect(decoded == original)
        #expect(decoded.cssString == "2.0em")
    }

    @Test func cssValue_stringCoding_encodesAndDecodesCorrectly() throws {
        let original = CSSValue.string("15px")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CSSValue.self, from: data)

        #expect(decoded == original)
        #expect(decoded.cssString == "15px")
    }

    // MARK: - Individual Margin/Padding Property Tests

    @Test func toCSSString_individualMarginProperties_takePrecedenceOverShorthand() {
        let style = ContentStyle(
            margin: "20px",
            marginTop: .numeric(1.0),
            marginLeft: .string("5px")
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("margin-top: 1.0em"))
        #expect(cssString.contains("margin-left: 5px"))
        #expect(!cssString.contains("margin: 20px"))
    }

    @Test func toCSSString_onlyShorthandMargin_usesShorthand() {
        let style = ContentStyle(margin: "15px")

        let cssString = style.toCSSString()

        #expect(cssString.contains("margin: 15px"))
        #expect(!cssString.contains("margin-top"))
        #expect(!cssString.contains("margin-left"))
    }

    @Test func toCSSString_individualPaddingProperties_takePrecedenceOverShorthand() {
        let style = ContentStyle(
            padding: "10px",
            paddingTop: "2px",
            paddingRight: "4px"
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("padding-top: 2px"))
        #expect(cssString.contains("padding-right: 4px"))
        #expect(!cssString.contains("padding: 10px"))
    }

    @Test func toCSSString_allIndividualMarginProperties_includesAll() {
        let style = ContentStyle(
            marginTop: .numeric(1.0),
            marginLeft: .string("2px"),
            marginRight: .numeric(3.0),
            marginBottom: .string("4px")
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("margin-top: 1.0em"))
        #expect(cssString.contains("margin-left: 2px"))
        #expect(cssString.contains("margin-right: 3.0em"))
        #expect(cssString.contains("margin-bottom: 4px"))
    }

    // MARK: - New CSS Properties Tests

    @Test func toCSSString_advancedProperties_includesClipPathAndCursor() {
        let style = ContentStyle(
            clipPath: "circle(50%)",
            cursor: "pointer"
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("clip-path: circle(50%)"))
        #expect(cssString.contains("cursor: pointer"))
    }

    @Test func toCSSString_allNewProperties_formatsCorrectly() {
        let style = ContentStyle(
            marginTop: .numeric(1.0),
            marginLeft: .string("10px"),
            paddingTop: "5px",
            paddingBottom: "8px",
            clipPath: "polygon(0% 0%, 100% 0%, 100% 100%)",
            cursor: "grab"
        )

        let cssString = style.toCSSString()

        #expect(cssString.contains("margin-top: 1.0em"))
        #expect(cssString.contains("margin-left: 10px"))
        #expect(cssString.contains("padding-top: 5px"))
        #expect(cssString.contains("padding-bottom: 8px"))
        #expect(cssString.contains("clip-path: polygon(0% 0%, 100% 0%, 100% 100%)"))
        #expect(cssString.contains("cursor: grab"))
    }

    // MARK: - Data Attributes Tests

    @Test func toDataAttributes_fontStyling_addsFontStyledAttribute() {
        let style = ContentStyle(
            fontStyle: "italic",
            fontWeight: "bold"
        )

        let attributes = style.toDataAttributes()

        #expect(attributes["data-font-styled"] == "true")
        #expect(attributes.count == 1)
    }

    @Test func toDataAttributes_colorStyling_addsColorStyledAttribute() {
        let style = ContentStyle(
            color: "#ff0000",
            backgroundColor: "#ffffff"
        )

        let attributes = style.toDataAttributes()

        #expect(attributes["data-color-styled"] == "true")
        #expect(attributes.count == 1)
    }

    @Test func toDataAttributes_textDecoration_addsTextDecoratedAttribute() {
        let style = ContentStyle(
            textDecorationLine: ["underline"],
            textDecorationColor: "#0000ff"
        )

        let attributes = style.toDataAttributes()

        #expect(attributes["data-text-decorated"] == "true")
        #expect(attributes.count == 1)
    }

    @Test func toDataAttributes_marginsAndPadding_addsSpacingAttributes() {
        let style = ContentStyle(
            marginTop: .numeric(1.0),
            paddingLeft: "10px"
        )

        let attributes = style.toDataAttributes()

        #expect(attributes["data-has-margin"] == "true")
        #expect(attributes["data-has-padding"] == "true")
        #expect(attributes.count == 2)
    }

    @Test func toDataAttributes_advancedProperties_addsSpecificAttributes() {
        let style = ContentStyle(
            borderStyle: "solid",
            clipPath: "circle(50%)",
            cursor: "pointer"
        )

        let attributes = style.toDataAttributes()

        #expect(attributes["data-has-border"] == "true")
        #expect(attributes["data-has-clip-path"] == "true")
        #expect(attributes["data-has-cursor"] == "true")
        #expect(attributes.count == 3)
    }

    @Test func toDataAttributes_noStyling_returnsEmptyDictionary() {
        let style = ContentStyle()

        let attributes = style.toDataAttributes()

        #expect(attributes.isEmpty)
    }

    // MARK: - CSS Classes Tests

    @Test func toCSSClasses_fontStyling_returnsSemanticClasses() {
        let style = ContentStyle(
            fontStyle: "italic",
            fontWeight: "bold"
        )

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-font-italic"))
        #expect(classes.contains("gloss-font-bold"))
    }

    @Test func toCSSClasses_textDecoration_returnsSpecificDecorationClasses() {
        let style = ContentStyle(
            textDecorationLine: ["underline", "line-through"]
        )

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-text-underline"))
        #expect(classes.contains("gloss-text-strikethrough"))
    }

    @Test func toCSSClasses_textAlign_returnsAlignmentClasses() {
        let style = ContentStyle(textAlign: "center")

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-text-center"))
    }

    @Test func toCSSClasses_rightAlignment_returnsRightClass() {
        let style = ContentStyle(textAlign: "right")

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-text-right"))
    }

    @Test func toCSSClasses_spacing_returnsSpacingClasses() {
        let style = ContentStyle(
            marginTop: .numeric(1.0),
            paddingLeft: "10px"
        )

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-margin"))
        #expect(classes.contains("gloss-padding"))
    }

    @Test func toCSSClasses_advancedProperties_returnsAdvancedClasses() {
        let style = ContentStyle(
            verticalAlign: "middle",
            clipPath: "circle(50%)",
            cursor: "pointer"
        )

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-clip-path"))
        #expect(classes.contains("gloss-cursor-pointer"))
        #expect(classes.contains("gloss-vertical-align-middle"))
    }

    @Test func toCSSClasses_noStyling_returnsEmptyArray() {
        let style = ContentStyle()

        let classes = style.toCSSClasses()

        #expect(classes.isEmpty)
    }

    @Test func toCSSClasses_complexStyling_returnsAllRelevantClasses() {
        let style = ContentStyle(
            fontWeight: "bold",
            backgroundColor: "#fff",
            textDecorationLine: ["underline"],
            textAlign: "center",
            borderStyle: "solid",
            marginTop: .numeric(1.0)
        )

        let classes = style.toCSSClasses()

        #expect(classes.contains("gloss-font-bold"))
        #expect(classes.contains("gloss-text-underline"))
        #expect(classes.contains("gloss-text-center"))
        #expect(classes.contains("gloss-background"))
        #expect(classes.contains("gloss-border-partial"))
        #expect(classes.contains("gloss-margin"))
    }
}
