import Foundation
@testable import MaruReader
import Testing

struct DefinitionHTMLGenerationTests {
    @Test func textDefinition_toHTML_wrapsInParagraph() throws {
        let definition = Definition.text("Simple <text>")

        let html = definition.toHTML()

        #expect(html == "<p class=\"definition-text\">Simple &lt;text&gt;</p>")
    }

    @Test func detailedTextDefinition_toHTML_wrapsInParagraph() throws {
        let detail = DefinitionDetailed.text(TextDef(type: "text", text: "Detailed"))
        let definition = Definition.detailed(detail)

        let html = definition.toHTML()

        #expect(html == "<p class=\"definition-text\">Detailed</p>")
    }

    @Test func structuredDefinition_toHTML_delegatesToStructuredContent() throws {
        let structuredElement = StructuredElement(
            tag: "strong",
            content: .text("bold"),
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
        let structured = StructuredContentDef(type: "structured-content", content: .array([
            .text("This is "),
            .element(structuredElement),
            .text(" text."),
        ]))
        let definition = Definition.detailed(.structured(structured))

        let html = definition.toHTML()

        #expect(html == "This is <strong>bold</strong> text.")
    }

    @Test func imageDefinition_toHTML_resolvesRelativeSource() throws {
        let image = ImageDef(
            type: "image",
            path: "images/example.png",
            width: 120,
            height: 80,
            title: "Example",
            alt: "An example image",
            description: nil,
            pixelated: true,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil
        )
        let definition = Definition.detailed(.image(image))
        let baseURL = URL(string: "file:///dictionary/")

        let html = definition.toHTML(baseURL: baseURL)

        #expect(html.contains("<img"))
        #expect(html.contains("src=\"file:///dictionary/images/example.png\""))
        #expect(html.contains("width=\"120\""))
        #expect(html.contains("height=\"80\""))
        #expect(html.contains("alt=\"An example image\""))
        #expect(html.contains("title=\"Example\""))
        #expect(html.contains("style=\"image-rendering: pixelated\""))
        #expect(html.contains("/>"))
    }

    @Test func imageDefinition_toHTML_skipsAbsoluteSource() throws {
        let image = ImageDef(
            type: "image",
            path: "https://example.com/image.png",
            width: nil,
            height: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html == "<img />")
    }

    @Test func deinflectionDefinition_toHTML_rendersInformationalParagraph() throws {
        let definition = Definition.deinflection(uninflected: "食べる", rules: ["past", "polite"])

        let html = definition.toHTML()

        #expect(html == "<p class=\"deinflection\">Uninflected: 食べる (Rules: past, polite)</p>")
    }
}
