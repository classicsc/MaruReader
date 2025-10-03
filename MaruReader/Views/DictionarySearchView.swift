//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    @State private var query: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var page: WebPage
    @State private var isUpdatingFromNavigation = false

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    init() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = DictionaryLookupURLSchemeHandler()
        self._page = State(initialValue: WebPage(configuration: config))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search dictionary", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                    .onChange(of: query) { _, newValue in
                        performSearch(newValue)
                    }
                    .onSubmit {
                        performSearch(query)
                    }

                WebView(page)
                    .task {
                        // Load initial empty page
                        if let url = lookupURL(for: "") {
                            _ = page.load(URLRequest(url: url))
                        }

                        // Ensure the view is inspectable when debugging
                        #if DEBUG
                            page.isInspectable = true
                        #endif

                        // Listen for navigation events
                        do {
                            for try await navigation in page.navigations {
                                if case .finished = navigation, !isUpdatingFromNavigation {
                                    updateQueryFromURL()
                                }
                            }
                        } catch {
                            // Navigation sequence ended or failed - this is expected
                        }
                    }
                    .animation(.default, value: query)
                    .animation(.default, value: isUpdatingFromNavigation)
            }
            .padding(.horizontal)
            .navigationTitle("Dictionary")
        }
    }

    private func performSearch(_ searchQuery: String) {
        guard !isUpdatingFromNavigation else { return }

        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }

            // Navigate to lookup URL
            if let url = lookupURL(for: searchQuery) {
                isUpdatingFromNavigation = true
                _ = page.load(URLRequest(url: url))
                isUpdatingFromNavigation = false
            }
        }
    }

    private func lookupURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(string: "marureader-lookup://lookup/dictionarysearchview.html")
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        return URL(string: "marureader-lookup://lookup/dictionarysearchview.html?query=\(encodedQuery)&noUpdateQuery=true")
    }

    private func updateQueryFromURL() {
        guard let url = page.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let queryItem = queryItems.first(where: { $0.name == "query" }),
              let newQuery = queryItem.value
        else {
            return
        }

        guard components.queryItems?.first(where: { $0.name == "noUpdateQuery" }) == nil else {
            return
        }

        if newQuery != query {
            isUpdatingFromNavigation = true
            query = newQuery
            isUpdatingFromNavigation = false
        }
    }
}

#Preview {
    DictionarySearchView()
}
