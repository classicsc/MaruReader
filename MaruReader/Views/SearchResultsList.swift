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
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedResults) { termGroup in
                    VStack(alignment: .leading, spacing: 12) {
                        // Term header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(termGroup.displayTerm)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)

                        // Dictionary results
                        ForEach(termGroup.dictionariesResults) { dictionaryResult in
                            VStack(alignment: .leading, spacing: 8) {
                                // Dictionary header
                                Text(dictionaryResult.dictionaryTitle)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                // HTML content
                                DefinitionWebView(htmlContent: dictionaryResult.combinedHTML)
                                    .frame(minHeight: 80)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical)
        }
    }
}

struct DefinitionWebView: View {
    let htmlContent: String
    @State private var contentHeight: CGFloat = 80

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
            \(htmlContent)
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

    var body: some View {
        if #available(iOS 26.0, *) {
            WebView(url: dataURL)
                .frame(height: contentHeight)
        } else {
            // Fallback for older iOS versions
            Text("HTML content not available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
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
