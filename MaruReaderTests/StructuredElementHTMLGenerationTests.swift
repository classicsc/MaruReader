//
//  StructuredElementHTMLGenerationTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/14/25.
//

import Foundation
@testable import MaruReader
import Testing

struct DictionaryContentMarkupTests {
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
        // New image structure should be Yomitan-compatible
        #expect(html.contains("class=\"gloss-image-link\""))
        #expect(html.contains("class=\"gloss-image-container\""))
        #expect(html.contains("class=\"gloss-image-sizer\""))
        #expect(html.contains("class=\"gloss-image-background\""))
        #expect(html.contains("class=\"gloss-image\""))
        #expect(html.contains("class=\"gloss-image-container-overlay\""))
        #expect(html.contains("class=\"gloss-image-link-text\""))
        #expect(html.contains("src=\"image.png\""))
        #expect(html.contains("alt=\"Test Image\""))
        #expect(html.contains("data-path=\"image.png\""))
        #expect(html.contains("data-image-load-state=\"loaded\""))
        #expect(html.contains("data-has-aspect-ratio=\"true\""))
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
        #expect(html.contains("href=\"file:///dictionary/images/test.png\""))
        #expect(html.contains("alt=\"Local Image\""))
        #expect(html.contains("class=\"gloss-image-link\""))
        #expect(html.contains("data-path=\"images/test.png\""))
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
        #expect(!html.contains("href="))
        #expect(html.contains("class=\"gloss-image-link\""))
        #expect(html.contains("data-path=\"https://example.com/image.jpg\""))
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

    // MARK: - Enhanced Image Element Tests

    @Test func structuredElement_toHTML_ImageWithPreferredDimensions() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "test.png",
            width: 200,
            height: 100,
            preferredWidth: 150,
            preferredHeight: 100,
            title: "Test Title",
            alt: "Test Alt",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        // Should use preferred dimensions for aspect ratio calculation
        let expectedAspectRatio = 100.0 / 150.0 // preferredHeight / preferredWidth
        let expectedPaddingTop = expectedAspectRatio * 100
        #expect(html.contains("padding-top: \(expectedPaddingTop)%"))
        #expect(html.contains("width: 150.0em")) // Should use preferredWidth
    }

    @Test func structuredElement_toHTML_ImageWithPixelatedRendering() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "pixel-art.png",
            width: 64,
            height: 64,
            title: nil,
            alt: nil,
            pixelated: true,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-image-rendering=\"pixelated\""))
    }

    @Test func structuredElement_toHTML_ImageWithCustomImageRendering() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            imageRendering: "crisp-edges",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-image-rendering=\"crisp-edges\""))
    }

    @Test func structuredElement_toHTML_ImageWithAppearanceAndBackground() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            appearance: "dark",
            background: false,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-appearance=\"dark\""))
        #expect(html.contains("data-background=\"false\""))
    }

    @Test func structuredElement_toHTML_ImageWithCollapsibleState() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            collapsed: true,
            collapsible: false,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-collapsed=\"true\""))
        #expect(html.contains("data-collapsible=\"false\""))
    }

    @Test func structuredElement_toHTML_ImageWithVerticalAlign() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            verticalAlign: "middle",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-vertical-align=\"middle\""))
    }

    @Test func structuredElement_toHTML_ImageWithBorderAndRadius() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            border: "1px solid red",
            borderRadius: "5px",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("border: 1px solid red"))
        #expect(html.contains("border-radius: 5px"))
    }

    @Test func structuredElement_toHTML_ImageWithEmSizeUnits() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: 10,
            preferredHeight: 5,
            title: nil,
            alt: nil,
            sizeUnits: "em",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-size-units=\"em\""))
        // Should include scaled width and height for em-based sizing
        let devicePixelRatio = 2.0
        let emSize = 14.0
        let scaleFactor = 2 * devicePixelRatio
        let expectedWidth = Int(10 * emSize * scaleFactor) // preferredWidth * emSize * scaleFactor
        let expectedHeight = Int(10 * (5.0 / 10.0) * emSize * scaleFactor) // aspect ratio preserved
        #expect(html.contains("width=\"\(expectedWidth)\""))
        #expect(html.contains("height=\"\(expectedHeight)\""))
    }

    @Test func structuredElement_toHTML_ImageAspectRatioCalculations() throws {
        // Test with only preferredHeight
        let element1 = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 200,
            height: 100,
            preferredHeight: 150,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html1 = element1.toHTML()
        // Should calculate width from preferredHeight and aspect ratio (height/width = 100/200 = 0.5)
        let expectedWidth1 = 150.0 / (100.0 / 200.0) // preferredHeight / invAspectRatio = 300
        #expect(html1.contains("width: \(expectedWidth1)em"))

        // Test with neither preferred dimension (should use width/height)
        let element2 = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 120,
            height: 80,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html2 = element2.toHTML()
        #expect(html2.contains("width: 120.0em")) // Should use original width
        let expectedPaddingTop2 = (80.0 / 120.0) * 100 // (height/width) * 100
        #expect(html2.contains("padding-top: \(expectedPaddingTop2)%"))
    }

    @Test func structuredElement_toHTML_ImageDefaultDataAttributes() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        // Test default values
        #expect(html.contains("data-image-rendering=\"auto\""))
        #expect(html.contains("data-appearance=\"auto\""))
        #expect(html.contains("data-background=\"true\""))
        #expect(html.contains("data-collapsed=\"false\""))
        #expect(html.contains("data-collapsible=\"true\""))
        #expect(!html.contains("data-vertical-align")) // Should not be present when nil
        #expect(!html.contains("data-size-units")) // Should not be present when no preferred dimensions
    }

    @Test func structuredElement_toHTML_ImageLinkStructure() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "image.png",
            width: 100,
            height: 100,
            title: "Image Description",
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()

        // Test the complete Yomitan-compatible structure
        #expect(html.contains("<a "))
        #expect(html.contains("class=\"gloss-image-link\""))
        #expect(html.contains("target=\"_blank\""))
        #expect(html.contains("rel=\"noreferrer noopener\""))

        #expect(html.contains("<span class=\"gloss-image-container\""))
        #expect(html.contains("<span class=\"gloss-image-sizer\""))
        #expect(html.contains("<span class=\"gloss-image-background\"></span>"))
        #expect(html.contains("<img class=\"gloss-image\""))
        #expect(html.contains("<span class=\"gloss-image-container-overlay\"></span>"))
        #expect(html.contains("<span class=\"gloss-image-link-text\">Image</span>"))
        #expect(html.contains("<span class=\"gloss-image-description\">Image Description</span>"))

        #expect(html.contains("</span>")) // Container close
        #expect(html.contains("</a>")) // Link close
    }
}
