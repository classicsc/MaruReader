// AnkiStyleProvider.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// Provides CSS styles for Anki note HTML output, matching Yomitan's approach for compatibility.
///
/// This generates scoped CSS that works in Anki cards, including:
/// - Base structured-content styles (images, tables, links)
/// - Dictionary-specific stylesheets scoped to their content
public enum AnkiStyleProvider {
    // MARK: - Public API

    /// Generates the base structured-content CSS for Anki, scoped with `.yomitan-glossary`.
    ///
    /// These styles are derived from Yomitan's `structured-content-style.json` and provide
    /// essential styling for images, tables, and other structured content elements.
    public static func baseStylesCSS() -> String {
        addGlossaryScope(to: baseStyles)
    }

    /// Loads a dictionary's stylesheet and scopes it for Anki output.
    ///
    /// - Parameters:
    ///   - dictionaryUUID: The UUID of the dictionary.
    ///   - dictionaryTitle: The title of the dictionary (used in the `data-dictionary` selector).
    /// - Returns: Scoped CSS string, or `nil` if the dictionary has no stylesheet.
    public static func scopedDictionaryCSS(dictionaryUUID: UUID, dictionaryTitle: String) -> String? {
        guard let stylesheet = loadDictionaryStylesheet(dictionaryUUID: dictionaryUUID) else {
            return nil
        }

        // Sanitize to prevent script injection (GHSA-g3p8-q34q-x686)
        let sanitized = CSSSanitizer.sanitize(stylesheet)

        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        // Scope to both .yomitan-glossary and the specific dictionary
        let dictionaryScoped = addDictionaryScope(to: trimmed, dictionaryTitle: dictionaryTitle)
        return addGlossaryScope(to: dictionaryScoped)
    }

    /// Generates a combined `<style>` tag containing base styles and all dictionary-specific styles.
    ///
    /// - Parameter dictionaryResults: Array of tuples containing dictionary UUID and title.
    /// - Returns: Complete `<style>` tag HTML, or empty string if no styles are needed.
    public static func generateStyleTag(dictionaryResults: [(uuid: UUID, title: String)]) -> String {
        var styles: [String] = []

        // Add base structured-content styles
        styles.append(baseStylesCSS())

        // Add dictionary-specific styles (deduplicated)
        var seenUUIDs: Set<UUID> = []
        for (uuid, title) in dictionaryResults {
            guard seenUUIDs.insert(uuid).inserted else { continue }
            if let dictionaryCSS = scopedDictionaryCSS(dictionaryUUID: uuid, dictionaryTitle: title) {
                styles.append(dictionaryCSS)
            }
        }

        let combinedCSS = styles.joined(separator: "\n")
        guard !combinedCSS.isEmpty else { return "" }

        return "<style>\n\(combinedCSS)\n</style>"
    }

    // MARK: - Private Helpers

    /// Adds `.yomitan-glossary` scope to CSS rules using CSS nesting.
    ///
    /// This uses the modern CSS nesting feature (supported in iOS 16.4+, Anki 25.02+)
    /// which wraps all rules in a parent selector scope.
    private static func addGlossaryScope(to css: String) -> String {
        addScope(to: css, scope: ".yomitan-glossary")
    }

    /// Adds `[data-dictionary="..."]` scope to CSS rules.
    private static func addDictionaryScope(to css: String, dictionaryTitle: String) -> String {
        let escapedTitle = dictionaryTitle
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return addScope(to: css, scope: "[data-dictionary=\"\(escapedTitle)\"]")
    }

    /// Adds a scope prefix to all CSS selectors using CSS nesting.
    ///
    /// This wraps the entire CSS in a scope selector, relying on CSS nesting
    /// which is supported in modern browsers (Safari 16.4+, Chrome 112+).
    private static func addScope(to css: String, scope: String) -> String {
        let trimmed = css.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Use CSS nesting - wrap all rules inside a scope block
        return "\(scope) {\n\(trimmed)\n}"
    }

    /// Loads a dictionary's stylesheet from the app group container.
    private static func loadDictionaryStylesheet(dictionaryUUID: UUID) -> String? {
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return nil
        }

        let stylesheetURL = appGroupDir
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(dictionaryUUID.uuidString, isDirectory: true)
            .appendingPathComponent("styles.css", isDirectory: false)

        guard (try? stylesheetURL.checkResourceIsReachable()) == true else {
            return nil
        }

        guard let data = try? Data(contentsOf: stylesheetURL) else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Base Styles

    /// Base structured-content styles for Anki, derived from Yomitan's structured-content-style.json.
    ///
    /// These styles provide essential formatting for images, tables, and other structured content
    /// without relying on CSS variables that may not be defined in Anki.
    private static let baseStyles = """
    /* Image container and link styles */
    .gloss-image-container {
        display: inline-block;
        white-space: nowrap;
        max-width: 100%;
        max-height: 100vh;
        position: relative;
        vertical-align: top;
        line-height: 0;
        overflow: hidden;
        font-size: 1px;
    }

    .gloss-image-link {
        cursor: inherit;
        display: inline-block;
        position: relative;
        line-height: 1;
        max-width: 100%;
        color: inherit;
        text-decoration: none;
    }

    .gloss-image {
        display: inline-block;
        vertical-align: top;
        object-fit: contain;
        border: none;
        outline: none;
    }

    .gloss-image-link[data-has-aspect-ratio=true] .gloss-image {
        position: absolute;
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
    }

    .gloss-image-link[data-has-aspect-ratio=true] .gloss-image-sizer {
        display: inline-block;
        width: 0;
        vertical-align: top;
        font-size: 0;
    }

    .gloss-image-link-text {
        display: none;
        line-height: 1.4;
    }

    .gloss-image-link-text::before {
        content: '[';
    }

    .gloss-image-link-text::after {
        content: ']';
    }

    /* Pixelated image rendering */
    .gloss-image-link[data-image-rendering=pixelated] .gloss-image {
        image-rendering: auto;
        image-rendering: -webkit-optimize-contrast;
        image-rendering: pixelated;
        image-rendering: crisp-edges;
    }

    .gloss-image-link[data-image-rendering=crisp-edges] .gloss-image {
        image-rendering: auto;
        image-rendering: -webkit-optimize-contrast;
        image-rendering: crisp-edges;
    }

    /* Image vertical alignment */
    .gloss-image-link[data-vertical-align=baseline] { vertical-align: baseline; }
    .gloss-image-link[data-vertical-align=sub] { vertical-align: sub; }
    .gloss-image-link[data-vertical-align=super] { vertical-align: super; }
    .gloss-image-link[data-vertical-align=text-top] { vertical-align: top; }
    .gloss-image-link[data-vertical-align=text-bottom] { vertical-align: bottom; }
    .gloss-image-link[data-vertical-align=middle] { vertical-align: middle; }
    .gloss-image-link[data-vertical-align=top] { vertical-align: top; }
    .gloss-image-link[data-vertical-align=bottom] { vertical-align: bottom; }

    /* Em-based sizing */
    .gloss-image-link[data-size-units=em] .gloss-image-container {
        font-size: 1em;
    }

    /* Monochrome appearance */
    .gloss-image-link[data-appearance=monochrome] .gloss-image {
        filter: grayscale(1) opacity(0.5) drop-shadow(0 0 0.01px currentColor) drop-shadow(0 0 0.01px currentColor) saturate(1000%) brightness(1000%);
    }

    /* Collapsed images */
    .gloss-image-link[data-collapsed=true] {
        vertical-align: baseline;
    }

    .gloss-image-link[data-collapsed=true] .gloss-image-container {
        display: none;
        position: absolute;
        left: 0;
        top: 100%;
        z-index: 1;
    }

    .gloss-image-link[data-collapsed=true]:hover .gloss-image-container,
    .gloss-image-link[data-collapsed=true]:focus .gloss-image-container {
        display: block;
    }

    .gloss-image-link[data-collapsed=true] .gloss-image-link-text {
        display: inline;
    }

    /* Table styles */
    .gloss-sc-table-container {
        display: block;
        overflow-x: auto;
    }

    .gloss-sc-table {
        table-layout: auto;
        border-collapse: collapse;
    }

    .gloss-sc-thead,
    .gloss-sc-tfoot,
    .gloss-sc-th {
        font-weight: bold;
    }

    .gloss-sc-th,
    .gloss-sc-td {
        border-style: solid;
        padding: 0.25em;
        vertical-align: top;
        border-width: 1px;
        border-color: currentColor;
    }

    /* List styles */
    .gloss-sc-ol,
    .gloss-sc-ul {
        padding-left: 2em;
        margin: 0;
    }

    .gloss-sc-li {
        display: list-item;
    }

    /* Link styles */
    .gloss-link {
        color: #0066cc;
        text-decoration: underline;
    }

    .gloss-link-external-icon {
        display: none;
    }

    /* Hide background overlay for non-monochrome */
    .gloss-image-link:not([data-appearance=monochrome]) .gloss-image-background {
        display: none;
    }

    .gloss-image-background {
        position: absolute;
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
        background-color: currentColor;
        -webkit-mask-repeat: no-repeat;
        -webkit-mask-position: center center;
        -webkit-mask-size: contain;
        mask-repeat: no-repeat;
        mask-position: center center;
        mask-size: contain;
    }

    .gloss-image-container-overlay {
        position: absolute;
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
        display: table;
        table-layout: fixed;
        white-space: normal;
    }

    /* Details/Summary */
    .gloss-sc-details {
        padding-left: 1em;
    }

    .gloss-sc-summary {
        list-style-position: outside;
        cursor: pointer;
    }

    /* Ruby text */
    .gloss-sc-ruby {
        display: ruby;
    }

    .gloss-sc-rt {
        display: ruby-text;
        font-size: 0.6em;
    }

    .gloss-sc-rp {
        display: none;
    }

    /* Text styling classes */
    .gloss-font-bold { font-weight: bold; }
    .gloss-font-normal { font-weight: normal; }
    .gloss-font-italic { font-style: italic; }
    .gloss-text-underline { text-decoration-line: underline; }
    .gloss-text-overline { text-decoration-line: overline; }
    .gloss-text-strikethrough { text-decoration-line: line-through; }
    .gloss-text-center { text-align: center; }
    .gloss-text-right { text-align: right; }
    .gloss-text-justify { text-align: justify; }
    .gloss-text-nowrap { white-space: nowrap; }
    .gloss-text-pre { white-space: pre; }

    /* Vertical alignment for inline elements */
    .gloss-vertical-align-baseline { vertical-align: baseline; }
    .gloss-vertical-align-sub { vertical-align: sub; }
    .gloss-vertical-align-super { vertical-align: super; }
    .gloss-vertical-align-text-top { vertical-align: text-top; }
    .gloss-vertical-align-text-bottom { vertical-align: text-bottom; }
    .gloss-vertical-align-middle { vertical-align: middle; }
    .gloss-vertical-align-top { vertical-align: top; }
    .gloss-vertical-align-bottom { vertical-align: bottom; }
    """
}
