//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    @State private var page: WebPage

    init() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = DictionaryLookupURLSchemeHandler()
        self._page = State(initialValue: WebPage(configuration: config))
    }

    var body: some View {
        WebView(page)
            .task {
                // Load initial main page
                if let url = URL(string: "marureader-lookup://dictionarysearch/dictionarysearchview.html") {
                    _ = page.load(URLRequest(url: url))
                }

                // Ensure the view is inspectable when debugging
                #if DEBUG
                    page.isInspectable = true
                #endif

                // Listen for navigation events
                do {
                    for try await navigation in page.navigations {
                        if case .finished = navigation {
                            // Navigation handling can be added here if needed
                        }
                    }
                } catch {
                    // Navigation sequence ended or failed - this is expected
                }
            }
    }
}

#Preview {
    DictionarySearchView()
}
