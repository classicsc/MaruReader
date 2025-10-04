//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import SwiftUI
import WebKit

// Helper class to hold mutable state references for the scheme handler
@MainActor
class DictionarySearchViewState: ObservableObject {
    @Published var query: String = ""
    @Published var showPopup = false
    @Published var popupQuery: String?
    @Published var focusState: Bool = false
    var focusDebounceTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewState")

    let forwardTextScanChars = 15

    func setNewQuery(_ newQuery: String) {
        logger.debug("Setting new query: \(newQuery)")
        self.query = newQuery
        self.showPopup = false
    }

    func hidePopup() {
        self.showPopup = false
    }

    func setPopupQuery(_ newQuery: String?) {
        self.popupQuery = newQuery
        self.showPopup = newQuery != nil
    }

    func textFieldFocused() {
        focusDebounceTask?.cancel()
        focusState = true
    }

    func textFieldUnfocused() {
        focusDebounceTask?.cancel()
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                focusState = false
            }
        }
    }
}

struct DictionarySearchView: View {
    @StateObject private var viewState = DictionarySearchViewState()
    @State private var searchTask: Task<Void, Never>?
    @State private var page: WebPage
    @State private var isUpdatingFromNavigation = false
    @FocusState private var isTextFieldFocused: Bool

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    init() {
        // Create state object first
        let state = DictionarySearchViewState()
        self._viewState = StateObject(wrappedValue: state)

        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()

        // Create lookup handler with closures that update state
        let lookupHandler = DictionaryLookupURLSchemeHandler(
            onNavigate: { term in
                Task { @MainActor in
                    let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupURLSchemeHandler")
                    logger.debug("Navigate handler called with term: \(term)")
                    state.setNewQuery(term)
                }
            },
            onScan: { offset, context in
                Task { @MainActor in
                    let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupURLSchemeHandler")
                    // Check if within debounce window
                    if state.focusState {
                        logger.debug("Scan ignored due to debounce")
                        return
                    }

                    // If popup is visible, hide it
                    if state.showPopup {
                        logger.debug("Hiding popup")
                        state.hidePopup()
                        return
                    }

                    // Extract substring from offset to offset + forwardTextScanChars
                    let startIndex = context.index(context.startIndex, offsetBy: offset, limitedBy: context.endIndex) ?? context.startIndex
                    let endIndex = context.index(startIndex, offsetBy: state.forwardTextScanChars, limitedBy: context.endIndex) ?? context.endIndex
                    let scanText = String(context[startIndex ..< endIndex])

                    state.setPopupQuery(scanText)
                    logger.debug("Showing popup for query: \(scanText)")
                }
            }
        )
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = lookupHandler

        self._page = State(initialValue: WebPage(configuration: config))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search dictionary", text: $viewState.query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                    .focused($isTextFieldFocused)
                    .onChange(of: viewState.query) { _, newValue in
                        performSearch(newValue)
                    }
                    .onChange(of: isTextFieldFocused) { _, isFocused in
                        if isFocused {
                            viewState.textFieldFocused()
                        } else {
                            viewState.textFieldUnfocused()
                        }
                    }
                    .onSubmit {
                        performSearch(viewState.query)
                    }

                ZStack(alignment: .topLeading) {
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
                        .animation(.default, value: viewState.query)
                        .animation(.default, value: isUpdatingFromNavigation)

                    // Popup overlay
                    if viewState.showPopup {
                        DictionaryPopupView(query: $viewState.popupQuery, context: .constant(nil), onNavigate: { term in
                            Task { @MainActor in
                                let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupURLSchemeHandler")
                                logger.debug("Navigate handler called with term: \(term)")
                                viewState.setNewQuery(term)
                            }
                        })
                        .frame(width: 300, height: 400)
                        .padding()
                    }
                }
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

        if newQuery != viewState.query {
            isUpdatingFromNavigation = true
            viewState.query = newQuery
            isUpdatingFromNavigation = false
        }
    }
}

#Preview {
    DictionarySearchView()
}
