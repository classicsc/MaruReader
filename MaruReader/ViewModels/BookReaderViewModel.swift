// BookReaderViewModel.swift
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
import MaruDictionaryUICommon
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
    /// When true, dictionary tap gestures are active and navigator gestures are blocked.
    /// When false, navigator receives all gestures (text selection, links).
    var isDictionaryActive: Bool = true
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
    /// Current reading location, if available.
    var currentLocator: Locator?
    var popupAnchorPosition: CGRect = .zero
    private var currentPopupResponse: TextLookupResponse?

    /// Bookmarks for the current book, sorted by creation date (newest first)
    var bookmarks: [Bookmark] = []
    /// Location before navigating to a bookmark, for "return" functionality
    var previousLocation: Locator?

    private var popupSearchTask: Task<Void, Error>?
    private weak var activeNavigatorWebView: WKWebView?

    private let searchService: DictionarySearchService
    private var mediaSchemeHandler: MediaURLSchemeHandler = .init()
    private var resourceSchemeHandler: ResourceURLSchemeHandler = .init()
    private var audioSchemeHandler: AudioURLSchemeHandler = .init()
    private var ankiSchemeHandler: AnkiURLSchemeHandler = .init()

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

    /// Book cover image, if available.
    var coverImage: UIImage? {
        guard let url = bookCoverURL,
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    /// Context values for dictionary lookups, populated with book metadata.
    private func makeLookupContextValues() async -> LookupContextValues {
        let coverImageURL = await makeCoverContextImageURL()
        return LookupContextValues(
            documentTitle: book.title,
            documentURL: nil,
            documentCoverImageURL: coverImageURL,
            screenshotURL: nil,
            sourceType: .book
        )
    }

    init(book: Book) {
        self.book = book
        self.readerPreferences = ReaderPreferences(book: book)
        self.searchService = DictionarySearchService()
        super.init()

        // Load bookmarks
        loadBookmarks()

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
        config.urlSchemeHandlers[URLScheme("marureader-anki")!] = ankiSchemeHandler

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "navigateToTerm")
        config.userContentController = userContentController
        popupPage = WebPage(configuration: config)
        popupPage.isInspectable = true
    }

    func searchInDictionarySheet(response: TextLookupResponse) {
        logger.debug("Opening dictionary sheet with context: \(response.context)")
        sheetLookupResponse = response
        showingDictionarySheet = true
    }

    /// Returns the bookmark at the current location, if any
    var currentLocationBookmark: Bookmark? {
        guard let locator = currentLocator,
              let currentJSON = locator.jsonString
        else { return nil }
        return bookmarks.first { $0.location == currentJSON }
    }

    func bookmarkCurrentLocation() {
        guard let locator = currentLocator else {
            logger.warning("Cannot bookmark: no current location")
            return
        }

        // Generate title on main actor before crossing to context.perform
        let title = generateDefaultBookmarkTitle(for: locator)
        let bookObjectID = book.objectID

        let context = BookDataPersistenceController.shared.container.viewContext
        context.perform {
            let bookmark = Bookmark(context: context)
            bookmark.id = UUID()
            bookmark.location = locator.jsonString ?? ""
            bookmark.createdAt = Date()
            bookmark.title = title
            bookmark.book = context.object(with: bookObjectID) as? Book

            do {
                try context.save()
                Task { @MainActor in
                    self.loadBookmarks()
                    self.logger.info("Bookmark created: \(title)")
                }
            } catch {
                self.logger.error("Failed to save bookmark: \(error.localizedDescription)")
            }
        }
    }

    func removeBookmarkAtCurrentLocation() {
        guard let bookmark = currentLocationBookmark else {
            logger.warning("Cannot remove bookmark: no bookmark at current location")
            return
        }
        deleteBookmark(bookmark)
    }

    func navigateToBookmark(_ bookmark: Bookmark) {
        guard let locationJSON = bookmark.location,
              let locator = try? Locator(jsonString: locationJSON),
              let navigator
        else {
            logger.warning("Cannot navigate to bookmark: invalid location or navigator not ready")
            return
        }

        // Store current location before navigating
        previousLocation = currentLocator

        Task {
            _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
            await MainActor.run {
                overlayState = .none
            }
        }
    }

    func returnToPreviousLocation() {
        guard let locator = previousLocation, let navigator else {
            logger.warning("Cannot return: no previous location or navigator not ready")
            return
        }

        Task {
            _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
            await MainActor.run {
                previousLocation = nil
                overlayState = .none
            }
        }
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        let bookmarkObjectID = bookmark.objectID
        let context = BookDataPersistenceController.shared.container.viewContext
        context.perform {
            let bookmarkToDelete = context.object(with: bookmarkObjectID)
            context.delete(bookmarkToDelete)
            do {
                try context.save()
                Task { @MainActor in
                    self.loadBookmarks()
                    self.logger.info("Bookmark deleted")
                }
            } catch {
                self.logger.error("Failed to delete bookmark: \(error.localizedDescription)")
            }
        }
    }

    func updateBookmarkTitle(_ bookmark: Bookmark, title: String) {
        let bookmarkObjectID = bookmark.objectID
        let newTitle = title.isEmpty ? nil : title
        let context = BookDataPersistenceController.shared.container.viewContext
        context.perform {
            guard let bookmarkToUpdate = context.object(with: bookmarkObjectID) as? Bookmark else { return }
            bookmarkToUpdate.title = newTitle
            do {
                try context.save()
                Task { @MainActor in
                    self.loadBookmarks()
                    self.logger.info("Bookmark title updated")
                }
            } catch {
                self.logger.error("Failed to update bookmark title: \(error.localizedDescription)")
            }
        }
    }

    func loadBookmarks() {
        let context = BookDataPersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Bookmark>(entityName: "Bookmark")
        request.predicate = NSPredicate(format: "book == %@", book)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bookmark.createdAt, ascending: false)]

        do {
            bookmarks = try context.fetch(request)
        } catch {
            logger.error("Failed to fetch bookmarks: \(error.localizedDescription)")
            bookmarks = []
        }
    }

    private func generateDefaultBookmarkTitle(for locator: Locator) -> String {
        // Try to get chapter title from publication TOC
        if let publication,
           let chapterTitle = findChapterTitle(for: locator, in: publication)
        {
            return chapterTitle
        }

        // Fall back to position
        if let position = locator.locations.position {
            return "Position \(position)"
        }

        // Fall back to total progression
        if let totalProgression = locator.locations.totalProgression {
            let percent = Int(totalProgression * 100)
            return "Book \(percent)%"
        }

        return "Bookmark"
    }

    private func findChapterTitle(for locator: Locator, in publication: Publication) -> String? {
        func searchLinks(_ links: [ReadiumShared.Link]) -> String? {
            for link in links {
                if link.href == locator.href.string, let title = link.title, !title.isEmpty {
                    return title
                }
                if let found = searchLinks(link.children) {
                    return found
                }
            }
            return nil
        }
        return searchLinks(publication.manifest.tableOfContents)
    }

    func searchInPopup(offset: Int, context: String, contextStartOffset: Int, cssSelector: String) {
        // If popup is visible, hide it
        if self.showPopup {
            logger.debug("Hiding popup")
            self.hidePopup()
            return
        }

        popupSearchTask?.cancel()
        popupSearchTask = Task {
            let lookupRequest = await TextLookupRequest(
                context: context,
                offset: offset,
                contextStartOffset: contextStartOffset,
                cssSelector: cssSelector,
                contextValues: makeLookupContextValues()
            )
            guard let searchResults = try await searchService.performTextLookup(query: lookupRequest) else {
                logger.debug("No search results found for lookup")
                return
            }

            // Store the response so we can pass it when opening the dictionary sheet
            await MainActor.run {
                self.currentPopupResponse = searchResults
            }
            await ankiSchemeHandler.setResponse(searchResults)
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

    private func makeCoverContextImageURL() async -> URL? {
        guard let coverURL = bookCoverURL else { return nil }
        return await writeJPEGContextImage(from: coverURL, prefix: "book_cover")
    }

    private func writeJPEGContextImage(from sourceURL: URL, prefix: String) async -> URL? {
        await Task.detached {
            guard let data = try? Data(contentsOf: sourceURL),
                  let jpegData = ContextImageEncoder.jpegData(from: data, quality: 0.9)
            else {
                return nil
            }
            return Self.writeContextJPEGData(jpegData, prefix: prefix)
        }.value
    }

    private nonisolated static func writeContextJPEGData(_ data: Data, prefix: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MaruContextMedia", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = "\(prefix)_\(UUID().uuidString).jpg"
            let fileURL = directory.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
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
            let rect = CGRect(x: x, y: y, width: width, height: height)
            return convertWebViewRectToReaderView(rect)
        }
    }

    private func navigatorWebView(containingNavigatorPoint point: CGPoint) -> WKWebView? {
        guard let navigatorView = navigator?.view else {
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

        guard let navigatorView = navigator?.view else {
            return nil
        }

        return navigatorView.descendants(ofType: WKWebView.self).first(where: { $0.window != nil })
    }

    private func convertWebViewRectToReaderView(_ rect: CGRect) -> CGRect? {
        guard let navigator,
              let webView = currentNavigatorWebView()
        else {
            return nil
        }

        let rectInNavigator = webView.convert(rect, to: navigator.view)
        return rectInNavigator.offsetBy(dx: readerPreferences.horizontalMargin, dy: 0)
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

    /// Triggers text scanning at the given point (in window/global coordinates).
    func triggerTextScan(atGlobalPoint point: CGPoint) {
        guard let navigator,
              let navigatorView = navigator.view,
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
            let result = await navigator.evaluateJavaScript(script)
            switch result {
            case .success:
                // Response is handled via WKScriptMessageHandler
                break
            case let .failure(error):
                logger.error("Text scan failed: \(error.localizedDescription)")
            }
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

    /// Navigate to a table of contents link.
    func navigateToLink(_ link: ReadiumShared.Link) {
        guard let publication, let navigator else {
            logger.warning("Cannot navigate: publication or navigator not ready")
            return
        }

        Task {
            if let locator = await publication.locate(link) {
                _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
                await MainActor.run {
                    overlayState = .none
                }
            } else {
                logger.warning("Could not locate link: \(link.href)")
            }
        }
    }

    /// Navigate to a 1-based position in the publication.
    func navigateToPosition(_ position: Int) {
        guard position > 0 else {
            logger.warning("Cannot navigate: invalid position \(position)")
            return
        }
        guard let publication, let navigator else {
            logger.warning("Cannot navigate: publication or navigator not ready")
            return
        }

        Task {
            let positions = await publication.positions().getOrNil() ?? []
            guard !positions.isEmpty else {
                logger.warning("Cannot navigate: positions list unavailable")
                return
            }

            let locator = positions.first(where: { $0.locations.position == position })
                ?? positions.getOrNil(position - 1)

            guard let locator else {
                logger.warning("Cannot navigate: position \(position) out of range")
                return
            }

            _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
            await MainActor.run {
                overlayState = .none
            }
        }
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

private extension UIView {
    func descendants<T: UIView>(ofType type: T.Type) -> [T] {
        var results: [T] = []

        if let view = self as? T {
            results.append(view)
        }

        for subview in subviews {
            results.append(contentsOf: subview.descendants(ofType: type))
        }

        return results
    }
}
