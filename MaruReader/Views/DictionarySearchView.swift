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
    @Published var popupContext: String?
    @Published var popupCssSelector: String?
    @Published var focusState: Bool = false
    var focusDebounceTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewState")

    let forwardTextScanChars = 15
    let highlightStyles = [
        "background-color": "yellow",
    ]

    func setNewQuery(_ newQuery: String) {
        logger.debug("Setting new query: \(newQuery)")
        self.query = newQuery
        self.showPopup = false
    }

    func hidePopup() {
        self.showPopup = false
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

    func highlightStylesAsJSObject() -> String {
        let stylePairs = highlightStyles.map { key, value in
            "'\(key)': '\(value)'"
        }
        return "{\(stylePairs.joined(separator: ", "))}"
    }
}

struct HighlightRect: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let left: Int
    let top: Int
    let right: Int
    let bottom: Int
}

struct DictionarySearchView: View {
    @StateObject private var viewState = DictionarySearchViewState()
    @State private var searchTask: Task<Void, Never>?
    @State private var page: WebPage
    @State private var isUpdatingFromNavigation = false
    @State private var highlightRects: [HighlightRect] = []
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
            onScan: { offset, context, cssSelector in
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

                    state.popupQuery = scanText
                    state.popupContext = context
                    state.popupCssSelector = cssSelector
                    state.showPopup = scanText.count > 0
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

                            page.isInspectable = true

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
                        .task {
                            logger.debug("Applying highlight for query: \(viewState.popupQuery ?? "") with CSS selector: \(viewState.popupCssSelector ?? "")")
                            _ = try? await page.callJavaScript("window.MaruReader.textHighlighting.clearAllHighlights();")
                            let highlightCallString = "window.MaruReader.textHighlighting.highlightText('\(viewState.popupQuery ?? "")', '\(viewState.popupCssSelector ?? "")', \(viewState.highlightStylesAsJSObject()));"
                            logger.debug("Highlight call string: \(highlightCallString)")
                            let highlightResult = try? await page.callJavaScript(highlightCallString)
                            guard let highlightData = highlightResult as? [String: Any],
                                  let highlightID = highlightData["highlightId"] as? String,
                                  let boundingRects = highlightData["boundingRects"] as? [[String: Int]]
                            else { return }
                            let rects = boundingRects.compactMap { dict -> HighlightRect? in
                                guard let x = dict["x"],
                                      let y = dict["y"],
                                      let width = dict["width"],
                                      let height = dict["height"],
                                      let left = dict["left"],
                                      let top = dict["top"],
                                      let right = dict["right"],
                                      let bottom = dict["bottom"]
                                else { return nil }
                                return HighlightRect(x: x, y: y, width: width, height: height, left: left, top: top, right: right, bottom: bottom)
                            }
                            self.highlightRects = rects
                            logger.debug("Applied highlight with ID \(highlightID) and rects: \(rects)")
                        }
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
