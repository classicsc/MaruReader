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
    @State private var isSearching: Bool = false
    @State private var searchService = DictionarySearchService()
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: Error?
    @State private var result: TextLookupResponse?
    @State private var webView: WKWebView?
    @State private var popupLookupResponse: TextLookupResponse?
    @State private var popupFrame: CGRect = .zero

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search Dictionary", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                    .onChange(of: query) { _, newValue in
                        performSearch(searchQuery: newValue)
                    }
                if query.isEmpty {
                    ContentUnavailableView("Start typing to search", systemImage: "magnifyingglass", description: Text("Dictionary results will appear here."))
                } else if isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
                } else if let error = searchError {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
                } else if let result {
                    DictionaryResultContentView(
                        lookupResponse: result,
                        searchService: searchService,
                        onPopupRequest: { lookupResponse, frame in
                            popupLookupResponse = lookupResponse
                            popupFrame = frame
                        },
                        onTermSelected: { term in
                            query = term
                            popupLookupResponse = nil
                        },
                        webViewRef: $webView
                    )
                } else {
                    ContentUnavailableView("No Results", systemImage: "xmark.circle", description: Text("No dictionary entries found for \"\(query)\"."))
                }
            }
            .padding(.horizontal)
            .navigationTitle("Dictionary")
            .overlay {
                if let popupLookupResponse {
                    GeometryReader { _ in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                self.popupLookupResponse = nil
                            }
                            .overlay(alignment: .topLeading) {
                                DictionaryPopupContentView(
                                    lookupResponse: popupLookupResponse,
                                    onTermSelected: { term in
                                        query = term
                                        self.popupLookupResponse = nil
                                    }
                                )
                                .frame(width: 300, height: 400)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 8)
                                .offset(x: popupFrame.origin.x, y: popupFrame.origin.y)
                            }
                    }
                }
            }
        }
    }

    private func performSearch(searchQuery: String) {
        guard !isSearching else { return }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // Debounce for 300ms
            if Task.isCancelled { return }
            isSearching = true
            searchError = nil
            result = nil
            do {
                let lookupRequest = TextLookupRequest(id: UUID(), offset: 0, context: searchQuery, rubyContext: nil, cssSelector: nil)
                try result = await searchService.performTextLookup(query: lookupRequest)
            } catch {
                if !Task.isCancelled {
                    searchError = error
                }
            }
            isSearching = false
        }
    }
}

#Preview {
    DictionarySearchView()
}
