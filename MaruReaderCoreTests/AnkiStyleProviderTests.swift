// AnkiStyleProviderTests.swift
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

struct AnkiStyleProviderTests {
    // MARK: - Base Styles Tests

    @Test func baseStylesCSS_containsImageContainerStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        // Uses CSS nesting, so outer scope contains inner rules
        #expect(css.hasPrefix(".yomitan-glossary {"))
        #expect(css.contains(".gloss-image-container"))
        #expect(css.contains("display: inline-block"))
        #expect(css.contains("max-width: 100%"))
    }

    @Test func baseStylesCSS_containsImageLinkStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-image-link"))
        #expect(css.contains("cursor: inherit"))
    }

    @Test func baseStylesCSS_containsImageStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-image"))
        #expect(css.contains("object-fit: contain"))
    }

    @Test func baseStylesCSS_containsTableStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-sc-table-container"))
        #expect(css.contains(".gloss-sc-table"))
        #expect(css.contains("border-collapse: collapse"))
    }

    @Test func baseStylesCSS_containsCellStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-sc-th"))
        #expect(css.contains(".gloss-sc-td"))
        #expect(css.contains("border-style: solid"))
        #expect(css.contains("padding: 0.25em"))
    }

    @Test func baseStylesCSS_containsListStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-sc-ol"))
        #expect(css.contains(".gloss-sc-ul"))
        #expect(css.contains("padding-left: 2em"))
    }

    @Test func baseStylesCSS_containsLinkStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-link"))
        #expect(css.contains("text-decoration: underline"))
    }

    @Test func baseStylesCSS_containsPixelatedImageStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains("[data-image-rendering=pixelated]"))
        #expect(css.contains("image-rendering: pixelated"))
    }

    @Test func baseStylesCSS_containsVerticalAlignStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains("[data-vertical-align=baseline]"))
        #expect(css.contains("[data-vertical-align=middle]"))
        #expect(css.contains("[data-vertical-align=top]"))
    }

    @Test func baseStylesCSS_containsCollapsedImageStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains("[data-collapsed=true]"))
        #expect(css.contains(".gloss-image-link-text"))
    }

    @Test func baseStylesCSS_containsTextStylingClasses() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-font-bold"))
        #expect(css.contains(".gloss-font-italic"))
        #expect(css.contains(".gloss-text-underline"))
        #expect(css.contains(".gloss-text-center"))
    }

    @Test func baseStylesCSS_containsRubyStyles() {
        let css = AnkiStyleProvider.baseStylesCSS()

        #expect(css.contains(".gloss-sc-ruby"))
        #expect(css.contains(".gloss-sc-rt"))
        #expect(css.contains(".gloss-sc-rp"))
    }

    @Test func baseStylesCSS_scopedWithYomitanGlossary() {
        let css = AnkiStyleProvider.baseStylesCSS()

        // CSS nesting format: starts with .yomitan-glossary { and ends with }
        #expect(css.hasPrefix(".yomitan-glossary {"))
        #expect(css.hasSuffix("}"))
    }

    // MARK: - Dictionary Scoping Tests

    @Test func scopedDictionaryCSS_returnsNilForNonExistentDictionary() {
        let result = AnkiStyleProvider.scopedDictionaryCSS(
            dictionaryUUID: UUID(),
            dictionaryTitle: "NonExistent"
        )

        #expect(result == nil)
    }

    // MARK: - Style Tag Generation Tests

    @Test func generateStyleTag_emptyDictionaries_returnsBaseStylesOnly() {
        let styleTag = AnkiStyleProvider.generateStyleTag(dictionaryResults: [])

        #expect(styleTag.hasPrefix("<style>"))
        #expect(styleTag.hasSuffix("</style>"))
        #expect(styleTag.contains(".yomitan-glossary"))
        #expect(styleTag.contains(".gloss-image-container"))
    }

    @Test func generateStyleTag_withDictionaries_includesBaseStyles() {
        let dictionaries = [
            (uuid: UUID(), title: "TestDict1"),
            (uuid: UUID(), title: "TestDict2"),
        ]

        let styleTag = AnkiStyleProvider.generateStyleTag(dictionaryResults: dictionaries)

        #expect(styleTag.hasPrefix("<style>"))
        #expect(styleTag.hasSuffix("</style>"))
        // With CSS nesting, the scope wraps the rules
        #expect(styleTag.contains(".yomitan-glossary {"))
        #expect(styleTag.contains(".gloss-image-container"))
    }

    @Test func generateStyleTag_deduplicatesSameDictionary() {
        let uuid = UUID()
        let dictionaries = [
            (uuid: uuid, title: "SameDict"),
            (uuid: uuid, title: "SameDict"),
            (uuid: uuid, title: "SameDict"),
        ]

        let styleTag = AnkiStyleProvider.generateStyleTag(dictionaryResults: dictionaries)

        // Should still work without issues (deduplication happens internally)
        #expect(styleTag.hasPrefix("<style>"))
        #expect(styleTag.hasSuffix("</style>"))
    }

    @Test func generateStyleTag_formatIsValid() {
        let styleTag = AnkiStyleProvider.generateStyleTag(dictionaryResults: [])

        // Should have proper HTML structure
        #expect(styleTag.hasPrefix("<style>\n"))
        #expect(styleTag.hasSuffix("\n</style>"))

        // Should contain CSS content
        let cssContent = styleTag
            .replacingOccurrences(of: "<style>\n", with: "")
            .replacingOccurrences(of: "\n</style>", with: "")

        #expect(!cssContent.isEmpty)
    }

    // MARK: - CSS Nesting Tests

    @Test func baseStylesCSS_usesNestedCSS() {
        let css = AnkiStyleProvider.baseStylesCSS()

        // Should use CSS nesting format
        #expect(css.hasPrefix(".yomitan-glossary {"))
        // Inner rules should not have the prefix repeated
        #expect(!css.contains(".yomitan-glossary .yomitan-glossary"))
    }

    @Test func baseStylesCSS_containsDataAttributeSelectors() {
        let css = AnkiStyleProvider.baseStylesCSS()

        // Data attribute selectors are within the nested block
        #expect(css.contains(".gloss-image-link[data-has-aspect-ratio=true]"))
        #expect(css.contains(".gloss-image-link[data-size-units=em]"))
    }
}
