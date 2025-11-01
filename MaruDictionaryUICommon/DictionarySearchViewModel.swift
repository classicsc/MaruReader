//
//  DictionarySearchViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import Foundation
import MaruReaderCore
import Observation
import os.log
import SwiftUI
import WebKit

public enum ResultDisplayState {
    case startPage
    case noResults(String)
    case searching
    case ready
    case error(Error)
}

// Helper class to hold mutable state references for the scheme handler
@MainActor
@Observable
public final class DictionarySearchViewModel: NSObject, WKScriptMessageHandler {
    var resultState: ResultDisplayState
    private var showingPopup: Bool = false
    var showPopup: Bool {
        get { showingPopup }
        set {
            if !newValue {
                Task {
                    try? await page.clearHighlights()
                }
            }
            showingPopup = newValue
        }
    }

    var focusState: Bool = false
    var page: WebPage = .init()
    var popupPage: WebPage = .init()
    var popupAnchorPosition: CGRect = .zero
    private var focusDebounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var popupSearchTask: Task<Void, Error>?

    private let searchService = DictionarySearchService()

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()

    let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewModel")

    public init(resultState: ResultDisplayState = .startPage) {
        self.resultState = resultState
        super.init()
        initializeWebPage()
        initializePopupPage()
    }

    private func initializeWebPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "textScanning")
        config.userContentController = userContentController
        page = WebPage(configuration: config)
        page.isInspectable = true
    }

    private func initializePopupPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    public func performSearch(_ searchQuery: String) {
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
                        self.resultState = .noResults(searchQuery)
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

    private func getBoundingRects(highlightBoundingRects: [[String: Double]]) -> [CGRect] {
        highlightBoundingRects.compactMap { dict in
            guard let x = dict["x"],
                  let y = dict["y"],
                  let width = dict["width"],
                  let height = dict["height"]
            else {
                return nil
            }
            return CGRect(x: x,
                          y: y,
                          width: width,
                          height: height)
        }
    }

    private func handleTextScan(offset: Int, context: String, contextStartOffset: Int, cssSelector: String) {
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
                        let highlightBoundingRects = try await page.highlightTextByContextRange(
                            cssSelector: cssSelector,
                            contextStartOffset: searchResults.contextStartOffset,
                            matchStartInContext: searchResults.matchStartInContext,
                            matchEndInContext: searchResults.matchEndInContext,
                            styles: self.highlightStylesAsJSObject()
                        )
                        let boundingRects = getBoundingRects(highlightBoundingRects: highlightBoundingRects)
                        if let firstRect = boundingRects.first {
                            await MainActor.run {
                                self.popupAnchorPosition = firstRect
                            }
                        }
                    } catch {
                        logger.error("Failed to highlight text: \(error.localizedDescription)")
                    }
                    logger.debug("Highlighted range: \(searchResults.matchStartInContext)..<\(searchResults.matchEndInContext) in context starting at \(searchResults.contextStartOffset)")
                }
            }
        }
    }

    public func hidePopup() {
        self.showPopup = false
        Task { @MainActor in
            do {
                try await page.clearHighlights()
            } catch {
                logger.error("Failed to clear highlights: \(error.localizedDescription)")
            }
        }
    }

    public func textFieldFocused() {
        focusDebounceTask?.cancel()
        focusState = true
    }

    public func textFieldUnfocused() {
        focusDebounceTask?.cancel()
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                focusState = false
            }
        }
    }

    private func highlightStylesAsJSObject() -> String {
        let stylePairs = highlightStyles.map { key, value in
            "'\(key)': '\(value)'"
        }
        return "{\(stylePairs.joined(separator: ", "))}"
    }

    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "textScanning" {
            logger.debug("Received textScanning message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let offset = messageObject["offset"] as? Int,
                  let context = messageObject["context"] as? String,
                  let contextStartOffset = messageObject["contextStartOffset"] as? Int,
                  let cssSelector = messageObject["cssSelector"] as? String
            else {
                logger.error("Invalid message body for textScanning")
                return
            }

            handleTextScan(offset: offset, context: context, contextStartOffset: contextStartOffset, cssSelector: cssSelector)
        } else if message.name == "navigateToTerm" {
            if let term = message.body as? String {
                logger.debug("Received navigateToTerm message for term: \(term)")
                performSearch(term)
            } else {
                logger.warning("navigateToTerm message body is not a string")
            }
        }
    }
}
