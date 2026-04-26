// MaruMark.swift
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

public struct MarkdownDisplayStyles: Sendable, Equatable {
    public let fontFamily: String
    public let contentFontSize: Double

    public init(fontFamily: String, contentFontSize: Double) {
        self.fontFamily = fontFamily
        self.contentFontSize = contentFontSize
    }

    public static let `default` = MarkdownDisplayStyles(
        fontFamily: "Hiragino Sans, HelveticaNeue, Helvetica, Arial, sans-serif",
        contentFontSize: 1.0
    )
}

public struct MarkdownWebTheme: Sendable, Equatable {
    public let colorScheme: String?
    public let textColor: String?
    public let backgroundColor: String?
    public let interfaceBackgroundColor: String?
    public let accentColor: String?
    public let linkColor: String?
    public let glossImageBackgroundColor: String?

    public init(
        colorScheme: String? = nil,
        textColor: String? = nil,
        backgroundColor: String? = nil,
        interfaceBackgroundColor: String? = nil,
        accentColor: String? = nil,
        linkColor: String? = nil,
        glossImageBackgroundColor: String? = nil
    ) {
        self.colorScheme = colorScheme
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.interfaceBackgroundColor = interfaceBackgroundColor
        self.accentColor = accentColor
        self.linkColor = linkColor
        self.glossImageBackgroundColor = glossImageBackgroundColor
    }
}

public struct MarkdownDocumentRenderer: Sendable {
    public let styles: MarkdownDisplayStyles
    public let webTheme: MarkdownWebTheme?

    public init(
        styles: MarkdownDisplayStyles = .default,
        webTheme: MarkdownWebTheme? = nil
    ) {
        self.styles = styles
        self.webTheme = webTheme
    }

    public func renderFragment(markdown: String) -> String {
        renderMarkdownToHtml(markdown: markdown)
    }

    public func renderDocument(
        markdown: String,
        title: String,
        baseURL: URL? = nil
    ) -> String {
        let fragment = renderFragment(markdown: markdown)
        let baseElement = baseURL.map {
            "<base href=\"\($0.absoluteString.escapeHTMLAttribute())\">"
        } ?? ""

        return """
        <!doctype html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src marureader-grammar: data:; style-src 'unsafe-inline';">
            \(baseElement)
            <title>\(title.escapeHTMLText())</title>
            <style>
            \(Self.stylesheet(styles: styles, webTheme: webTheme))
            </style>
        </head>
        <body class="grammar-entry-body">
            <article class="grammar-entry">
            \(fragment)
            </article>
        </body>
        </html>
        """
    }

    public static func stylesheet(
        styles: MarkdownDisplayStyles = .default,
        webTheme: MarkdownWebTheme? = nil
    ) -> String {
        let colorScheme = webTheme?.colorScheme?.cssDeclarationValue()
        let textColor = webTheme?.textColor?.cssDeclarationValue()
        let backgroundColor = webTheme?.backgroundColor?.cssDeclarationValue()
        let interfaceBackgroundColor = webTheme?.interfaceBackgroundColor?.cssDeclarationValue()
        let accentColor = webTheme?.accentColor?.cssDeclarationValue()
        let linkColor = webTheme?.linkColor?.cssDeclarationValue()
        let glossImageBackgroundColor = webTheme?.glossImageBackgroundColor?.cssDeclarationValue()

        return """
        :root {
            color-scheme: \(colorScheme ?? "light dark");
            --font-family: \(styles.fontFamily.cssDeclarationValue());
            --content-font-size-multiplier: \(styles.contentFontSize);
            --text-color: \(textColor ?? "CanvasText");
            --background-color: \(backgroundColor ?? "Canvas");
            --interface-background-color: \(interfaceBackgroundColor ?? "var(--background-color)");
            --accent-color: \(accentColor ?? "AccentColor");
            --link-color: \(linkColor ?? "var(--accent-color)");
            --gloss-image-background-color: \(glossImageBackgroundColor ?? "Canvas");
            --text-color-light1: color-mix(in srgb, var(--text-color) 70%, transparent);
            --text-color-light2: color-mix(in srgb, var(--text-color) 50%, transparent);
            --background-color-dark1: color-mix(in srgb, var(--background-color) 90%, var(--text-color) 10%);
            --border-radius-base: 0.375rem;
            --line-height: 1.5;
        }

        html {
            -webkit-text-size-adjust: 100%;
        }

        body.grammar-entry-body {
            margin: 0;
            padding: 0.75em;
            font-family: var(--font-family, Hiragino Sans, HelveticaNeue, Helvetica, Arial, sans-serif);
            font-size: calc(1em * var(--content-font-size-multiplier, 1.0));
            line-height: var(--line-height);
            color: var(--text-color);
            background-color: var(--interface-background-color, var(--background-color));
        }

        .grammar-entry {
            max-width: 72ch;
            margin: 0 auto;
        }

        .grammar-entry > :first-child {
            margin-top: 0;
        }

        .grammar-entry h1,
        .grammar-entry h2,
        .grammar-entry h3,
        .grammar-entry h4,
        .grammar-entry h5,
        .grammar-entry h6 {
            line-height: 1.2;
            margin: 1.2em 0 0.45em;
            color: var(--text-color);
        }

        .grammar-entry h1 {
            font-size: 1.5em;
            font-weight: 650;
        }

        .grammar-entry h2 {
            font-size: 1.25em;
            font-weight: 650;
        }

        .grammar-entry p,
        .grammar-entry ul,
        .grammar-entry ol,
        .grammar-entry dl,
        .grammar-entry pre,
        .grammar-entry table,
        .grammar-entry blockquote {
            margin: 0.75em 0;
        }

        .grammar-entry a {
            color: var(--link-color);
        }

        .grammar-entry img {
            max-width: 100%;
            height: auto;
            background: var(--gloss-image-background-color);
        }

        .grammar-entry pre,
        .grammar-entry code {
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: 0.92em;
        }

        .grammar-entry pre {
            overflow-x: auto;
            padding: 0.75em;
            border-radius: var(--border-radius-base);
            background: var(--background-color-dark1);
        }

        .grammar-entry blockquote {
            padding-left: 0.85em;
            border-left: 3px solid var(--text-color-light2);
            color: var(--text-color-light1);
        }

        .grammar-entry table {
            display: block;
            width: 100%;
            overflow-x: auto;
            border-collapse: collapse;
        }

        .grammar-entry th,
        .grammar-entry td {
            padding: 0.35em 0.55em;
            border: 1px solid var(--text-color-light2);
            vertical-align: top;
        }

        .grammar-entry th {
            background: var(--background-color-dark1);
            font-weight: 600;
        }

        .grammar-entry .footnote-definition {
            color: var(--text-color-light1);
            font-size: 0.92em;
        }
        """
    }
}

private extension String {
    func escapeHTMLText() -> String {
        var result = replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    func escapeHTMLAttribute() -> String {
        var result = escapeHTMLText()
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }

    func cssDeclarationValue() -> String {
        filter { character in
            !character.isNewline
                && character != ";"
                && character != "{"
                && character != "}"
                && character != "<"
                && character != ">"
        }
    }
}
