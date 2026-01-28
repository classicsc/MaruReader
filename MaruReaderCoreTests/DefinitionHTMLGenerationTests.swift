// DefinitionHTMLGenerationTests.swift
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

struct DefinitionHTMLGenerationTests {
    @Test func textDefinition_toHTML_wrapsInParagraph() {
        let definition = Definition.text("Simple <text>")

        let html = definition.toHTML()

        #expect(html == "<p class=\"gloss-definition-text\">Simple &lt;text&gt;</p>")
    }

    @Test func detailedTextDefinition_toHTML_wrapsInParagraph() {
        let detail = DefinitionDetailed.text(TextDef(type: "text", text: "Detailed"))
        let definition = Definition.detailed(detail)

        let html = definition.toHTML()

        #expect(html == "<p class=\"gloss-definition-text\">Detailed</p>")
    }

    @Test func structuredDefinition_toHTML_delegatesToStructuredContent() {
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

        #expect(html == "This is <strong class=\"gloss-sc-strong\">bold</strong> text.")
    }

    @Test func imageDefinition_toHTML_resolvesRelativeSource() {
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

        #expect(html.contains("<div class=\"gloss-image-def\">"))
        #expect(html.contains("<a class=\"gloss-image-link\""))
        #expect(html.contains("data-path=\"images/example.png\""))
        #expect(html.contains("data-image-load-state=\"not-loaded\""))
        #expect(html.contains("data-has-aspect-ratio=\"true\""))
        #expect(html.contains("data-image-rendering=\"pixelated\""))
        #expect(html.contains("<span class=\"gloss-image-container\" data-width=\"120px\""))
        #expect(html.contains("title=\"Example\""))
        #expect(html.contains("data-aspect-ratio=\"66.6667\""))
        #expect(html.contains("<span class=\"gloss-image-sizer\" style=\"padding-top: 66.6667%\">"))
        #expect(html.contains("<span class=\"gloss-image-background\"></span>"))
        #expect(html.contains("<span class=\"gloss-image-container-overlay\"></span>"))
        #expect(html.contains("<img class=\"gloss-image\" src=\"file:///dictionary/images/example.png\" style=\"width: 100%; height: 100%\" width=\"120\" height=\"80\" alt=\"An example image\" />"))
        #expect(html.contains("<span class=\"gloss-image-link-text\">Image</span>"))
        #expect(html.contains("</div>"))
        #expect(!html.contains("style=\"border:"))
        #expect(html.contains("style=\"width: 120px\""))
    }

    @Test func imageDefinition_toHTML_skipsAbsoluteSource() {
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

        #expect(html.contains("<div class=\"gloss-image-def\">"))
        #expect(html.contains("<a class=\"gloss-image-link\""))
        #expect(html.contains("data-path=\"https://example.com/image.png\""))
        #expect(html.contains("data-image-load-state=\"not-loaded\""))
        #expect(!html.contains("src="))
        #expect(html.contains("</div>"))
        #expect(!html.contains("style=\"border:"))
    }

    @Test func deinflectionDefinition_toHTML_rendersInformationalParagraph() {
        let definition = Definition.deinflection(uninflected: "食べる", rules: ["past", "polite"])

        let html = definition.toHTML()

        #expect(html == "<p class=\"gloss-deinflection\" data-uninflected=\"食べる\" data-rules=\"past, polite\">Uninflected: 食べる (Rules: past, polite)</p>")
    }

    @Test func arrayOfDefinitions_toHTML_wrapsInGlossaryList() {
        let defs: [Definition] = [
            .text("First definition"),
            .text("Second definition"),
        ]

        let html = defs.toHTML()

        #expect(html.contains("<ul class=\"gloss-glossary-list\""))
    }

    @Test func imageDefinition_toHTML_rendersDescriptionWrapper() {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: "Description text",
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

        #expect(html.contains("<div class=\"gloss-image-def\">"))
        #expect(html.contains("<span class=\"gloss-image-desc\">Description text</span>"))
        #expect(html.contains("</div>"))
    }

    @Test func imageDefinition_toHTML_noDescriptionUsesSimpleWrapper() {
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

        #expect(html.contains("<div class=\"gloss-image-def\">"))
        #expect(!html.contains("class=\"gloss-image-desc\""))
        #expect(html.contains("</div>"))
    }

    @Test func imageDefinition_toHTML_descriptionEscapesHTML() {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 100,
            height: 100,
            preferredWidth: nil,
            preferredHeight: nil,
            title: nil,
            alt: nil,
            description: "Desc with <script> & \"quote\"",
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

        #expect(html.contains("<span class=\"gloss-image-desc\">Desc with &lt;script&gt; &amp; &quot;quote&quot;</span>"))
        #expect(!html.contains("<script>"))
    }

    // MARK: - Responsive Sizing Tests

    @Test func imageDefinition_toHTML_preferredWidthOnlyMaintainsAspectRatio() {
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
        #expect(html.contains("data-width=\"150px\""))
        #expect(html.contains("data-aspect-ratio=\"50\""))
    }

    @Test func imageDefinition_toHTML_preferredHeightOnlyCalculatesWidth() {
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
        #expect(html.contains("data-width=\"120px\""))
        #expect(html.contains("data-aspect-ratio=\"50\""))
    }

    @Test func imageDefinition_toHTML_bothPreferredDimensionsUsesNewAspectRatio() {
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
        #expect(html.contains("data-width=\"180px\""))
        #expect(html.contains("data-aspect-ratio=\"50\""))
    }

    // MARK: - CSS Styling Tests

    @Test func imageDefinition_toHTML_verticalAlignAppliesDataAttr() {
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

        #expect(html.contains("data-vertical-align=\"middle\""))
        #expect(html.contains("style=\"width: 100%; height: 100%\""))
        #expect(!html.contains("vertical-align: middle"))
    }

    @Test func imageDefinition_toHTML_borderAppliesDataAttr() {
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

        #expect(html.contains("data-border=\"2px solid red\""))
        #expect(html.contains("data-width=\"100px\""))
        #expect(!html.contains("style=\"border:"))
    }

    @Test func imageDefinition_toHTML_borderRadiusAppliesDataAttr() {
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

        #expect(html.contains("data-border-radius=\"8px\""))
        #expect(html.contains("data-width=\"100px\""))
        #expect(!html.contains("style=\"border-radius:"))
    }

    @Test func imageDefinition_toHTML_combinedDataAttrs() {
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

        #expect(html.contains("class=\"gloss-image-container\" data-border=\"1px solid blue\" data-border-radius=\"4px\" data-width=\"100px\""))
        #expect(html.contains("style=\"width: 100%; height: 100%\""))
        #expect(html.contains("data-vertical-align=\"top\""))
        #expect(!html.contains("style=\"image-rendering:"))
        #expect(!html.contains("style=\"vertical-align:"))
    }

    // MARK: - Size Units Tests

    @Test func imageDefinition_toHTML_sizeUnitsEmAppliesEmSizing() {
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
        #expect(html.contains("data-size-units=\"em\"")) // Should be present for CSS font-size override
        #expect(html.contains("data-width=\"120em\""))
    }

    @Test func imageDefinition_toHTML_sizeUnitsEmWithPreferredDimensions() {
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
        #expect(html.contains("data-size-units=\"em\""))
        #expect(html.contains("data-width=\"150em\""))
    }

    @Test func imageDefinition_toHTML_sizeUnitsPxDoesNotApplyEmStyles() {
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
        #expect(html.contains("style=\"width: 100px\""))
    }

    // MARK: - Description Tests

    @Test func imageDefinition_toHTML_rendersDescriptionAsVisibleText() {
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

        #expect(html.contains("<a class=\"gloss-image-link\""))
        #expect(html.contains("<span class=\"gloss-image-desc\">This is a visible description</span>"))
    }

    @Test func imageDefinition_toHTML_noDescriptionRendersImageOnly() {
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

        #expect(html.contains("<a class=\"gloss-image-link\""))
        #expect(!html.contains("gloss-image-description"))
    }

    @Test func imageDefinition_toHTML_descriptionEscapesHTMLCharacters() {
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

        #expect(html.contains("<span class=\"gloss-image-desc\">Description with &lt;HTML&gt; &amp; &quot;quotes&quot;</span>"))
        #expect(!html.contains("Description with <HTML> & \"quotes\"")) // Should NOT contain unescaped HTML
    }

    @Test func imageDefinition_toHTML_yomitanExampleCase() {
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
        #expect(html.contains("data-image-rendering=\"pixelated\""))
        #expect(html.contains("<span class=\"gloss-image-desc\">gazou definition 2</span>"))
        #expect(html.contains("<span class=\"gloss-image-sizer\""))
        #expect(html.contains("<span class=\"gloss-image-background\"></span>"))
        #expect(html.contains("<span class=\"gloss-image-container-overlay\"></span>"))
    }

    // MARK: - Enhanced Sizing Algorithm Tests

    @Test func imageDefinition_toHTML_devicePixelRatioScalingWithEmUnits() {
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

        let html = definition.toHTML(devicePixelRatio: 3.0, baseFontSize: 16.0)

        // With device pixel ratio scaling: finalWidth=150, scaleFactor=2*3.0=6.0, baseFontSize=16.0
        // scaledWidth = 150 * 16.0 * 6.0 = 14400
        // scaledHeight = 14400 * (100/200) = 7200 (maintaining 2:1 aspect ratio)
        #expect(html.contains("width=\"14400\""))
        #expect(html.contains("height=\"7200\""))
        #expect(html.contains("style=\"width: 150em\""))
    }

    @Test func imageDefinition_toHTML_usesPixelWidthForLayoutWithCustomBaseFontSize() {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
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

        let html = definition.toHTML(devicePixelRatio: 2.0, baseFontSize: 18.0)

        // Width uses the raw pixel value expressed in px for layout when sizeUnits is not "em".
        #expect(html.contains("width=\"200\""))
        #expect(html.contains("height=\"100\""))
        #expect(html.contains("style=\"width: 200px\""))
    }

    @Test func imageDefinition_toHTML_preferredDimensionsWithoutSizeUnitsUsePx() {
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
            sizeUnits: nil // No explicit size units, so use pixel dimensions
        )
        let definition = Definition.detailed(.image(image))

        let html = definition.toHTML(devicePixelRatio: 2.0, baseFontSize: 14.0)

        // Should use px units when sizeUnits is not explicitly "em"
        #expect(html.contains("style=\"width: 150px\""))
    }

    @Test func imageDefinition_toHTML_noDevicePixelRatioScalingWithoutEmAndPreferredDimensions() {
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

        let html = definition.toHTML(devicePixelRatio: 4.0, baseFontSize: 12.0)

        // No device pixel ratio scaling because sizeUnits != "em" and no preferred dimensions
        #expect(html.contains("width=\"100\""))
        #expect(html.contains("height=\"100\""))
        // Width uses the raw pixel value expressed in px for layout when sizeUnits is not "em".
        #expect(html.contains("style=\"width: 100px\""))
    }

    @Test func imageDefinition_toHTML_devicePixelRatioScalingWithPreferredHeightOnly() {
        let image = ImageDef(
            type: "image",
            path: "image.png",
            width: 200,
            height: 100,
            preferredWidth: nil,
            preferredHeight: 80,
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

        let html = definition.toHTML(devicePixelRatio: 2.5, baseFontSize: 15.0)

        // With device pixel ratio scaling:
        // finalWidth = 80 / (100/200) = 160 (calculated from preferred height maintaining aspect ratio)
        // scaleFactor = 2 * 2.5 = 5.0, baseFontSize = 15.0
        // scaledWidth = 160 * 15.0 * 5.0 = 12000
        // scaledHeight = 12000 * (100/200) = 6000
        #expect(html.contains("width=\"12000\""))
        #expect(html.contains("height=\"6000\""))
        #expect(html.contains("style=\"width: 160em\""))
    }

    @Test func imageDefinition_toHTML_matchingYomitanScaling() {
        // Test case matching Yomitan's exact behavior from structured-content-generator.js:154-163
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

        // Using Yomitan's default values: emSize=14, devicePixelRatio=2.0
        let html = definition.toHTML(devicePixelRatio: 2.0, baseFontSize: 14.0)

        // Yomitan calculation: scaleFactor = 2 * 2.0 = 4.0
        // image.width = usedWidth * emSize * scaleFactor = 150 * 14 * 4 = 8400
        // image.height = image.width * invAspectRatio = 8400 * 0.5 = 4200
        #expect(html.contains("width=\"8400\""))
        #expect(html.contains("height=\"4200\""))
        #expect(html.contains("style=\"width: 150em\""))
    }
}
