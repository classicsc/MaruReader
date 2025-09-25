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
    @State private var lastHTML: String = ""

    init() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
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

                Group {
                    if query.isEmpty {
                        ContentUnavailableView("Start typing to search", systemImage: "magnifyingglass", description: Text("Dictionary results will appear here."))
                    } else if searchViewModel.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else if let error = searchViewModel.searchError {
                        ContentUnavailableView("Search Error", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
                    } else if searchViewModel.groupedResults.isEmpty {
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No dictionary entries found for '\(query)'"))
                    } else {
                        WebView(page)
                            .task {
                                loadHTMLIfNeeded(searchViewModel.htmlDocument)
                                // Ensure the view is inspectable when debugging
                                #if DEBUG
                                    page.isInspectable = true
                                #endif
                            }
                            .onChange(of: searchViewModel.htmlDocument) { _, newHTML in
                                loadHTMLIfNeeded(newHTML)
                            }
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

    private func loadHTMLIfNeeded(_ html: String) {
        guard html != lastHTML else { return }
        lastHTML = html
        _ = page.load(html: html)
    }

    private func performSearch(_ searchQuery: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }
            await searchViewModel.search(query: searchQuery)
        }
    }
}

#Preview {
    DictionarySearchView()
}
