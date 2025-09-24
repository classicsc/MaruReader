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
            preferredWidth: nil,
            preferredHeight: nil,
            title: "Example",
            alt: "An example image",
            description: nil,
            pixelated: true,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
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
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html == "<img width=\"100\" height=\"100\" />")
    }

    @Test func deinflectionDefinition_toHTML_rendersInformationalParagraph() throws {
        let definition = Definition.deinflection(uninflected: "食べる", rules: ["past", "polite"])

        let html = definition.toHTML()

        #expect(html == "<p class=\"deinflection\">Uninflected: 食べる (Rules: past, polite)</p>")
    }

    // MARK: - Responsive Sizing Tests

    @Test func imageDefinition_toHTML_preferredWidthOnlyMaintainsAspectRatio() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
            height: 100,
            preferredWidth: 150,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        // Should use preferredWidth=150 and calculate height=75 (maintaining 2:1 aspect ratio)
        #expect(html.contains("width=\"150\""))
        #expect(html.contains("height=\"75\""))
    }

    @Test func imageDefinition_toHTML_preferredHeightOnlyCalculatesWidth() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
            height: 100,
            preferredWidth: nil,
            preferredHeight: 60,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        // Should calculate width=120 from preferredHeight=60 (maintaining 2:1 aspect ratio)
        #expect(html.contains("width=\"120\""))
        #expect(html.contains("height=\"60\""))
    }

    @Test func imageDefinition_toHTML_bothPreferredDimensionsUsesNewAspectRatio() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
            height: 100,
            preferredWidth: 180,
            preferredHeight: 90,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        // Should use preferredWidth=180 and calculate height from preferred aspect ratio (90/180 = 0.5)
        #expect(html.contains("width=\"180\""))
        #expect(html.contains("height=\"90\""))
    }

    // MARK: - CSS Styling Tests

    @Test func imageDefinition_toHTML_verticalAlignAppliesStyle() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: "middle",
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("style=\"vertical-align: middle\""))
    }

    @Test func imageDefinition_toHTML_borderAppliesStyle() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: "2px solid red",
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("style=\"border: 2px solid red\""))
    }

    @Test func imageDefinition_toHTML_borderRadiusAppliesStyle() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: "8px",
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("style=\"border-radius: 8px\""))
    }

    @Test func imageDefinition_toHTML_combinedStylesJoinCorrectly() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: true,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: "top",
            border: "1px solid blue",
            borderRadius: "4px",
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        let styleAttribute = html.components(separatedBy: "style=\"")[1].components(separatedBy: "\"")[0]
        #expect(styleAttribute.contains("image-rendering: pixelated"))
        #expect(styleAttribute.contains("vertical-align: top"))
        #expect(styleAttribute.contains("border: 1px solid blue"))
        #expect(styleAttribute.contains("border-radius: 4px"))
    }

    // MARK: - Size Units Tests

    @Test func imageDefinition_toHTML_sizeUnitsEmAppliesEmSizing() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 120,
            height: 80,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: "em"
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("width=\"120\"")) // HTML attributes still use pixel values
        #expect(html.contains("height=\"80\""))
        #expect(html.contains("width: 120em")) // CSS style uses em
        #expect(html.contains("height: 80em"))
    }

    @Test func imageDefinition_toHTML_sizeUnitsEmWithPreferredDimensions() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
            height: 100,
            preferredWidth: 150,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: "em"
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        // Should use preferredWidth=150 and calculated height=75
        #expect(html.contains("width=\"150\""))
        #expect(html.contains("height=\"75\""))
        #expect(html.contains("width: 150em"))
        #expect(html.contains("height: 75em"))
    }

    @Test func imageDefinition_toHTML_sizeUnitsPxDoesNotApplyEmStyles() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: "px"
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("width=\"100\""))
        #expect(html.contains("height=\"100\""))
        #expect(!html.contains("width: 100em")) // Should NOT have em in CSS
        #expect(!html.contains("height: 100em"))
    }

    // MARK: - Description Tests

    @Test func imageDefinition_toHTML_rendersDescriptionAsVisibleText() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: "This is a visible description",
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("<img"))
        #expect(html.contains("width=\"100\""))
        #expect(html.contains("height=\"100\""))
        #expect(html.contains("<span class=\"image-description\">This is a visible description</span>"))
    }

    @Test func imageDefinition_toHTML_noDescriptionRendersImageOnly() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: nil,
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html == "<img src=\"image.png\" width=\"100\" height=\"100\" />")
        #expect(!html.contains("image-description"))
    }

    @Test func imageDefinition_toHTML_descriptionEscapesHTMLCharacters() throws {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: "Description with <HTML> & \"quotes\"",
            pixelated: nil,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("Description with &lt;HTML&gt; &amp; &quot;quotes&quot;"))
        #expect(!html.contains("Description with <HTML> & \"quotes\"")) // Should NOT contain unescaped HTML
    }

    @Test func imageDefinition_toHTML_yomitanExampleCase() throws {
        // Test case based on the Yomitan example: gazou definition with pixelated image and description
        let image = ImageDef(
            type: "image",
            path: "image.gif",
            width: 350,
            height: 350,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: "gazou definition 2",
            pixelated: true,
            imageRendering: nil,
            appearance: nil,
            background: nil,
            collapsed: nil,
            collapsible: nil,
            verticalAlign: nil,
            border: nil,
            borderRadius: nil,
            sizeUnits: nil
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML()

        #expect(html.contains("width=\"350\""))
        #expect(html.contains("height=\"350\""))
        #expect(html.contains("style=\"image-rendering: pixelated\""))
        #expect(html.contains("<span class=\"image-description\">gazou definition 2</span>"))
    }
}
