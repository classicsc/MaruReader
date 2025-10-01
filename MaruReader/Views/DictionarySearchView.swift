//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    @State private var page: WebPage
    @State private var webServerManager: WebServerManager?
    @State private var lookupHandler: DictionaryLookupRouteHandler?

    init() {
        self._page = State(initialValue: WebPage(configuration: WebPage.Configuration()))
    }

    var body: some View {
        WebView(page)
            .task {
                // Initialize and start web server
                let manager = WebServerManager()

                if manager.start() {
                    // Register route handlers
                    MediaRouteHandler.register(with: manager)
                    ResourceRouteHandler.register(with: manager)

                    if let baseURL = manager.baseURL {
                        let handler = DictionaryLookupRouteHandler(
                            searchService: DictionarySearchService(persistenceController: PersistenceController.shared),
                            baseURL: baseURL.absoluteString
                        )
                        handler.register(with: manager)

                        webServerManager = manager
                        lookupHandler = handler

                        // Load initial main page
                        let initialURL = baseURL.appendingPathComponent("/lookup/dictionarysearchview.html")
                        _ = page.load(URLRequest(url: initialURL))
                    }
                } else {
                    print("Failed to start web server for dictionary search")
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

                // Cleanup: stop server when view disappears
                webServerManager?.stop()
            }
    }
}

#Preview {
    DictionarySearchView()
}
