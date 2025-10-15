//
//  DictionarySearchViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import Foundation
import Observation
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
@Observable
class DictionarySearchViewModel {
    var resultState: ResultDisplayState = .startPage
    var showPopup = false
    var focusState: Bool = false
    var page: WebPage = .init()
    var popupPage: WebPage = .init()
    var highlightBoundingRects: [[String: Double]]?
    private var focusDebounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var popupSearchTask: Task<Void, Error>?

    private let searchService = DictionarySearchService()

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var lookupSchemeHandler: DictionaryLookupURLSchemeHandler?

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
            onScan: { offset, context, contextStartOffset, cssSelector in
                Task { @MainActor in
                    self.handleTextScan(offset, context: context, contextStartOffset: contextStartOffset, cssSelector: cssSelector)
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
    }

    func performSearch(_ searchQuery: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }
            Task { @MainActor in
                self.hidePopup()
            }
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

    func handleTextScan(_ offset: Int, context: String, contextStartOffset: Int, cssSelector: String) {
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

        let lookupRequest = TextLookupRequest(context: context, offset: offset, contextStartOffset: contextStartOffset, cssSelector: cssSelector)
        popupSearchTask?.cancel()
        popupSearchTask = Task {
            guard let searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                return
            }
            let loadSequence = popupPage.load(html: searchResults.toPopupHTML())
            for try await value in loadSequence {
                try Task.checkCancellation()
                if value == WebPage.NavigationEvent.finished {
                    self.showPopup = true

                    // Use offset-based highlighting for precise positioning
                    do {
                        try await page.clearHighlights()
                        highlightBoundingRects = try await page.highlightTextByContextRange(
                            cssSelector: cssSelector,
                            contextStartOffset: searchResults.contextStartOffset,
                            matchStartInContext: searchResults.matchStartInContext,
                            matchEndInContext: searchResults.matchEndInContext,
                            styles: self.highlightStylesAsJSObject()
                        )
                    } catch {
                        logger.error("Failed to highlight text: \(error.localizedDescription)")
                    }
                    logger.debug("Highlighted range: \(searchResults.matchStartInContext)..<\(searchResults.matchEndInContext) in context starting at \(searchResults.contextStartOffset)")
                    logger.debug("Highlight bounding rects: \(String(describing: self.highlightBoundingRects))")
                }
            }
        }
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
