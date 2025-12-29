//
//  BookReaderViewModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import CoreData
import Foundation
import MaruAnki
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
    private var showingPopup: Bool = false
    var showPopup: Bool {
        get { showingPopup }
        set {
            if !newValue {
                Task {
                    await clearHighlights()
                }
            }
            showingPopup = newValue
        }
    }

    var popupPage: WebPage = .init()
    var sheetLookupResponse: TextLookupResponse?
    var publication: Publication?
    var initialLocation: Locator?
    var book: Book
    var readerPreferences: ReaderPreferences
    var navigator: EPUBNavigatorViewController?
    var popupAnchorPosition: CGRect = .zero
    private var currentPopupResponse: TextLookupResponse?

    private var popupSearchTask: Task<Void, Error>?

    private let audioLookupService = AudioLookupService(persistenceController: .shared)
    private let searchService: DictionarySearchService
    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()

    // Anki services
    private var ankiConnectionManager: AnkiConnectionManager?
    private let ankiNoteService = AnkiNoteService()

    let highlightStyles = [
        "background-color": "inherit",
    ]

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookReaderViewModel")

    /// URL to the book's cover image file, if available.
    private var bookCoverURL: URL? {
        guard let coverFileName = book.coverFileName else { return nil }

        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }

        return appSupportDir
            .appendingPathComponent("Covers")
            .appendingPathComponent(coverFileName)
    }

    /// Context values for dictionary lookups, populated with book metadata.
    private var lookupContextValues: LookupContextValues {
        LookupContextValues(
            documentTitle: book.title,
            documentURL: nil,
            documentCoverImageURL: bookCoverURL,
            screenshotURL: nil
        )
    }

    init(book: Book) {
        self.book = book
        self.readerPreferences = ReaderPreferences(book: book)
        self.searchService = DictionarySearchService(audioLookupService: audioLookupService)
        super.init()

        // Load audio providers asynchronously
        Task {
            try? await audioLookupService.loadProviders()
        }

        // Initialize Anki connection manager asynchronously
        Task { @MainActor in
            self.ankiConnectionManager = await AnkiConnectionManager()
        }

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
        config.urlSchemeHandlers[URLScheme("marureader-audio")!] = audioSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        userContentController.add(self, name: "ankiAdd")
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    func searchInDictionarySheet(response: TextLookupResponse) {
        logger.debug("Opening dictionary sheet with context: \(response.context)")
        sheetLookupResponse = response
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

        let lookupRequest = TextLookupRequest(
            context: context,
            offset: offset,
            contextStartOffset: contextStartOffset,
            cssSelector: cssSelector,
            contextValues: lookupContextValues
        )
        popupSearchTask?.cancel()
        popupSearchTask = Task {
            guard var searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                return
            }

            // Check for existing Anki notes and update response
            searchResults = await prepareResponseWithAnkiState(searchResults)

            // Store the response so we can pass it when opening the dictionary sheet
            await MainActor.run {
                self.currentPopupResponse = searchResults
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
                        self.popupAnchorPosition = firstRect
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
            return CGRect(x: x + readerPreferences.horizontalMargin,
                          y: y + readerPreferences.horizontalMargin,
                          width: width,
                          height: height)
        }
    }

    func hidePopup() {
        self.showPopup = false
        self.popupAnchorPosition = .zero
        self.currentPopupResponse = nil
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
                // Pass the current popup response if available
                if let response = currentPopupResponse {
                    searchInDictionarySheet(response: response)
                } else {
                    logger.warning("No current popup response available, cannot preserve context")
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
            handleAnkiAdd(termKey: termKey, expression: expression, reading: reading)
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
    private func handleAnkiAdd(termKey: String, expression: String, reading: String?) {
        Task {
            // Set button state to loading
            await setAnkiButtonState(termKey: termKey, state: "loading")

            do {
                guard let ankiConnectionManager, await ankiConnectionManager.isReady else {
                    logger.warning("AnkiConnectionManager not ready")
                    await setAnkiButtonState(termKey: termKey, state: "error")
                    return
                }

                // Find the matching term group from current response
                guard let response = currentPopupResponse,
                      let termGroup = response.results.first(where: { $0.termKey == termKey })
                else {
                    logger.error("Could not find term group for key: \(termKey)")
                    await setAnkiButtonState(termKey: termKey, state: "error")
                    return
                }

                // Create the template resolver
                let resolver = TextLookupResponseTemplateResolver(
                    response: response,
                    selectedGroup: termGroup
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
                    fields: [:],
                    ankiID: result.ankiNoteID
                )

                logger.info("Successfully added Anki note for '\(expression)'")
                await setAnkiButtonState(termKey: termKey, state: "success")

            } catch {
                logger.error("Failed to add Anki note: \(error.localizedDescription)")

                // Check if it's a duplicate error - if so, mark as exists
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("duplicate") || errorDescription.contains("exists") {
                    await setAnkiButtonState(termKey: termKey, state: "exists")
                } else {
                    await setAnkiButtonState(termKey: termKey, state: "error")
                }
            }
        }
    }

    /// Set the Anki button state via JavaScript
    private func setAnkiButtonState(termKey: String, state: String) async {
        let escapedTermKey = termKey.replacingOccurrences(of: "'", with: "\\'")
        let js = "window.MaruReader?.ankiDisplay?.setButtonState('\(escapedTermKey)', '\(state)');"

        do {
            _ = try await popupPage.callJavaScript(js)
        } catch {
            logger.error("Failed to set button state: \(error.localizedDescription)")
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
