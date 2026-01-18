// StructuredElementHTMLGenerationTests.swift
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
        #expect(html == "<p class=\"gloss-sc-p\">Hello World</p>")
        #expect(!html.contains("style="))
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
        #expect(html.contains("<span class=\"gloss-sc-span gloss-font-bold gloss-font-italic\" style=\"font-style: italic; font-weight: bold; font-size: 16px; color: #000000\">Styled Text</span>"))
        #expect(html.contains("Styled Text</span>"))
        #expect(html.contains("style="))
    }

    @Test func structuredElement_toHTML_NoStyleAddsOnlyBaseClass() throws {
        let element = StructuredElement(
            tag: "div",
            content: .text("Plain Text"),
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
        #expect(html == "<div class=\"gloss-sc-div\">Plain Text</div>")
        #expect(!html.contains("gloss-font-"))
        #expect(!html.contains("style="))
    }

    @Test func contentStyle_toCSSClasses_GeneratesExpectedClasses() throws {
        let style = ContentStyle(
            fontStyle: "italic",
            fontWeight: "bold",
            textDecorationLine: ["underline", "line-through"],
            textAlign: "right"
        )
        let classes = style.toCSSClasses()
        #expect(classes.contains("gloss-font-bold"))
        #expect(classes.contains("gloss-text-underline"))
        #expect(classes.contains("gloss-text-strikethrough"))
        #expect(classes.contains("gloss-text-right"))
        #expect(classes.contains("gloss-font-italic"))
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
        #expect(html.contains("data-external=\"true\""))
        #expect(html.contains("<a class=\"gloss-link\""))
        #expect(html.contains("<span class=\"gloss-link-text\">Click me</span>"))
        #expect(html.contains("<span class=\"gloss-link-external-icon icon\""))
        #expect(!html.contains("style="))
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
        #expect(html.contains("class=\"gloss-image-container\" data-width"))
        #expect(!html.contains("<span class=\"gloss-image-sizer\"></span>"))
        #expect(html.contains("class=\"gloss-image-background\""))
        #expect(html.contains("class=\"gloss-image\""))
        #expect(html.contains("class=\"gloss-image-container-overlay\""))
        #expect(html.contains("class=\"gloss-image-link-text\""))
        #expect(html.contains("src=\"image.png\""))
        #expect(html.contains("alt=\"Test Image\""))
        #expect(html.contains("data-path=\"image.png\""))
        #expect(html.contains("data-image-load-state=\"not-loaded\""))
        #expect(html.contains("data-has-aspect-ratio=\"true\""))
        #expect(html.contains("data-aspect-ratio="))
        #expect(html.contains("style=\"padding-top:"))
        #expect(html.contains("style=\"width:"))
        #expect(!html.contains("style=\"border:"))
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
        #expect(html.contains("data-width"))
        #expect(html.contains("style=\"width:"))
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
        #expect(html.contains("data-width"))
    }

    @Test func structuredElement_toHTML_ImageWithBorderDataAttr() throws {
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
            border: "2px solid red",
            borderRadius: "5px",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("data-border=\"2px solid red\""))
        #expect(html.contains("data-border-radius=\"5px\""))
        #expect(!html.contains("style=\"border:"))
        #expect(!html.contains("style=\"border-radius:"))
    }

    @Test func structuredElement_toHTML_ImageNoStyleNoInline() throws {
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
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()
        #expect(html.contains("style=\"width: 100%; height: 100%\"")) // Essential layout only
        #expect(!html.contains("style=\"vertical-align:"))
        #expect(!html.contains("style=\"image-rendering:"))
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
        #expect(html.contains("colspan=\"2\" rowspan=\"3\">Cell Content</td>"))
        #expect(!html.contains("style="))
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
        #expect(html.contains("<details class=\"gloss-sc-details\" open>Details Content</details>"))
        #expect(html.contains("Details Content</details>"))
        #expect(!html.contains("style="))
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
        #expect(html.contains("<div class=\"gloss-sc-div\" "))
        #expect(html.contains("data-sc-id=\"123\""))
        #expect(html.contains("data-sc-type=\"example\""))
        #expect(!html.contains("style="))
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
        #expect(html == "<br class=\"gloss-sc-br\" />")

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
        #expect(hrHtml.contains("class=\"gloss-sc-hr gloss-border-partial\""))
        #expect(hrHtml.contains("<hr "))
        #expect(hrHtml.contains("/>"))
        #expect(!hrHtml.contains("data-sc-border-width=\"1px\""))
        #expect(hrHtml.contains("style=\"border-width:"))
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
        #expect(html == "<p class=\"gloss-sc-p\">This is <strong class=\"gloss-sc-strong\">Bold</strong> text.</p>")
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
        let linkStyle = ContentStyle(color: "#0000FF", textDecorationLine: ["underline"])
        let linkElement = StructuredElement(
            tag: "a",
            content: .text("link"),
            data: nil,
            style: linkStyle,
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

        let divStyle = ContentStyle(backgroundColor: "#f0f0f0", padding: "10px")
        let divElement = StructuredElement(
            tag: "div",
            content: .array([
                .text("This is a "),
                .element(linkElement),
                .text(" in a div."),
            ]),
            data: ["section": "main"],
            style: divStyle,
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
        #expect(html.contains("lang=\"en\" class=\"gloss-sc-div gloss-background gloss-padding\" style=\"background-color: #f0f0f0; padding: 10px\" data-sc-section=\"main\">"))
        #expect(html.contains("padding: 10px"))
        #expect(html.contains("style=\"background-color:"))
        #expect(html.contains("data-sc-section=\"main\""))
        #expect(html.contains("<a class=\"gloss-link gloss-text-underline\" style=\"color: #0000FF; text-decoration-line: underline\" href=\"https://example.com\" "))
        #expect(html.contains("gloss-text-underline"))
        #expect(!html.contains("style=\"color: #0000FF\""))
        #expect(!html.contains("style=\"text-decoration-line: underline\""))
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
        let formattedPaddingTop = formatNumber(expectedPaddingTop)
        #expect(html.contains("padding-top: \(formattedPaddingTop)%"))
        #expect(html.contains("width: 150px")) // Should use preferredWidth
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
        #expect(html.contains("data-border=\"1px solid red\""))
        #expect(html.contains("data-border-radius=\"5px\""))
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

        // Should include scaled width and height for em-based sizing when parameters provided
        let devicePixelRatio = 2.0
        let emSize = 14.0
        let html = element.toHTML(baseURL: nil, devicePixelRatio: devicePixelRatio, emSize: emSize)
        #expect(html.contains("data-size-units=\"em\""))
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
        let formattedWidth1 = formatNumber(expectedWidth1)
        #expect(html1.contains("width: \(formattedWidth1)px"))

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
        // Width uses the raw pixel value expressed in px for layout.
        let expectedWidth2Px = 120.0
        let formattedWidth2 = formatNumber(expectedWidth2Px)
        #expect(html2.contains("width: \(formattedWidth2)px"))
        let expectedPaddingTop2 = (80.0 / 120.0) * 100 // (height/width) * 100
        let formattedPaddingTop2 = formatNumber(expectedPaddingTop2)
        #expect(html2.contains("padding-top: \(formattedPaddingTop2)%"))
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
        // Note: StructuredElement doesn't handle descriptions - that's Definition's responsibility

        #expect(html.contains("</span>")) // Container close
        #expect(html.contains("</a>")) // Link close
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = .halfEven
        let string = formatter.string(from: NSNumber(value: value)) ?? "0"
        // Trim trailing zeros after decimal if present
        if let decimalIndex = string.firstIndex(where: { $0 == "." }) {
            let integerPart = String(string[..<decimalIndex])
            let decimalPart = String(string[string.index(after: decimalIndex)...])
            let trimmedDecimal = decimalPart.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmedDecimal.isEmpty {
                return integerPart
            } else {
                return integerPart + "." + trimmedDecimal
            }
        }
        return string
    }

    @Test func structuredElement_toHTML_ImageWithNilDimensions() throws {
        // Test that images without width/height default to 380px (converted to ~27.14em)
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "test.png",
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toHTML()

        // Default dimensions: 380px expressed in px for layout.
        let expectedWidthPx = 380.0
        let formattedWidth = formatNumber(expectedWidthPx)
        #expect(html.contains("width: \(formattedWidth)px"))

        // Aspect ratio should be 100% (square 380:380)
        #expect(html.contains("padding-top: 100%"))

        // Image attributes should use the 380px default
        #expect(html.contains("width=\"380\""))
        #expect(html.contains("height=\"380\""))
    }

    // MARK: - Anki HTML Generation Tests

    @Test func structuredElement_toAnkiHTML_ImageWithEmSizeUnits() throws {
        // Test that em-based images produce em-based CSS dimensions for Anki
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "svg-accent/平板.svg",
            width: 0.7,
            height: 1,
            title: nil,
            alt: nil,
            sizeUnits: "em",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toAnkiHTML()
        #expect(html.contains("src=\"平板.svg\""))
        #expect(html.contains("width: 0.7em"))
        #expect(html.contains("height: 1em"))
        // Should NOT have pixel-based width/height attributes
        #expect(!html.contains("width=\"0\""))
        #expect(!html.contains("height=\"1\""))
    }

    @Test func structuredElement_toAnkiHTML_ImageWithEmSizeUnitsAndPreferredDimensions() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "test.svg",
            width: 1,
            height: 2,
            preferredWidth: 0.5,
            title: nil,
            alt: nil,
            sizeUnits: "em",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toAnkiHTML()
        // preferredWidth is 0.5, aspect ratio is 2:1, so height should be 1.0
        #expect(html.contains("width: 0.5em"))
        #expect(html.contains("height: 1em"))
    }

    @Test func structuredElement_toAnkiHTML_ImageWithPixelDimensions() throws {
        // Test that pixel-based images still use width/height attributes
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "test.png",
            width: 100,
            height: 50,
            title: nil,
            alt: nil,
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toAnkiHTML()
        #expect(html.contains("width=\"100\""))
        #expect(html.contains("height=\"50\""))
        #expect(!html.contains("width:"))
        #expect(!html.contains("height:"))
    }

    @Test func structuredElement_toAnkiHTML_ImageWithVerticalAlign() throws {
        let element = StructuredElement(
            tag: "img",
            content: nil,
            data: nil,
            style: nil,
            lang: nil,
            href: nil,
            path: "test.svg",
            width: 0.7,
            height: 1,
            title: nil,
            alt: nil,
            verticalAlign: "text-bottom",
            sizeUnits: "em",
            colSpan: nil,
            rowSpan: nil,
            open: nil
        )

        let html = element.toAnkiHTML()
        #expect(html.contains("vertical-align: text-bottom"))
        #expect(html.contains("width: 0.7em"))
        #expect(html.contains("height: 1em"))
    }
}
