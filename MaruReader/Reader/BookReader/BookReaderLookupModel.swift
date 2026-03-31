// BookReaderLookupModel.swift
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
import MaruDictionaryUICommon
import MaruReaderCore
import Observation
import os
import ReadiumNavigator
import SwiftUI
import WebKit

@MainActor
@Observable
final class BookReaderLookupModel: NSObject, WKScriptMessageHandler {
    var showPopup: Bool = false {
        didSet {
            if !showPopup {
                currentPopupSession = nil
                popupAnchorPosition = .zero
                Task {
                    await clearHighlights()
                }
            }
        }
    }

    var popupPage: WebPage = .init()
    var popupAnchorPosition: CGRect = .zero
    var dictionarySheetPresentation: BookReaderDictionarySheetPresentation?
    var isDictionaryReady: Bool = false
    private(set) var pendingSheetSearchText: String?
    private(set) var pendingSheetContextValues: LookupContextValues?

    private var popupSearchTask: Task<Void, Error>?
    private weak var activeNavigatorWebView: WKWebView?
    private var currentPopupSession: TextLookupSession?
    private var dictionaryWebTheme: DictionaryWebTheme?

    private let session: BookReaderSessionModel
    private let readerPreferences: ReaderPreferences
    private let searchServiceFactory: () -> DictionarySearchService
    private var resolvedSearchService: DictionarySearchService?
    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()
    private var resultsSchemeHandler: DictionaryResultsURLSchemeHandler = .init()
    private var ankiSchemeHandler: AnkiURLSchemeHandler = .init()

    private let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger.maru(category: "BookReaderLookupModel")

    init(
        session: BookReaderSessionModel,
        readerPreferences: ReaderPreferences,
        searchServiceFactory: @escaping () -> DictionarySearchService = { DictionarySearchService() }
    ) {
        self.session = session
        self.readerPreferences = readerPreferences
        self.searchServiceFactory = searchServiceFactory
        super.init()
        initializePopupPage()
    }

    private func searchService() -> DictionarySearchService {
        if let resolvedSearchService {
            return resolvedSearchService
        }

        let searchService = searchServiceFactory()
        resolvedSearchService = searchService
        return searchService
    }

    func presentDictionarySheet(with searchViewModel: DictionarySearchViewModel) {
        dictionarySheetPresentation = BookReaderDictionarySheetPresentation(viewModel: searchViewModel)
    }

    func dismissDictionarySheet() {
        dictionarySheetPresentation = nil
        pendingSheetSearchText = nil
        pendingSheetContextValues = nil
    }

    func replayPendingSheetSearch() {
        guard let searchText = pendingSheetSearchText,
              let presentation = dictionarySheetPresentation
        else { return }
        presentation.viewModel.performSearch(searchText, contextValues: pendingSheetContextValues)
        pendingSheetSearchText = nil
        pendingSheetContextValues = nil
    }

    func searchInDictionarySheet(session lookupSession: TextLookupSession) {
        logger.debug("Opening dictionary sheet with lookup session")
        let searchViewModel = DictionarySearchViewModel(
            session: lookupSession,
            dictionaryWebTheme: dictionaryWebTheme
        )
        presentDictionarySheet(with: searchViewModel)
    }

    func setDictionaryWebTheme(_ theme: DictionaryWebTheme?) {
        dictionaryWebTheme = theme
        dictionarySheetPresentation?.viewModel.setDictionaryWebTheme(theme)

        Task {
            do {
                await self.resultsSchemeHandler.setWebTheme(theme)
                guard self.showPopup, let currentPopupSession = self.currentPopupSession else { return }
                await currentPopupSession.resetRenderCursor()
                let requestId = await currentPopupSession.requestId
                let urlString = "marureader-resource://dictionary.html?mode=popup&requestId=\(requestId.uuidString)"
                let loadSequence = self.popupPage.load(URLRequest(url: URL(string: urlString)!))
                for try await value in loadSequence {
                    if value == WebPage.NavigationEvent.finished {
                        return
                    }
                }
            } catch {
                logger.error("Failed to reload book reader dictionary popup for theme update: \(error.localizedDescription)")
            }
        }
    }

    func searchInPopup(offset: Int, context: String, contextStartOffset: Int, cssSelector: String) {
        if showPopup {
            hidePopup()
            return
        }

        guard isDictionaryReady else {
            let searchText = String(context.dropFirst(offset).prefix(20))
            pendingSheetSearchText = searchText
            Task {
                pendingSheetContextValues = await session.makeLookupContextValues()
            }
            presentDictionarySheet(with: DictionarySearchViewModel(resultState: .searching))
            return
        }

        popupSearchTask?.cancel()
        popupSearchTask = Task {
            let contextValues = await session.makeLookupContextValues()
            let lookupRequest = TextLookupRequest(
                context: context,
                offset: offset,
                contextStartOffset: contextStartOffset,
                cssSelector: cssSelector,
                contextValues: contextValues
            )
            guard let lookupSession = try await self.searchService().startTextLookup(request: lookupRequest) else {
                logger.debug("No search session created for lookup")
                return
            }

            let hasResults = try await lookupSession.prepareInitialResults()
            guard hasResults, let snapshot = try? await lookupSession.snapshot() else {
                logger.debug("No search results found for lookup")
                return
            }

            currentPopupSession = lookupSession
            await ankiSchemeHandler.setSession(lookupSession)
            await resultsSchemeHandler.setSession(lookupSession)

            let urlString = "marureader-resource://dictionary.html?mode=popup&requestId=\(lookupRequest.id.uuidString)"
            let loadSequence = popupPage.load(URLRequest(url: URL(string: urlString)!))
            for try await value in loadSequence {
                try Task.checkCancellation()
                if value == WebPage.NavigationEvent.finished {
                    await clearHighlights()
                    let boundingRects = await highlightTextByContextRange(
                        cssSelector: cssSelector,
                        contextStartOffset: snapshot.contextStartOffset,
                        matchStartInContext: snapshot.matchStartInContext,
                        matchEndInContext: snapshot.matchEndInContext,
                        styles: highlightStylesAsJSObject()
                    )
                    let rects = makeBoundingRects(from: boundingRects)
                    popupAnchorPosition = rects.first ?? .zero
                    showPopup = true
                }
            }
        }
    }

    func hidePopup() {
        showPopup = false
    }

    func clearHighlights() async {
        logger.debug("Clearing highlights")
        guard let navigator = session.navigator else {
            logger.warning("Navigator is not initialized, skipping clear highlights")
            return
        }

        do {
            try await navigator.clearMaruHighlights()
        } catch {
            logger.error("Clearing highlights threw error: \(error.localizedDescription)")
        }
    }

    func highlightTextByContextRange(
        cssSelector: String,
        contextStartOffset: Int,
        matchStartInContext: Int,
        matchEndInContext: Int,
        styles: String
    ) async -> [[String: Double]] {
        logger.debug("Highlighting by context range: \(matchStartInContext)..<\(matchEndInContext) at context start \(contextStartOffset)")
        guard let navigator = session.navigator else {
            logger.warning("Navigator is not initialized, skipping highlight")
            return []
        }

        do {
            return try await navigator.maruHighlightTextByContextRange(
                cssSelector: cssSelector,
                contextStartOffset: contextStartOffset,
                matchStartInContext: matchStartInContext,
                matchEndInContext: matchEndInContext,
                styles: styles
            )
        } catch {
            logger.error("Highlighting by context range threw error: \(error.localizedDescription)")
            return []
        }
    }

    func highlightStylesAsJSObject() -> String {
        let stylePairs = highlightStyles.map { key, value in
            "'\(key)': '\(value)'"
        }
        return "{\(stylePairs.joined(separator: ", "))}"
    }

    func triggerTextScan(atGlobalPoint point: CGPoint) {
        guard let navigatorView = session.navigator?.view,
              let window = navigatorView.window
        else {
            logger.warning("Navigator web view not ready for text scan")
            return
        }

        let pointInNavigator = navigatorView.convert(point, from: window)
        guard let webView = navigatorWebView(containingNavigatorPoint: pointInNavigator) else {
            logger.warning("Navigator web view not found for text scan")
            return
        }

        let pointInWebView = webView.convert(pointInNavigator, from: navigatorView)
        guard webView.bounds.contains(pointInWebView) else {
            logger.debug("Tap outside navigator web view bounds: \(String(describing: pointInWebView))")
            return
        }

        activeNavigatorWebView = webView
        let script = "window.MaruReader.textScanning.extractTextAtPoint(\(pointInWebView.x), \(pointInWebView.y), 0, 50);"
        Task {
            let result = await self.session.navigator?.evaluateJavaScript(script)
            switch result {
            case .success?:
                break
            case let .failure(error)?:
                logger.error("Text scan failed: \(error.localizedDescription)")
            case nil:
                logger.warning("Navigator unavailable for text scan")
            }
        }
    }

    static let screenshotLookupSearchText = "常に"

    /// Checks whether the screenshot lookup text is visible in the current viewport
    /// (not just present in the DOM, which may include off-screen paginated columns).
    func isScreenshotTextVisible() async -> Bool {
        let text = Self.screenshotLookupSearchText
        let script = """
        (function() {
            var text = '\(text)';
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {
                var idx = walker.currentNode.textContent.indexOf(text);
                if (idx !== -1) {
                    var range = document.createRange();
                    range.setStart(walker.currentNode, idx);
                    range.setEnd(walker.currentNode, idx + text.length);
                    var rect = range.getBoundingClientRect();
                    return rect.left >= 0 && rect.right <= window.innerWidth
                        && rect.top >= 0 && rect.bottom <= window.innerHeight;
                }
            }
            return false;
        })()
        """
        switch await session.navigator?.evaluateJavaScript(script) {
        case let .success(value)?:
            return value as? Bool ?? false
        default:
            return false
        }
    }

    func triggerScreenshotTextLookup() {
        guard let webView = currentNavigatorWebView() else {
            logger.warning("Navigator web view not ready for screenshot text lookup")
            return
        }

        activeNavigatorWebView = webView
        let script = "window.MaruReader.textScanning.extractTextBySearch('\(Self.screenshotLookupSearchText)', 0, 0, 50);"
        Task {
            let result = await self.session.navigator?.evaluateJavaScript(script)
            switch result {
            case .success?:
                break
            case let .failure(error)?:
                logger.error("Screenshot text lookup failed: \(error.localizedDescription)")
            case nil:
                logger.warning("Navigator unavailable for screenshot text lookup")
            }
        }
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "navigateToTerm" {
            if let _ = message.body as? String {
                if let currentPopupSession {
                    searchInDictionarySheet(session: currentPopupSession)
                } else {
                    logger.warning("No current popup session available, cannot preserve context")
                }
            } else {
                logger.warning("navigateToTerm message body is not a string")
            }
        }
    }

    private func initializePopupPage() {
        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = mediaSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = resourceSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = resultsSchemeHandler
        config.urlSchemeHandlers[URLScheme("marureader-anki")!] = ankiSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        userContentController.addUserScript(makeDictionaryLocalizedStringsScript())
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    private func makeBoundingRects(from highlightBoundingRects: [[String: Double]]) -> [CGRect] {
        highlightBoundingRects.compactMap { dict in
            guard let x = dict["x"],
                  let y = dict["y"],
                  let width = dict["width"],
                  let height = dict["height"]
            else {
                return nil
            }

            let rect = CGRect(x: x, y: y, width: width, height: height)
            return convertWebViewRectToReaderView(rect)
        }
    }

    private func navigatorWebView(containingNavigatorPoint point: CGPoint) -> WKWebView? {
        guard let navigatorView = session.navigator?.view else {
            return nil
        }

        let webViews = navigatorView.descendants(ofType: WKWebView.self)
        if let matchingWebView = webViews.first(where: { webView in
            guard webView.window != nil else { return false }
            let pointInWebView = webView.convert(point, from: navigatorView)
            return webView.bounds.contains(pointInWebView)
        }) {
            return matchingWebView
        }

        return webViews.first(where: { $0.window != nil })
    }

    private func currentNavigatorWebView() -> WKWebView? {
        if let activeNavigatorWebView, activeNavigatorWebView.window != nil {
            return activeNavigatorWebView
        }

        guard let navigatorView = session.navigator?.view else {
            return nil
        }

        return navigatorView.descendants(ofType: WKWebView.self).first(where: { $0.window != nil })
    }

    private func convertWebViewRectToReaderView(_ rect: CGRect) -> CGRect? {
        guard let navigator = session.navigator,
              let webView = currentNavigatorWebView()
        else {
            return nil
        }

        let rectInNavigator = webView.convert(rect, to: navigator.view)
        return rectInNavigator.offsetBy(dx: readerPreferences.horizontalMargin, dy: 0)
    }
}
