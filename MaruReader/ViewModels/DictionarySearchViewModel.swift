//
//  DictionarySearchViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import Foundation
import os.log
import SwiftUI
import WebKit

enum ResultDisplayState {
    case startPage
    case noResults
    case searching
    case ready
    case error(Error)
}

// Helper class to hold mutable state references for the scheme handler
@MainActor
class DictionarySearchViewModel: ObservableObject {
    @Published var resultState: ResultDisplayState = .startPage
    @Published var showPopup = false
    @Published var popupQuery: String?
    @Published var popupContext: String?
    @Published var popupCssSelector: String?
    @Published var focusState: Bool = false
    @Published var page: WebPage = .init()
    @Published var popupPage: WebPage = .init()
    private var focusDebounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    private let searchService = DictionarySearchService()

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var lookupSchemeHandler: DictionaryLookupURLSchemeHandler?

    let forwardTextScanChars = 15
    let highlightStyles = [
        "background-color": "yellow",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewModel")

    init() {
        initializeWebPage()
        initializePopupPage()
    }

    private func initializeWebPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler

        // Create lookup handler with closures that update state
        let lookupHandler = DictionaryLookupURLSchemeHandler(
            onNavigate: { term in
                Task { @MainActor in
                    self.performSearch(term)
                }
            },
            onScan: { offset, context, cssSelector in
                Task { @MainActor in
                    self.handleTextScan(offset, context: context, cssSelector: cssSelector)
                }
            }
        )
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = lookupHandler
        page = WebPage(configuration: config)
        page.isInspectable = true
    }

    private func initializePopupPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler

        let lookupHandler = DictionaryLookupURLSchemeHandler(
            onNavigate: { term in
                Task { @MainActor in
                    self.performSearch(term)
                }
            }
        )

        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = lookupHandler
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
        if let url = popupURL(for: "") {
            _ = popupPage.load(URLRequest(url: url))
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

    private func popupURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(string: "marureader-lookup://lookup/popup.html")
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        return URL(string: "marureader-lookup://lookup/popup.html?query=\(encodedQuery)")
    }

    func performSearch(_ searchQuery: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }

            guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    self.resultState = .startPage
                }
                return
            }

            let updateTask = Task { @MainActor in
                self.resultState = .searching
            }
            let lookupRequest = TextLookupRequest(context: searchQuery)
            do {
                guard let searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                    await MainActor.run {
                        self.resultState = .noResults
                    }
                    return
                }
                await updateTask.value
                let loadSequence = page.load(html: searchResults.toResultsHTML())
                for try await value in loadSequence {
                    if Task.isCancelled { return }
                    if value == WebPage.NavigationEvent.finished {
                        self.resultState = .ready
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    self.resultState = .error(error)
                }
                self.logger.error("Search error: \(error.localizedDescription)")
                return
            }
        }
    }

    func searchInPopup(_ query: String?) {
        guard let query else {
            if let url = popupURL(for: "") {
                page.load(URLRequest(url: url))
            }
            return
        }

        if let url = popupURL(for: query) {
            popupPage.load(URLRequest(url: url))
        } else {
            logger.error("Failed to create popup URL for query: \(query)")
        }
    }

    func handleTextScan(_ offset: Int, context: String, cssSelector: String) {
        // Check if within debounce window
        if self.focusState {
            logger.debug("Scan ignored due to debounce")
            return
        }

        // If popup is visible, hide it
        if self.showPopup {
            logger.debug("Hiding popup")
            self.hidePopup()
            return
        }

        // Extract substring from offset to offset + forwardTextScanChars
        let startIndex = context.index(context.startIndex, offsetBy: offset, limitedBy: context.endIndex) ?? context.startIndex
        let endIndex = context.index(startIndex, offsetBy: self.forwardTextScanChars, limitedBy: context.endIndex) ?? context.endIndex
        let scanText = String(context[startIndex ..< endIndex])

        self.popupQuery = scanText
        self.popupContext = context
        self.popupCssSelector = cssSelector
        self.searchInPopup(popupQuery)
        self.showPopup = scanText.count > 0
        Task { @MainActor in
            do {
                try await page.clearHighlights()
                if self.showPopup, let cssSelector = self.popupCssSelector, !cssSelector.isEmpty {
                    _ = try await page.highlightText(scanText, elementSelector: cssSelector, styles: self.highlightStylesAsJSObject())
                }
            } catch {
                logger.error("Failed to highlight text: \(error.localizedDescription)")
            }
        }

        logger.debug("Showing popup for query: \(scanText)")
    }

    func hidePopup() {
        self.showPopup = false
        Task { @MainActor in
            do {
                try await page.clearHighlights()
            } catch {
                logger.error("Failed to clear highlights: \(error.localizedDescription)")
            }
        }
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
