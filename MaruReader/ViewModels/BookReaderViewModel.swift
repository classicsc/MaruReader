//
//  BookReaderViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import CoreData
import Foundation
import Observation
import os.log
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
    case showingSettingsEditorSheet
    case showingToolbars
    case showingSearch
    case showingBookmarks

    var shouldShowNavigationBackButton: Bool {
        switch self {
        case .showingSettingsEditorSheet, .showingSearch, .showingBookmarks:
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
class BookReaderViewModel {
    var readerState: BookReaderState = .loading
    var overlayState: BookReaderOverlayState = .none
    var showPopup = false
    var popupPage: WebPage = .init()
    var publication: Publication?
    var initialLocation: Locator?
    var book: Book

    private var popupSearchTask: Task<Void, Error>?

    private let searchService = DictionarySearchService()

    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var lookupSchemeHandler: DictionaryLookupURLSchemeHandler?

    let forwardTextScanChars = 15
    let highlightStyles = [
        "background-color": "yellow",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookReaderViewModel")

    init(book: Book) {
        self.book = book

        Task {
            await loadPublication()
            initializePopupPage()
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

        let lookupHandler = DictionaryLookupURLSchemeHandler(
            onNavigate: { term in
                Task { @MainActor in
                    self.searchInDictionarySheet(term)
                }
            }
        )

        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = lookupHandler
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    func searchInDictionarySheet(_ term: String) {
        // Stub: will be implemented later
        logger.debug("Searching in dictionary sheet for term: \(term)")
    }

    func bookmarkCurrentLocation() {
        // Stub: will be implemented later
        logger.debug("Bookmarking current location")
    }

    func searchInPopup(offset: Int, context: String, cssSelector: String) {
        // If popup is visible, hide it
        if self.showPopup {
            logger.debug("Hiding popup")
            self.hidePopup()
            return
        }

        let lookupRequest = TextLookupRequest(context: context, offset: offset, cssSelector: cssSelector)
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

                    // The range to highlight within the context is given in the results object
                    let highlightText = context[searchResults.primaryResultSourceRange]
                    try await self.clearHighlights()
                    try await self.highlightText(String(highlightText), elementSelector: cssSelector, styles: self.highlightStylesAsJSObject())
                    logger.debug("Highlighted text: \(highlightText)")
                }
            }
        }
    }

    func hidePopup() {
        self.showPopup = false
        Task { @MainActor in
            do {
                try await self.clearHighlights()
            } catch {
                logger.error("Failed to clear highlights: \(error.localizedDescription)")
            }
        }
    }

    func clearHighlights() async throws {
        // Stub: will be implemented later
        logger.debug("Clearing highlights")
    }

    func highlightText(_ text: String, elementSelector: String, styles: String) async throws {
        // Stub: will be implemented later
        logger.debug("Highlighting text: \(text) in element: \(elementSelector) with styles: \(styles)")
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
}
