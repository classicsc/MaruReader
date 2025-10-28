//
//  BookReaderViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import CoreData
import Foundation
import MaruReaderCore
import Observation
import os.log
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import SwiftUI
import WebKit

enum BookReaderState {
    case loading
    case reading
    case error(Error)
}

enum BookReaderOverlayState {
    case none
    case showingTableOfContents
    case showingQuickSettings
    case showingToolbars
    case showingSearch
    case showingDictionarySheet
    case showingBookmarks

    var shouldShowNavigationBackButton: Bool {
        switch self {
        case .showingSearch, .showingBookmarks, .showingDictionarySheet, .none:
            false
        default:
            true
        }
    }

    var shouldShowToolbars: Bool {
        switch self {
        case .showingToolbars, .showingTableOfContents, .showingQuickSettings:
            true
        default:
            false
        }
    }
}

@MainActor
@Observable
final class BookReaderViewModel: NSObject, WKScriptMessageHandler {
    var readerState: BookReaderState = .loading
    var overlayState: BookReaderOverlayState = .showingToolbars
    var showPopup = false
    var popupPage: WebPage = .init()
    var sheetQueryTerm: String = ""
    var publication: Publication?
    var initialLocation: Locator?
    var book: Book
    var readerPreferences: ReaderPreferences
    var navigator: EPUBNavigatorViewController?
    var popupAnchorPosition: UnitPoint = .zero

    private var popupSearchTask: Task<Void, Error>?

    private let searchService = DictionarySearchService()
    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()

    let highlightStyles = [
        "background-color": "yellow",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookReaderViewModel")

    init(book: Book) {
        self.book = book
        self.readerPreferences = ReaderPreferences(book: book)
        super.init()

        Task {
            await loadPublication()
        }
        initializePopupPage()
    }

    var showingDictionarySheet: Bool {
        get { overlayState == .showingDictionarySheet }
        set {
            if newValue {
                overlayState = .showingDictionarySheet
            } else if overlayState == .showingDictionarySheet {
                overlayState = .none
            }
        }
    }

    private func loadPublication() async {
        do {
            guard let fileName = book.fileName else {
                throw BookReaderError.bookFileNotFound
            }

            guard let appSupportDir = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ) else {
                throw BookReaderError.cannotAccessAppSupport
            }

            let bookURL = appSupportDir
                .appendingPathComponent("Books")
                .appendingPathComponent(fileName)

            guard let fileURL = FileURL(url: bookURL) else {
                throw BookReaderError.invalidBookPath
            }

            let assetRetriever = AssetRetriever(httpClient: DefaultHTTPClient())
            let assetResult = await assetRetriever.retrieve(url: fileURL)
            guard case let .success(asset) = assetResult else {
                if case let .failure(error) = assetResult {
                    self.readerState = .error(error)
                    return
                } else {
                    self.readerState = .error(BookReaderError.unknownError)
                    return
                }
            }

            let publicationOpener = PublicationOpener(
                parser: DefaultPublicationParser(httpClient: DefaultHTTPClient(), assetRetriever: assetRetriever, pdfFactory: DefaultPDFDocumentFactory())
            )
            let publicationResult = await publicationOpener.open(asset: asset, allowUserInteraction: false)
            guard case let .success(publication) = publicationResult else {
                if case let .failure(error) = publicationResult {
                    self.readerState = .error(error)
                    return
                } else {
                    self.readerState = .error(BookReaderError.unknownError)
                    return
                }
            }

            self.publication = publication

            logger.info("Successfully loaded publication for book \(self.book.title ?? "Unknown")")

            // Get the last read location if available
            if let lastPageJSON = book.lastOpenedPage {
                initialLocation = try? Locator(jsonString: lastPageJSON)
            }

            self.readerState = .reading
        } catch {
            logger.error("Failed to load publication for book \(self.book.title ?? "Unknown"): \(error.localizedDescription)")
            self.readerState = .error(error)
        }
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

    func searchInDictionarySheet(_ term: String) {
        logger.debug("Searching in dictionary sheet for term: \(term)")
        sheetQueryTerm = term
        showingDictionarySheet = true
    }

    func bookmarkCurrentLocation() {
        // Stub: will be implemented later
        logger.debug("Bookmarking current location")
    }

    func searchInPopup(offset: Int, context: String, contextStartOffset: Int, cssSelector: String) {
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
                    // Use offset-based highlighting for precise positioning
                    await self.clearHighlights()
                    let boundingRects = await self.highlightTextByContextRange(
                        cssSelector: cssSelector,
                        contextStartOffset: searchResults.contextStartOffset,
                        matchStartInContext: searchResults.matchStartInContext,
                        matchEndInContext: searchResults.matchEndInContext,
                        styles: self.highlightStylesAsJSObject()
                    )
                    let boundingRectsAsCGRects = getBoundingRects(highlightBoundingRects: boundingRects)
                    if let firstRect = boundingRectsAsCGRects.first {
                        self.popupAnchorPosition = UnitPoint(
                            x: firstRect.midX,
                            y: firstRect.midY
                        )
                    } else {
                        logger.debug("No bounding rects returned for highlight")
                        self.popupAnchorPosition = .zero
                    }
                    logger.debug("Highlighted range: \(searchResults.matchStartInContext)..<\(searchResults.matchEndInContext) in context starting at \(searchResults.contextStartOffset)")
                    self.showPopup = true
                }
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
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    func hidePopup() {
        self.showPopup = false
        self.popupAnchorPosition = .zero
        Task { @MainActor in
            await self.clearHighlights()
        }
    }

    func clearHighlights() async {
        logger.debug("Clearing highlights")
        guard let navigator else {
            logger.warning("Navigator is not initialized, skipping clear highlights")
            return
        }
        do {
            try await navigator.clearMaruHighlights()
        } catch {
            logger.error("Clearing highlights threw error: \(error.localizedDescription)")
        }
    }

    func highlightTextByContextRange(cssSelector: String, contextStartOffset: Int, matchStartInContext: Int, matchEndInContext: Int, styles: String) async -> [[String: Double]] {
        logger.debug("Highlighting by context range: \(matchStartInContext)..<\(matchEndInContext) at context start \(contextStartOffset)")
        guard let navigator else {
            logger.warning("Navigator is not initialized, skipping highlight")
            return []
        }
        do {
            let result = try await navigator.maruHighlightTextByContextRange(
                cssSelector: cssSelector,
                contextStartOffset: contextStartOffset,
                matchStartInContext: matchStartInContext,
                matchEndInContext: matchEndInContext,
                styles: styles
            )
            logger.debug("Highlight result bounding rects: \(result)")
            return result
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

    func toggleOverlay() {
        if overlayState == .none {
            overlayState = .showingToolbars
        } else {
            overlayState = .none
        }
    }

    func isVerticalWriting() -> Bool {
        guard let navigator else { return false }
        return navigator.settings.verticalText
    }

    func readingProgression() -> ReadiumNavigator.ReadingProgression {
        guard let navigator else { return .ltr }
        return navigator.settings.readingProgression
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "navigateToTerm" {
            if let term = message.body as? String {
                logger.debug("Received navigateToTerm message for term: \(term)")
                searchInDictionarySheet(term)
            } else {
                logger.warning("navigateToTerm message body is not a string")
            }
        }
    }
}

extension EPUBNavigatorViewController {
    func clearMaruHighlights() async throws {
        let result = await self.evaluateJavaScript("window.MaruReader.textHighlighting.clearAllHighlights();")
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func maruHighlightTextByContextRange(cssSelector: String, contextStartOffset: Int, matchStartInContext: Int, matchEndInContext: Int, styles: String) async throws -> [[String: Double]] {
        let script = "window.MaruReader.textHighlighting.highlightTextByContextRange('\(cssSelector)', \(contextStartOffset), \(matchStartInContext), \(matchEndInContext), \(styles));"
        let result = await self.evaluateJavaScript(script)
        switch result {
        case let .success(value):
            guard let dataDict = value as? [String: Any],
                  let _ = dataDict["highlightId"] as? String,
                  let boundingRects = dataDict["boundingRects"] as? [[String: Double]]
            else {
                throw HighlightError.invalidResponse
            }
            return boundingRects
        case let .failure(error):
            throw error
        }
    }
}
