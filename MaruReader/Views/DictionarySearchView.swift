//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    @State private var query: String = ""
    @State private var searchViewModel = SearchViewModel()
    @State private var searchTask: Task<Void, Never>?
    @State private var page: WebPage
    @State private var isUpdatingFromNavigation = false

    init() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-textscan")!] = TextScanURLSchemeHandler()
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

                WebView(page)
                    .task {
                        // Load initial empty page
                        if let url = searchViewModel.lookupURL(for: "") {
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
                    .animation(.default, value: searchViewModel.isSearching)

                Spacer()
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
            if let url = searchViewModel.lookupURL(for: searchQuery) {
                isUpdatingFromNavigation = true
                _ = page.load(URLRequest(url: url))
                isUpdatingFromNavigation = false
            }

            // Update search state for UI feedback
            await searchViewModel.search(query: searchQuery)
        }
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
