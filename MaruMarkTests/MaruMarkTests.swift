// MaruMarkTests.swift
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

@testable import MaruMark
import Testing

struct MaruMarkTests {
    @Test func renderFragmentUsesMdBookMarkdownExtensions() {
        let markdown = """
        # Heading {#custom-id}

        | A | B |
        |---|---|
        | 1 | 2 |

        ~~old~~
        """

        let html = MarkdownDocumentRenderer().renderFragment(markdown: markdown)

        #expect(html.contains("<h1 id=\"custom-id\">Heading</h1>"))
        #expect(html.contains("<table>"))
        #expect(html.contains("<del>old</del>"))
    }

    @Test func renderDocumentAppliesDisplayStylesAndTheme() {
        let renderer = MarkdownDocumentRenderer(
            styles: MarkdownDisplayStyles(fontFamily: "Test Font, sans-serif", contentFontSize: 1.25),
            webTheme: MarkdownWebTheme(textColor: "#111111", backgroundColor: "#eeeeee")
        )

        let html = renderer.renderDocument(markdown: "# Title", title: "A <Title>")

        #expect(html.contains("<title>A &lt;Title&gt;</title>"))
        #expect(html.contains("--font-family: Test Font, sans-serif;"))
        #expect(html.contains("--content-font-size-multiplier: 1.25;"))
        #expect(html.contains("--text-color: #111111;"))
        #expect(html.contains("<article class=\"grammar-entry\">"))
    }
}
