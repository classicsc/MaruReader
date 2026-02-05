// DictionarySearchViewModel.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import MaruAnki
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

/// Helper class to hold mutable state references for the scheme handler
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

    // Context display settings
    var contextFontSize: Double = DictionaryDisplayDefaults.defaultContextFontSize
    var contextFuriganaEnabled: Bool = DictionaryDisplayDefaults.defaultContextFuriganaEnabled
    var toolbarFuriganaOverride: Bool?

    /// Effective furigana enabled state (toolbar override takes precedence)
    var furiganaEnabled: Bool {
        toolbarFuriganaOverride ?? contextFuriganaEnabled
    }

    /// Link activation state
    var toolbarLinksActiveOverride: Bool?

    /// Effective links active state (toolbar override takes precedence, default off)
    var linksActiveEnabled: Bool {
        toolbarLinksActiveOverride ?? false
    }

    // External link confirmation dialog state
    var pendingExternalURL: URL?
    var externalLinkAnchorRect: CGRect = .zero
    var showExternalLinkConfirmation: Bool = false

    // Tooltip display state
    var tooltipText: String = ""
    var tooltipAnchorRect: CGRect = .zero
    var showTooltip: Bool = false

    // Context editing state
    var isEditingContext: Bool = false
    var editContextText: String = ""

    // Cached furigana segments for current context
    private var cachedFuriganaSegments: [FuriganaSegment] = []
    private var cachedFuriganaContext: String?

    /// Get furigana segments for the current context
    var currentFuriganaSegments: [FuriganaSegment] {
        guard let context = currentResponse?.effectiveContext ?? currentRequest?.context else {
            return []
        }

        if cachedFuriganaContext == context {
            return cachedFuriganaSegments
        }

        let segments = FuriganaGenerator.generateSegments(from: context)
        cachedFuriganaContext = context
        cachedFuriganaSegments = segments
        return segments
    }

    /// Navigation history for back/forward functionality
    let history = NavigationHistory()

    private var searchService: DictionarySearchService

    // Anki services - lazily initialized
    private var ankiConnectionManager: AnkiConnectionManager?
    private let ankiNoteService = AnkiNoteService()

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()

    let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewModel")

    public init(resultState: ResultDisplayState = .startPage) {
        self.resultState = resultState
        self.searchService = DictionarySearchService()
        super.init()
        initializeWebPage()
        initializePopupPage()

        Task {
            self.ankiConnectionManager = await AnkiConnectionManager()
        }
    }

    /// Initialize with an existing lookup response to preserve context
    public init(response: TextLookupResponse) {
        self.resultState = .ready

        // Reconstruct the request from the response data, preserving contextValues
        // Use the start of the match as the offset
        let reconstructedRequest = TextLookupRequest(
            context: response.context,
            offset: response.matchStartInContext,
            contextStartOffset: response.contextStartOffset,
            rubyContext: nil,
            cssSelector: nil,
            contextValues: response.request.contextValues
        )

        self.currentRequest = reconstructedRequest
        self.currentResponse = response
        self.searchService = DictionarySearchService()
        super.init()
        initializeWebPage()
        initializePopupPage()

        Task {
            self.ankiConnectionManager = await AnkiConnectionManager()
        }

        // Load the HTML and push to navigation history
        Task {
            let html = await response.toResultsHTML()
            let loadSequence = page.load(html: html)
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    self.history.push(request: reconstructedRequest, response: response)
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
        userContentController.add(self, name: "ankiAdd")
        userContentController.add(self, name: "internalLink")
        userContentController.add(self, name: "externalLink")
        userContentController.add(self, name: "tooltip")
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
        userContentController.add(self, name: "ankiAdd")
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    /// Perform a search at a specific offset within the current context
    public func performSearchAtOffset(_ offset: Int) {
        guard let currentRequest else { return }

        // Use effective context (edited if available)
        let effectiveContext = currentResponse?.effectiveContext ?? currentRequest.context

        let newRequest = TextLookupRequest(
            context: effectiveContext,
            offset: offset,
            contextStartOffset: 0, // Reset for edited context
            rubyContext: currentRequest.rubyContext,
            cssSelector: currentRequest.cssSelector,
            contextValues: currentRequest.contextValues
        )
        performSearchWithRequest(newRequest)
    }

    /// Perform a search with a specific TextLookupRequest
    private func performSearchWithRequest(_ lookupRequest: TextLookupRequest) {
        resetContextEditingState()
        searchTask?.cancel()
        searchTask = Task {
            if Task.isCancelled { return }
            self.hidePopup()
            self.resultState = .searching
            do {
                guard var searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                    self.currentRequest = lookupRequest
                    self.currentResponse = nil
                    self.resultState = .noResults(lookupRequest.context)
                    return
                }

                // Check for existing Anki notes and update response
                searchResults = await prepareResponseWithAnkiState(searchResults)

                self.currentRequest = lookupRequest
                self.currentResponse = searchResults
                // Push to navigation history
                self.history.push(request: lookupRequest, response: searchResults)
                let html = await searchResults.toResultsHTML()
                let loadSequence = page.load(html: html)
                for try await value in loadSequence {
                    if Task.isCancelled { return }
                    if value == WebPage.NavigationEvent.finished {
                        self.resultState = .ready
                        return
                    }
                }
            } catch {
                self.currentRequest = lookupRequest
                self.currentResponse = nil
                self.resultState = .error(error)
                self.logger.error("Search error: \(error.localizedDescription)")
                return
            }
        }
    }

    public func performSearch(_ searchQuery: String, contextValues: LookupContextValues? = nil) {
        // Cancel any existing search
        searchTask?.cancel()
        resetContextEditingState()

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

            let resolvedContextValues = contextValues ?? currentRequest?.contextValues
            let lookupRequest = TextLookupRequest(context: searchQuery, contextValues: resolvedContextValues)
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

    private struct ViewportInfo {
        let rect: CGRect
        let snapshotWidth: CGFloat
    }

    private func captureSearchScreenshotURL() async -> URL? {
        do {
            let imageData = try await captureSearchSnapshotData()
            return await writeJPEGContextImage(imageData, prefix: "dictionary_search")
        } catch {
            logger.error("Failed to capture search screenshot: \(error.localizedDescription)")
            return nil
        }
    }

    private func captureSearchSnapshotData() async throws -> Data {
        if let viewportInfo = try await fetchViewportInfo() {
            let configuration = WebPage.ExportedContentConfiguration.image(
                region: .rect(viewportInfo.rect),
                snapshotWidth: viewportInfo.snapshotWidth
            )
            return try await page.exported(as: configuration)
        }

        let configuration = WebPage.ExportedContentConfiguration.image(
            region: .contents,
            snapshotWidth: nil
        )
        return try await page.exported(as: configuration)
    }

    private func fetchViewportInfo() async throws -> ViewportInfo? {
        let script = """
        (() => ({
            scrollX: window.scrollX,
            scrollY: window.scrollY,
            width: window.innerWidth,
            height: window.innerHeight
        }))()
        """

        let result = try await page.callJavaScript(script)
        guard let dictionary = result as? [String: Any] else { return nil }

        guard let scrollX = doubleValue(dictionary["scrollX"]),
              let scrollY = doubleValue(dictionary["scrollY"]),
              let width = doubleValue(dictionary["width"]),
              let height = doubleValue(dictionary["height"])
        else {
            return nil
        }

        let rect = CGRect(x: scrollX, y: scrollY, width: width, height: height)
        return ViewportInfo(rect: rect, snapshotWidth: CGFloat(width))
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private func writeJPEGContextImage(_ data: Data, prefix: String) async -> URL? {
        await Task.detached {
            guard let jpegData = ContextImageEncoder.jpegData(from: data, quality: 0.9) else {
                return nil
            }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MaruContextMedia", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let filename = "\(prefix)_\(UUID().uuidString).jpg"
                let fileURL = directory.appendingPathComponent(filename)
                try jpegData.write(to: fileURL, options: .atomic)
                return fileURL
            } catch {
                return nil
            }
        }.value
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

        let baseContextValues = currentRequest?.contextValues ?? LookupContextValues()
        popupSearchTask?.cancel()
        popupSearchTask = Task {
            // When scanning text within dictionary results, transition source type to .dictionary.
            let screenshotURL = await captureSearchScreenshotURL()
            let transitionedContextValues = baseContextValues.withSourceType(
                .dictionary,
                screenshotURL: screenshotURL
            )
            let lookupRequest = TextLookupRequest(
                context: context,
                offset: offset,
                contextStartOffset: contextStartOffset,
                cssSelector: cssSelector,
                contextValues: transitionedContextValues
            )
            guard var searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                return
            }

            // Check for existing Anki notes and update response
            searchResults = await prepareResponseWithAnkiState(searchResults)

            // Store the response so we can preserve context when navigating
            self.currentPopupResponse = searchResults
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
                            self.popupAnchorPosition = firstRect
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
        Task {
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
            focusState = false
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
                    // Use effective context and offset to preserve any edits
                    let effectiveOffset = popupResponse.effectiveMatchStartInContext ?? popupResponse.matchStartInContext
                    let request = TextLookupRequest(
                        context: popupResponse.effectiveContext,
                        offset: effectiveOffset,
                        contextStartOffset: 0, // Reset for effective context
                        rubyContext: nil,
                        cssSelector: nil,
                        contextValues: popupResponse.request.contextValues
                    )
                    performSearchWithRequest(request)
                } else {
                    // Fallback to simple search if no popup context available
                    performSearch(term)
                }
            } else {
                logger.warning("navigateToTerm message body is not a string")
            }
        } else if message.name == "ankiAdd" {
            logger.debug("Received ankiAdd message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let termKey = messageObject["termKey"] as? String,
                  let expression = messageObject["expression"] as? String
            else {
                logger.error("Invalid message body for ankiAdd")
                return
            }
            let reading = messageObject["reading"] as? String
            let audioURLString = messageObject["audioURL"] as? String
            let audioURL = audioURLString.flatMap { $0.isEmpty ? nil : URL(string: $0) }
            // Determine source based on whether popup is showing
            let isFromPopup = showPopup && currentPopupResponse != nil
            handleAnkiAdd(
                termKey: termKey,
                expression: expression,
                reading: reading,
                primaryAudioURL: audioURL,
                isFromPopup: isFromPopup
            )
        } else if message.name == "internalLink" {
            logger.debug("Received internalLink message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let query = messageObject["query"] as? String
            else {
                logger.error("Invalid message body for internalLink")
                return
            }
            performSearch(query)
        } else if message.name == "externalLink" {
            logger.debug("Received externalLink message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let urlString = messageObject["url"] as? String,
                  let url = URL(string: urlString)
            else {
                logger.error("Invalid message body for externalLink")
                return
            }

            // Parse anchor rect for popover positioning
            if let anchorRect = messageObject["anchorRect"] as? [String: Double],
               let x = anchorRect["x"],
               let y = anchorRect["y"],
               let width = anchorRect["width"],
               let height = anchorRect["height"]
            {
                externalLinkAnchorRect = CGRect(x: x, y: y, width: width, height: height)
            }

            pendingExternalURL = url
            showExternalLinkConfirmation = true
        } else if message.name == "tooltip" {
            logger.debug("Received tooltip message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let title = messageObject["title"] as? String,
                  !title.isEmpty
            else {
                logger.error("Invalid message body for tooltip")
                return
            }

            // Parse anchor rect for popover positioning
            if let anchorRect = messageObject["anchorRect"] as? [String: Double],
               let x = anchorRect["x"],
               let y = anchorRect["y"],
               let width = anchorRect["width"],
               let height = anchorRect["height"]
            {
                tooltipAnchorRect = CGRect(x: x, y: y, width: width, height: height)
            }

            tooltipText = title
            showTooltip = true
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
        hidePopup()

        // Load the HTML and update result state
        Task {
            // Prepare response with current Anki state
            let updatedResponse = await prepareResponseWithAnkiState(entry.response)

            self.currentRequest = entry.request
            self.currentResponse = updatedResponse

            let html = await updatedResponse.toResultsHTML()
            let loadSequence = page.load(html: html)
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    self.resultState = .ready
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
        hidePopup()

        // Load the HTML and update result state
        Task {
            // Prepare response with current Anki state
            let updatedResponse = await prepareResponseWithAnkiState(entry.response)

            self.currentRequest = entry.request
            self.currentResponse = updatedResponse

            let html = await updatedResponse.toResultsHTML()
            let loadSequence = page.load(html: html)
            for try await value in loadSequence {
                if value == WebPage.NavigationEvent.finished {
                    self.resultState = .ready
                    return
                }
            }
        }
    }

    // MARK: - Anki Integration

    /// Prepare a response with Anki state (enabled status and existing notes)
    private func prepareResponseWithAnkiState(_ response: TextLookupResponse) async -> TextLookupResponse {
        var updatedResponse = response

        guard let ankiConnectionManager else {
            return updatedResponse
        }

        let isReady = await ankiConnectionManager.isReady
        guard isReady else {
            return updatedResponse
        }

        // Mark Anki as enabled
        updatedResponse.setAnkiEnabled(true)

        // Get current profile name for note existence check
        guard let profileName = await ankiConnectionManager.profileName else {
            return updatedResponse
        }

        // Build list of terms to check
        let terms = response.results.map { group in
            (expression: group.expression, reading: group.reading)
        }

        // Check for existing notes
        let existingTermKeys = await ankiNoteService.getExistingNoteTermKeys(
            for: terms,
            profileName: profileName
        )

        updatedResponse.markExistingNotes(existingTermKeys)
        return updatedResponse
    }

    /// Handle Anki add note request from JavaScript
    private func handleAnkiAdd(
        termKey: String,
        expression: String,
        reading: String?,
        primaryAudioURL: URL?,
        isFromPopup: Bool
    ) {
        Task {
            // Set button state to loading
            await setAnkiButtonState(termKey: termKey, state: "loading", isFromPopup: isFromPopup)

            do {
                guard let ankiConnectionManager, await ankiConnectionManager.isReady else {
                    logger.warning("AnkiConnectionManager not ready")
                    await setAnkiButtonState(termKey: termKey, state: "error", isFromPopup: isFromPopup)
                    return
                }

                // Find the matching term group from current response
                let response: TextLookupResponse? = if isFromPopup, let popup = currentPopupResponse {
                    popup
                } else {
                    currentResponse
                }

                guard let response,
                      let termGroup = response.results.first(where: { $0.termKey == termKey })
                else {
                    logger.error("Could not find term group for key: \(termKey)")
                    await setAnkiButtonState(termKey: termKey, state: "error", isFromPopup: isFromPopup)
                    return
                }

                // Create the template resolver
                let resolver = TextLookupResponseTemplateResolver(
                    response: response,
                    selectedGroup: termGroup,
                    primaryAudioURL: primaryAudioURL
                )

                // Add the note via AnkiConnectionManager
                let result = try await ankiConnectionManager.addNote(resolver: resolver)

                // Record the note locally
                try await ankiNoteService.recordNote(
                    expression: expression,
                    reading: reading,
                    profileName: result.profileName,
                    deckName: result.deckName,
                    modelName: result.modelName,
                    fields: result.resolvedFields,
                    ankiID: result.ankiNoteID,
                    pendingSync: result.pendingSync
                )

                logger.info("Successfully added Anki note for '\(expression)'")
                await setAnkiButtonState(termKey: termKey, state: "success", isFromPopup: isFromPopup)

            } catch {
                logger.error("Failed to add Anki note: \(error.localizedDescription)")

                // Check if it's a duplicate error - if so, mark as exists
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("duplicate") || errorDescription.contains("exists") {
                    await setAnkiButtonState(termKey: termKey, state: "exists", isFromPopup: isFromPopup)
                } else {
                    await setAnkiButtonState(termKey: termKey, state: "error", isFromPopup: isFromPopup)
                }
            }
        }
    }

    /// Set the Anki button state via JavaScript
    private func setAnkiButtonState(termKey: String, state: String, isFromPopup: Bool) async {
        let escapedTermKey = termKey.replacingOccurrences(of: "'", with: "\\'")
        let js = "window.MaruReader?.ankiDisplay?.setButtonState('\(escapedTermKey)', '\(state)');"

        do {
            if isFromPopup {
                _ = try await popupPage.callJavaScript(js)
            } else {
                _ = try await page.callJavaScript(js)
            }
        } catch {
            logger.error("Failed to set button state: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Display

    /// Load context display settings from Core Data
    public func loadContextDisplaySettings() {
        Task {
            let container = DictionaryPersistenceController.shared.container
            let context = container.viewContext

            await context.perform {
                let fetchRequest = DictionaryDisplayPreferences.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "enabled == YES")
                fetchRequest.fetchLimit = 1

                if let preferences = try? context.fetch(fetchRequest).first {
                    Task { @MainActor in
                        self.contextFontSize = preferences.contextFontSize
                        self.contextFuriganaEnabled = preferences.contextFuriganaEnabled
                    }
                }
            }
        }
    }

    /// Toggle furigana display on/off
    public func toggleFurigana() {
        if toolbarFuriganaOverride == nil {
            // First toggle: override the setting
            toolbarFuriganaOverride = !contextFuriganaEnabled
        } else {
            // Subsequent toggles: flip the override
            toolbarFuriganaOverride = !furiganaEnabled
        }
        // Invalidate furigana cache
        cachedFuriganaContext = nil
    }

    /// Toggle link activation on/off
    public func toggleLinksActive() {
        if toolbarLinksActiveOverride == nil {
            // First toggle: activate links
            toolbarLinksActiveOverride = true
        } else {
            // Subsequent toggles: flip the override
            toolbarLinksActiveOverride = !linksActiveEnabled
        }
        // Notify JavaScript of state change
        updateLinksActiveState()
    }

    /// Update JavaScript with current links active state
    private func updateLinksActiveState() {
        let js = "window.MaruReader.linkDisplay?.setLinksActive(\(linksActiveEnabled));"
        Task {
            _ = try? await page.callJavaScript(js)
        }
    }

    /// Clear pending external URL after it has been opened
    public func clearPendingExternalURL() {
        pendingExternalURL = nil
    }

    /// Start editing the context text
    public func startEditingContext() {
        guard let context = currentResponse?.effectiveContext ?? currentRequest?.context else { return }
        editContextText = context
        isEditingContext = true
    }

    private func resetContextEditingState() {
        isEditingContext = false
        editContextText = ""
    }

    /// Commit the edited context text
    public func commitContextEdit() {
        guard isEditingContext else { return }
        guard var response = currentResponse else {
            isEditingContext = false
            return
        }

        // Update context and recompute range
        let termFound = response.updateEditedRange(for: editContextText)

        if !termFound {
            logger.info("Primary result '\(response.primaryResult)' not found in edited context")
        }

        currentResponse = response

        // Invalidate furigana cache since context changed
        cachedFuriganaContext = nil

        isEditingContext = false
    }

    /// Cancel editing and discard changes
    public func cancelContextEdit() {
        isEditingContext = false
        editContextText = ""
    }

    /// Copy the current context to clipboard
    public func copyContextToClipboard() {
        guard let context = currentResponse?.effectiveContext ?? currentRequest?.context else { return }
        UIPasteboard.general.string = context
    }
}
