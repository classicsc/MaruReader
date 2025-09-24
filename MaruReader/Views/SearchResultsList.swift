//
//  SearchResultsList.swift
//  MaruReader
//
//  List view for displaying grouped search results with HTML rendering.
//

import SwiftUI
import WebKit

struct SearchResultsList: View {
    let groupedResults: [GroupedSearchResults]

    var body: some View {
        ScrollView {
            UnifiedSearchWebView(groupedResults: groupedResults)
                .padding()
        }
    }
}

struct UnifiedSearchWebView: View {
    let groupedResults: [GroupedSearchResults]
    @State private var contentHeight: CGFloat = 200

    private var unifiedHTML: String {
        let termGroupsHTML = groupedResults.map { termGroup in
            """
            <div class="term-group">
                <h1 class="term-header">\(escapeHTML(termGroup.displayTerm))</h1>
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    """
                    <div class="dictionary-section">
                        <h2 class="dictionary-header">\(escapeHTML(dictionaryResult.dictionaryTitle))</h2>
                        <div class="dictionary-content">
                            \(dictionaryResult.combinedHTML)
                        </div>
                    </div>
                    """
                }.joined())
            </div>
            """
        }.joined()

        return termGroupsHTML
    }

    private var htmlDocument: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 12px;
                    padding: 0;
                    line-height: 1.4;
                    font-size: 16px;
                    color: CanvasText;
                    background-color: Canvas;
                }
                .term-group {
                    margin-bottom: 20px;
                }
                .term-header {
                    font-size: 22px;
                    font-weight: 600;
                    margin: 0 0 12px 0;
                    color: CanvasText;
                }
                .dictionary-section {
                    margin-bottom: 12px;
                }
                .dictionary-header {
                    font-size: 17px;
                    font-weight: 600;
                    margin: 0 0 8px 0;
                    color: color-mix(in srgb, CanvasText 60%, transparent);
                }
                .dictionary-content {
                    margin-bottom: 8px;
                }
                .glossary-list {
                    margin: 0;
                    padding-left: 20px;
                }
                .glossary-list li {
                    margin-bottom: 8px;
                }
                .definition-text {
                    margin: 4px 0;
                }
                .deinflection {
                    font-style: italic;
                    opacity: 0.7;
                    margin: 4px 0;
                }
            </style>
        </head>
        <body>
            \(unifiedHTML)
            <script>
                function updateHeight() {
                    const height = document.body.scrollHeight;
                    window.webkit?.messageHandlers?.heightUpdate?.postMessage(height);
                }
                window.addEventListener('load', updateHeight);
                window.addEventListener('resize', updateHeight);
                updateHeight();
            </script>
        </body>
        </html>
        """
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            WebView(url: dataURL)
                .frame(height: contentHeight)
        } else {
            Text("Search results not available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private var dataURL: URL? {
        let data = htmlDocument.data(using: .utf8)
        return data?.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            .flatMap { "data:text/html;base64,\($0)" }
            .flatMap(URL.init(string:))
    }
}

#Preview {
    let sampleDefinitions = [
        Definition.text("A sample definition for testing"),
        Definition.text("Another definition to show multiple entries"),
    ]

    let sampleResult = DictionaryResults(
        dictionaryTitle: "Sample Dictionary",
        results: [],
        combinedHTML: sampleDefinitions.toHTML()
    )

    let sampleGroup = GroupedSearchResults(
        termKey: "test|テスト",
        expression: "test",
        reading: "テスト",
        dictionariesResults: [sampleResult]
    )

    return SearchResultsList(groupedResults: [sampleGroup])
        .padding()
}
