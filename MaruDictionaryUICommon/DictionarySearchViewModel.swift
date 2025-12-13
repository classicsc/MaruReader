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
                currentPopupResponse = nil
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
    private var currentPopupResponse: TextLookupResponse?
    private var focusDebounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var popupSearchTask: Task<Void, Error>?

    // Store current lookup request and response for context display
    var currentRequest: TextLookupRequest?
    var currentResponse: TextLookupResponse?

    // Navigation history for back/forward functionality
    let history = NavigationHistory()

    private let audioLookupService = AudioLookupService(persistenceController: .shared)
    private let searchService: DictionarySearchService

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()

    let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewModel")

    public init(resultState: ResultDisplayState = .startPage) {
        self.resultState = resultState
        self.searchService = DictionarySearchService(audioLookupService: audioLookupService)
        super.init()
        initializeWebPage()
        initializePopupPage()

        // Load audio providers asynchronously
        Task {
            try? await audioLookupService.loadProviders()
        }
    }

    /// Initialize with an existing lookup response to preserve context
    public init(response: TextLookupResponse) {
        self.resultState = .ready

        // Reconstruct the request from the response data
        // Use the start of the match as the offset
        let reconstructedRequest = TextLookupRequest(
            context: response.context,
            offset: response.matchStartInContext,
            contextStartOffset: response.contextStartOffset,
            rubyContext: nil,
            cssSelector: nil
        )

        self.currentRequest = reconstructedRequest
        self.currentResponse = response
        self.searchService = DictionarySearchService(audioLookupService: audioLookupService)
        super.init()
        initializeWebPage()
        initializePopupPage()

        // Load audio providers asynchronously
        Task {
            try? await audioLookupService.loadProviders()
        }

        // Load the HTML and push to navigation history
        Task {
            let loadSequence = page.load(html: response.toResultsHTML())
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    await MainActor.run {
                        self.history.push(request: reconstructedRequest, response: response)
                    }
                    return
                }
            }
        }
    }

    private func initializeWebPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler

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
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    /// Perform a search at a specific offset within the current context
    public func performSearchAtOffset(_ offset: Int) {
        guard let currentRequest else { return }
        let newRequest = TextLookupRequest(
            context: currentRequest.context,
            offset: offset,
            contextStartOffset: currentRequest.contextStartOffset,
            rubyContext: currentRequest.rubyContext,
            cssSelector: currentRequest.cssSelector
        )
        performSearchWithRequest(newRequest)
    }

    /// Perform a search with a specific TextLookupRequest
    private func performSearchWithRequest(_ lookupRequest: TextLookupRequest) {
        searchTask?.cancel()
        searchTask = Task {
            if Task.isCancelled { return }
            Task { @MainActor in
                self.hidePopup()
            }

            let updateTask = Task { @MainActor in
                self.resultState = .searching
            }
            do {
                guard let searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                    await MainActor.run {
                        self.currentRequest = lookupRequest
                        self.currentResponse = nil
                        self.resultState = .noResults(lookupRequest.context)
                    }
                    return
                }
                await updateTask.value
                await MainActor.run {
                    self.currentRequest = lookupRequest
                    self.currentResponse = searchResults
                    // Push to navigation history
                    self.history.push(request: lookupRequest, response: searchResults)
                }
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
                    self.currentRequest = lookupRequest
                    self.currentResponse = nil
                    self.resultState = .error(error)
                }
                self.logger.error("Search error: \(error.localizedDescription)")
                return
            }
        }
    }

    public func performSearch(_ searchQuery: String) {
        // Cancel any existing search
        searchTask?.cancel()

        // Handle empty query
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentRequest = nil
            currentResponse = nil
            resultState = .startPage
            return
        }

        // Start new search with debounce
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }

            let lookupRequest = TextLookupRequest(context: searchQuery)
            performSearchWithRequest(lookupRequest)
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
            // Store the response so we can preserve context when navigating
            await MainActor.run {
                self.currentPopupResponse = searchResults
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
        self.currentPopupResponse = nil
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
                // If we have a popup response with context, use it to preserve context
                if let popupResponse = currentPopupResponse {
                    // Reconstruct request from the popup response to preserve context
                    let request = TextLookupRequest(
                        context: popupResponse.context,
                        offset: popupResponse.matchStartInContext,
                        contextStartOffset: popupResponse.contextStartOffset,
                        rubyContext: nil,
                        cssSelector: nil
                    )
                    performSearchWithRequest(request)
                } else {
                    // Fallback to simple search if no popup context available
                    performSearch(term)
                }
            } else {
                logger.warning("navigateToTerm message body is not a string")
            }
        }
    }

    /// Navigate backwards in history
    public func navigateBack() {
        guard let entry = history.goBack() else {
            logger.warning("Cannot navigate back: no history available")
            return
        }

        // Cancel any pending searches
        searchTask?.cancel()

        // Restore state from history entry
        currentRequest = entry.request
        currentResponse = entry.response
        hidePopup()

        // Load the HTML and update result state
        Task {
            let loadSequence = page.load(html: entry.response.toResultsHTML())
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    await MainActor.run {
                        self.resultState = .ready
                    }
                    return
                }
            }
        }
    }

    /// Navigate forwards in history
    public func navigateForward() {
        guard let entry = history.goForward() else {
            logger.warning("Cannot navigate forward: no history available")
            return
        }

        // Cancel any pending searches
        searchTask?.cancel()

        // Restore state from history entry
        currentRequest = entry.request
        currentResponse = entry.response
        hidePopup()

        // Load the HTML and update result state
        Task {
            let loadSequence = page.load(html: entry.response.toResultsHTML())
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    await MainActor.run {
                        self.resultState = .ready
                    }
                    return
                }
            }
        }
    }
}
