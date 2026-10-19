// AnkiNotePreviewView.swift
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

import SwiftUI
import WebKit

/// A field or value as it will read in Anki: its HTML rendered where there is text, a label for
/// media-only values.
@MainActor
struct AnkiNotePreview: View {
    let html: String
    let text: String

    var body: some View {
        if !html.isEmpty {
            AnkiHTMLPreview(html: html)
        } else if text.isEmpty {
            Text(String(localized: "Empty", bundle: .dictionaryUICommon)).foregroundStyle(.tertiary)
        } else {
            Text(text)
        }
    }
}

/// Renders field HTML in a web view sized to its content. Glossary HTML carries its own styles, so
/// this shows the formatting a plain text preview drops, though not what the note type's CSS adds.
@MainActor
struct AnkiHTMLPreview: View {
    let html: String
    @State private var page = WebPage()
    @State private var height: CGFloat = 1

    var body: some View {
        WebView(page)
            .webViewContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: height)
            .task(id: html) { _ = page.load(html: Self.document(html)) }
            // The page reports its content height through its title, which the page already
            // publishes, so no message handler is needed for one number.
            .onChange(of: page.title) {
                if let reported = Double(page.title) {
                    height = reported
                }
            }
    }

    /// The script comes before the field HTML, which is unvalidated: an unclosed tag at its end
    /// would otherwise swallow whatever follows it.
    private static func document(_ body: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body { margin: 0; font: -apple-system-body; color: CanvasText; pointer-events: none; overflow-wrap: anywhere; }
        img { max-width: 100%; }
        </style>
        <script>
        new ResizeObserver(() => { document.title = document.documentElement.scrollHeight; }).observe(document.documentElement);
        </script>
        </head><body>\(body)</body></html>
        """
    }
}
