// DictionarySearchViewModel.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import MaruReaderCore
import Observation
import os
import SwiftUI
import WebKit

/// Helper class to hold mutable state references for the scheme handler
@MainActor
@Observable
public final class DictionarySearchViewModel: NSObject, WKScriptMessageHandler {
    typealias ResultsPageLoadHandler = @MainActor (WebPage, URLRequest) async throws -> Void
    typealias ResultsPageJavaScriptHandler = @MainActor (WebPage, String) async throws -> Any?

    var resultState: ResultDisplayState
    private var showingPopup: Bool = false
    var showPopup: Bool {
        get { showingPopup }
        set {
            if !newValue {
                currentPopupResponse = nil
                currentPopupSession = nil
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
    private var currentPopupSession: TextLookupSession?
    private var focusDebounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var popupSearchTask: Task<Void, Never>?
    private var dictionaryWebTheme: DictionaryWebTheme?
    @ObservationIgnored
    private(set) var isResultsPageBootstrapped: Bool = false

    // Store current lookup request and response for context display
    var currentRequest: TextLookupRequest?
    var currentResponse: TextLookupResponse?
    private var currentSession: TextLookupSession?

    /// Link activation state
    var toolbarLinksActiveOverride: Bool?

    /// Effective links active state (toolbar override takes precedence, default on)
    var linksActiveEnabled: Bool {
        toolbarLinksActiveOverride ?? true
    }

    // External link confirmation dialog state
    var pendingExternalURL: URL?
    var externalLinkAnchorRect: CGRect = .zero
    var showExternalLinkConfirmation: Bool = false

    // Tooltip display state
    var tooltipText: String = ""
    var tooltipAnchorRect: CGRect = .zero
    var showTooltip: Bool = false

    /// Navigation history for back/forward functionality
    let history = NavigationHistory()

    private let searchServiceFactory: () -> DictionarySearchService
    private var resolvedSearchService: DictionarySearchService?

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()
    private var resultsSchemeHandler: DictionaryResultsURLSchemeHandler = .init()
    private var popupResultsSchemeHandler: DictionaryResultsURLSchemeHandler = .init()
    private var ankiSchemeHandler: AnkiURLSchemeHandler = .init()
    private var popupAnkiSchemeHandler: AnkiURLSchemeHandler = .init()
    @ObservationIgnored
    private var pageSecuritySetupTask: Task<Void, Error>?
    @ObservationIgnored
    private var popupPageSecuritySetupTask: Task<Void, Error>?
    @ObservationIgnored
    var resultsPageLoadHandler: ResultsPageLoadHandler?
    @ObservationIgnored
    var resultsPageJavaScriptHandler: ResultsPageJavaScriptHandler?

    let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger.maru(category: "DictionarySearchViewModel")

    public init(
        resultState: ResultDisplayState = .startPage,
        dictionaryWebTheme: DictionaryWebTheme? = nil,
        searchServiceFactory: @escaping () -> DictionarySearchService = { DictionarySearchService() }
    ) {
        self.resultState = resultState
        self.searchServiceFactory = searchServiceFactory
        self.dictionaryWebTheme = dictionaryWebTheme
        super.init()
        initializeWebPage()
        initializePopupPage()
        applyDictionaryWebTheme()
    }

    /// Initialize with an existing lookup session to preserve context/results.
    public init(
        session: TextLookupSession,
        dictionaryWebTheme: DictionaryWebTheme? = nil,
        searchServiceFactory: @escaping () -> DictionarySearchService = { DictionarySearchService() }
    ) {
        self.resultState = .ready
        self.searchServiceFactory = searchServiceFactory
        self.dictionaryWebTheme = dictionaryWebTheme
        super.init()
        initializeWebPage()
        initializePopupPage()
        applyDictionaryWebTheme()

        Task {
            do {
                await session.resetRenderCursor()
                let request = await session.request
                _ = try? await session.prepareInitialResults()
                let snapshot = try? await session.snapshot()

                self.currentRequest = request
                self.currentSession = session
                self.currentResponse = snapshot

                await ankiSchemeHandler.setSession(session)
                await resultsSchemeHandler.setSession(session)
                try await self.showResultsPage(for: request.id)

                self.history.push(request: request, session: session)
                self.resultState = .ready
                self.updateLinksActiveState()
            } catch {
                self.resultState = .error(error)
                self.logger.error("Failed to display existing dictionary session: \(error.localizedDescription)")
                return
            }
        }
    }

    private enum ResultsPageMode: String {
        case results
        case popup
    }

    private enum ResultsPageError: Error {
        case navigationDidNotFinish
    }

    private func resultsPageURLRequest(requestID: UUID, mode: ResultsPageMode) -> URLRequest {
        let urlString = "marureader-resource://dictionary.html?mode=\(mode.rawValue)&requestId=\(requestID.uuidString)"
        return URLRequest(url: URL(string: urlString)!)
    }

    private func popupResultsPageURLRequest(requestID: UUID) -> URLRequest {
        resultsPageURLRequest(requestID: requestID, mode: .popup)
    }

    private func loadResultsPage(_ request: URLRequest) async throws {
        if resultsPageLoadHandler == nil {
            try await ensureResultsPageSecurityReady()
        }

        if let resultsPageLoadHandler {
            try await resultsPageLoadHandler(page, request)
            return
        }

        let loadSequence = page.load(request)
        for try await value in loadSequence {
            if value == WebPage.NavigationEvent.finished {
                return
            }
        }

        throw ResultsPageError.navigationDidNotFinish
    }

    private func loadPopupPage(_ request: URLRequest) async throws {
        try await ensurePopupPageSecurityReady()

        let loadSequence = popupPage.load(request)
        for try await value in loadSequence {
            if value == WebPage.NavigationEvent.finished {
                return
            }
        }

        throw ResultsPageError.navigationDidNotFinish
    }

    private func evaluateResultsPageJavaScript(_ script: String) async throws -> Any? {
        if let resultsPageJavaScriptHandler {
            return try await resultsPageJavaScriptHandler(page, script)
        }

        return try await page.callJavaScript(script)
    }

    func showResultsPage(for requestID: UUID) async throws {
        if isResultsPageBootstrapped {
            do {
                let script = "window.MaruReader.dictionaryResults.replaceRequest('\(requestID.uuidString)', 'results');"
                _ = try await evaluateResultsPageJavaScript(script)
                return
            } catch {
                logger.error("Falling back to a full results page reload after JS replacement failed: \(error.localizedDescription)")
                isResultsPageBootstrapped = false
            }
        }

        try await loadResultsPage(resultsPageURLRequest(requestID: requestID, mode: .results))
        isResultsPageBootstrapped = true
    }

    public func setDictionaryWebTheme(_ theme: DictionaryWebTheme?) {
        guard dictionaryWebTheme != theme else { return }
        dictionaryWebTheme = theme
        applyDictionaryWebTheme()
        reloadWebContentForThemeChangeIfNeeded()
    }

    private func applyDictionaryWebTheme() {
        let theme = dictionaryWebTheme
        Task {
            await resultsSchemeHandler.setWebTheme(theme)
            await popupResultsSchemeHandler.setWebTheme(theme)
        }
    }

    private func reloadWebContentForThemeChangeIfNeeded() {
        if case .ready = resultState {
            reloadResultsPageForCurrentSession()
        }
        if showPopup {
            reloadPopupPageForCurrentSession()
        }
    }

    private func reloadResultsPageForCurrentSession() {
        guard let currentRequest, let currentSession else { return }

        Task {
            await currentSession.resetRenderCursor()

            do {
                try await loadResultsPage(resultsPageURLRequest(requestID: currentRequest.id, mode: .results))
                self.isResultsPageBootstrapped = true
                self.updateLinksActiveState()
                return
            } catch {
                self.logger.error("Failed to reload dictionary results page for theme update: \(error.localizedDescription)")
            }
        }
    }

    private func reloadPopupPageForCurrentSession() {
        guard let currentPopupSession else { return }

        Task {
            await currentPopupSession.resetRenderCursor()
            let requestId = await currentPopupSession.requestId

            do {
                try await loadPopupPage(popupResultsPageURLRequest(requestID: requestId))
                return
            } catch {
                self.logger.error("Failed to reload dictionary popup page for theme update: \(error.localizedDescription)")
            }
        }
    }

    private func initializeWebPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = resultsSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-anki")!] = ankiSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "textScanning")
        userContentController.add(self, name: "internalLink")
        userContentController.add(self, name: "externalLink")
        userContentController.add(self, name: "tooltip")
        userContentController.addUserScript(makeDictionaryLocalizedStringsScript())
        config.userContentController = userContentController
        page = WebPage(configuration: config, navigationDecider: DictionaryRendererNavigationDecider())
        page.isInspectable = true
        pageSecuritySetupTask = Task { @MainActor in
            try await DictionaryRendererSecurity.installContentRuleList(on: userContentController)
        }
    }

    private func initializePopupPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = popupResultsSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-anki")!] = popupAnkiSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        userContentController.addUserScript(makeDictionaryLocalizedStringsScript())
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config, navigationDecider: DictionaryRendererNavigationDecider())
        popupPage.isInspectable = true
        popupPageSecuritySetupTask = Task { @MainActor in
            try await DictionaryRendererSecurity.installContentRuleList(on: userContentController)
        }
    }

    private func ensureResultsPageSecurityReady() async throws {
        try await pageSecuritySetupTask?.value
    }

    private func ensurePopupPageSecurityReady() async throws {
        try await popupPageSecuritySetupTask?.value
    }

    private func searchService() -> DictionarySearchService {
        if let resolvedSearchService {
            return resolvedSearchService
        }

        let searchService = searchServiceFactory()
        resolvedSearchService = searchService
        return searchService
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
        searchTask?.cancel()
        searchTask = Task {
            do {
                try Task.checkCancellation()
                self.hidePopup()
                self.resultState = .searching

                guard let session = try await self.searchService().startTextLookup(request: lookupRequest) else {
                    try Task.checkCancellation()
                    self.currentRequest = lookupRequest
                    self.currentResponse = nil
                    self.currentSession = nil
                    self.resultState = .noResults(lookupRequest.context)
                    return
                }
                try Task.checkCancellation()

                let hasResults = try await session.prepareInitialResults()
                try Task.checkCancellation()
                guard hasResults else {
                    self.currentRequest = lookupRequest
                    self.currentResponse = nil
                    self.currentSession = nil
                    self.resultState = .noResults(lookupRequest.context)
                    return
                }

                let snapshot = try await session.snapshot()
                try Task.checkCancellation()

                await self.ankiSchemeHandler.setSession(session)
                try Task.checkCancellation()
                await self.resultsSchemeHandler.setSession(session)
                try Task.checkCancellation()
                try await self.showResultsPage(for: lookupRequest.id)
                try Task.checkCancellation()
                self.currentRequest = lookupRequest
                self.currentSession = session
                self.currentResponse = snapshot
                self.history.push(request: lookupRequest, session: session)
                self.resultState = .ready
                self.updateLinksActiveState()
                return
            } catch is CancellationError {
                return
            } catch {
                self.currentRequest = lookupRequest
                self.currentResponse = nil
                self.currentSession = nil
                self.resultState = .error(error)
                self.logger.error("Search error: \(error.localizedDescription)")
                return
            }
        }
    }

    public func performSearch(_ searchQuery: String, contextValues: LookupContextValues? = nil) {
        // Cancel any existing search
        searchTask?.cancel()

        // Handle empty query
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentRequest = nil
            currentResponse = nil
            currentSession = nil
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

    private func makeDictionaryContextInfo() -> String {
        let query = normalizedContextInfoPart(currentRequest?.context) ?? "Unknown"
        let headword = normalizedContextInfoPart(currentResponse?.primaryResult) ?? "Unknown"
        let dictionaryTitle = normalizedContextInfoPart(currentResponse?.results.first?.dictionariesResults.first?.dictionaryTitle) ?? "Unknown Dictionary"
        return "Query: \(query) | Headword: \(headword) | Dictionary: \(dictionaryTitle)"
    }

    private func normalizedContextInfoPart(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
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
            do {
                // When scanning text within dictionary results, transition source type to .dictionary.
                let screenshotURL = await captureSearchScreenshotURL()
                try Task.checkCancellation()

                let contextInfo = makeDictionaryContextInfo()
                let transitionedContextValues = baseContextValues.withSourceType(
                    .dictionary,
                    contextInfo: contextInfo,
                    screenshotURL: screenshotURL
                )
                let lookupRequest = TextLookupRequest(
                    context: context,
                    offset: offset,
                    contextStartOffset: contextStartOffset,
                    cssSelector: cssSelector,
                    contextValues: transitionedContextValues
                )
                guard let session = try await self.searchService().startTextLookup(request: lookupRequest) else {
                    return
                }
                try Task.checkCancellation()

                let hasResults = try await session.prepareInitialResults()
                try Task.checkCancellation()
                guard hasResults, let snapshot = try await session.snapshot() else {
                    return
                }
                try Task.checkCancellation()

                await self.popupAnkiSchemeHandler.setSession(session)
                try Task.checkCancellation()
                await self.popupResultsSchemeHandler.setSession(session)
                try Task.checkCancellation()

                try await self.loadPopupPage(self.popupResultsPageURLRequest(requestID: lookupRequest.id))
                try Task.checkCancellation()

                do {
                    try await page.clearHighlights()
                    try Task.checkCancellation()

                    let highlightBoundingRects = try await page.highlightTextByContextRange(
                        cssSelector: cssSelector,
                        contextStartOffset: snapshot.contextStartOffset,
                        matchStartInContext: snapshot.matchStartInContext,
                        matchEndInContext: snapshot.matchEndInContext,
                        styles: self.highlightStylesAsJSObject()
                    )
                    try Task.checkCancellation()

                    let boundingRects = getBoundingRects(highlightBoundingRects: highlightBoundingRects)
                    if let firstRect = boundingRects.first {
                        self.popupAnchorPosition = firstRect
                    } else {
                        self.popupAnchorPosition = .zero
                    }
                    self.currentPopupSession = session
                    self.currentPopupResponse = snapshot
                    self.showPopup = true
                } catch is CancellationError {
                    return
                } catch {
                    logger.error("Failed to highlight text: \(error.localizedDescription)")
                }
                logger.debug("Highlighted range: \(snapshot.matchStartInContext)..<\(snapshot.matchEndInContext) in context starting at \(snapshot.contextStartOffset)")
                return
            } catch is CancellationError {
                return
            } catch {
                logger.error("Popup search failed: \(error.localizedDescription)")
            }
        }
    }

    public func hidePopup() {
        self.showPopup = false
        self.currentPopupResponse = nil
        self.currentPopupSession = nil
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
            do {
                let session = entry.session
                await session.resetRenderCursor()
                let snapshot = try? await session.snapshot()

                self.currentRequest = entry.request
                self.currentSession = session
                self.currentResponse = snapshot
                await ankiSchemeHandler.setSession(session)
                await resultsSchemeHandler.setSession(session)
                try await self.showResultsPage(for: entry.request.id)
                self.resultState = .ready
                self.updateLinksActiveState()
            } catch {
                self.resultState = .error(error)
                self.logger.error("Failed to navigate dictionary history backwards: \(error.localizedDescription)")
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
            do {
                let session = entry.session
                await session.resetRenderCursor()
                let snapshot = try? await session.snapshot()

                self.currentRequest = entry.request
                self.currentSession = session
                self.currentResponse = snapshot
                await ankiSchemeHandler.setSession(session)
                await resultsSchemeHandler.setSession(session)
                try await self.showResultsPage(for: entry.request.id)
                self.resultState = .ready
                self.updateLinksActiveState()
            } catch {
                self.resultState = .error(error)
                self.logger.error("Failed to navigate dictionary history forwards: \(error.localizedDescription)")
            }
        }
    }

    /// Toggle link activation on/off
    public func toggleLinksActive() {
        toolbarLinksActiveOverride = !linksActiveEnabled
        // Notify JavaScript of state change
        updateLinksActiveState()
    }

    /// Update JavaScript with current links active state
    private func updateLinksActiveState() {
        let js = "window.MaruReader.linkDisplay?.setLinksActive(\(linksActiveEnabled));"
        Task {
            _ = try? await evaluateResultsPageJavaScript(js)
        }
    }

    /// Clear pending external URL after it has been opened
    public func clearPendingExternalURL() {
        pendingExternalURL = nil
    }

    /// Commit the edited context text
    public func commitContextEdit(_ editedText: String) async {
        guard let session = currentSession else {
            return
        }

        let termFound = await session.updateEditedContext(editedText)

        if let response = try? await session.snapshot() {
            if !termFound {
                logger.info("Primary result '\(response.primaryResult)' not found in edited context")
            }
            currentResponse = response
        }
    }

    /// Copy the current context to clipboard
    public func copyContextToClipboard() {
        guard let context = currentResponse?.effectiveContext ?? currentRequest?.context else { return }
        UIPasteboard.general.string = context
    }
}
