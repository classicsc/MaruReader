//
//  DictionaryContentMarkupTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/14/25.
//

import Foundation
@testable import MaruReader
import Testing

struct DictionaryContentMarkupTests {
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

    // MARK: - StructuredElement HTML Tests

    @Test func structuredElement_toHTML_SimpleElement() throws {
        let element = StructuredElement(
            tag: "p",
            content: .text("Hello World"),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html == "<p>Hello World</p>")
    }

    @Test func structuredElement_toHTML_WithStyle() throws {
        let style = ContentStyle(
            fontStyle: "italic",
            fontWeight: "bold",
            fontSize: "16px",
            color: "#000000"
        )

        let element = StructuredElement(
            tag: "span",
            content: .text("Styled Text"),
            data: nil,
            style: style,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("<span style=\"font-style: italic; font-weight: bold; font-size: 16px; color: #000000\">"))
        #expect(html.contains("Styled Text</span>"))
    }

    @Test func structuredElement_toHTML_LinkWithHref() throws {
        let element = StructuredElement(
            tag: "a",
            content: .text("Click me"),
            data: nil,
            style: nil,
            lang: nil,
            href: "https://example.com",
            path: nil,
            width: nil,
            height: nil,
            title: "Example Link",
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("href=\"https://example.com\""))
        #expect(html.contains("title=\"Example Link\""))
        #expect(html.contains(">Click me</a>"))
    }

    @Test func structuredElement_toHTML_ImageWithPath() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 50,
            title: nil,
            alt: "Test Image",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("src=\"image.png\""))
        #expect(html.contains("width=\"100\""))
        #expect(html.contains("height=\"50\""))
        #expect(html.contains("alt=\"Test Image\""))
        #expect(html.contains("/>"))
    }

    @Test func structuredElement_toHTML_ImageWithBaseURL() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "images/test.png",
            width: nil,
            height: nil,
            title: nil,
            alt: "Local Image",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let baseURL = URL(string: "file:///dictionary/")
        let html = element.toHTML(baseURL: baseURL)
        #expect(html.contains("src=\"file:///dictionary/images/test.png\""))
        #expect(html.contains("alt=\"Local Image\""))
    }

    @Test func structuredElement_toHTML_ImageWithAbsolutePath_SkipsSrc() throws {
        // Absolute URLs in dictionary content should be treated as errors
        // and the src attribute should be omitted
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "https://example.com/image.jpg",
            width: nil,
            height: nil,
            title: nil,
            alt: "Remote Image",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let baseURL = URL(string: "file:///dictionary/")
        let html = element.toHTML(baseURL: baseURL)
        #expect(!html.contains("src="))
        #expect(html.contains("alt=\"Remote Image\""))
    }

    @Test func structuredElement_toHTML_TableCellWithSpans() throws {
        let element = StructuredElement(
            tag: "td",
            content: .text("Cell Content"),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: 2,
            rowSpan: 3,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("colspan=\"2\""))
        #expect(html.contains("rowspan=\"3\""))
        #expect(html.contains(">Cell Content</td>"))
    }

    @Test func structuredElement_toHTML_DetailsElement() throws {
        let element = StructuredElement(
            tag: "details",
            content: .text("Details Content"),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: true
        )

        let html = element.toHTML()
        #expect(html.contains("<details open>"))
        #expect(html.contains("Details Content</details>"))
    }

    @Test func structuredElement_toHTML_WithLanguage() throws {
        let element = StructuredElement(
            tag: "span",
            content: .text("日本語"),
            data: nil,
            style: nil,
            lang: "ja",
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("lang=\"ja\""))
        #expect(html.contains(">日本語</span>"))
    }

    @Test func structuredElement_toHTML_WithDataAttributes() throws {
        let element = StructuredElement(
            tag: "div",
            content: .text("Content"),
            data: ["id": "123", "type": "example"],
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-id=\"123\""))
        #expect(html.contains("data-type=\"example\""))
    }

    @Test func structuredElement_toHTML_SelfClosingTags() throws {
        let br = StructuredElement(
            tag: "br",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = br.toHTML()
        #expect(html == "<br />")

        let hr = StructuredElement(
            tag: "hr",
            content: nil,
            data: nil,
            style: ContentStyle(borderWidth: "1px"),
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let hrHtml = hr.toHTML()
        #expect(hrHtml.contains("<hr"))
        #expect(hrHtml.contains("/>"))
    }

    @Test func structuredElement_toHTML_NestedContent() throws {
        let innerElement = StructuredElement(
            tag: "strong",
            content: .text("Bold"),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let outerElement = StructuredElement(
            tag: "p",
            content: .array([
                .text("This is "),
                .element(innerElement),
                .text(" text."),
            ]),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = outerElement.toHTML()
        #expect(html == "<p>This is <strong>Bold</strong> text.</p>")
    }

    @Test func structuredElement_toHTML_EscapesHTMLCharacters() throws {
        let element = StructuredElement(
            tag: "p",
            content: .text("Text with <special> & \"quoted\" 'characters'"),
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("&lt;special&gt;"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&quot;quoted&quot;"))
        #expect(html.contains("&#39;characters&#39;"))
    }

    @Test func structuredElement_toHTML_EscapesAttributeValues() throws {
        let element = StructuredElement(
            tag: "a",
            content: .text("Link"),
            data: nil,
            style: nil,
            lang: nil,
            href: "https://example.com?param=\"value\"&other='test'",
            path: nil,
            width: nil,
            height: nil,
            title: "Title with \"quotes\" & 'apostrophes'",
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("href=\"https://example.com?param=&quot;value&quot;&amp;other=&#39;test&#39;\""))
        #expect(html.contains("title=\"Title with &quot;quotes&quot; &amp; &#39;apostrophes&#39;\""))
    }

    @Test func structuredElement_toHTML_ComplexNestedStructure() throws {
        let linkElement = StructuredElement(
            tag: "a",
            content: .text("link"),
            data: nil,
            style: ContentStyle(color: "#0000FF", textDecorationLine: ["underline"]),
            lang: nil,
            href: "https://example.com",
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let divElement = StructuredElement(
            tag: "div",
            content: .array([
                .text("This is a "),
                .element(linkElement),
                .text(" in a div."),
            ]),
            data: ["section": "main"],
            style: ContentStyle(backgroundColor: "#f0f0f0", padding: "10px"),
            lang: "en",
            href: nil,
            path: nil,
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = divElement.toHTML()
        #expect(html.contains("<div"))
        #expect(html.contains("style=\""))
        #expect(html.contains("padding: 10px"))
        #expect(html.contains("background-color: #f0f0f0"))
        #expect(html.contains("lang=\"en\""))
        #expect(html.contains("data-section=\"main\""))
        #expect(html.contains("<a"))
        #expect(html.contains("href=\"https://example.com\""))
        #expect(html.contains("color: #0000FF"))
        #expect(html.contains("text-decoration-line: underline"))
    }
}
