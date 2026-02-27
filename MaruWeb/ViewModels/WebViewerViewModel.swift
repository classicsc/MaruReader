// WebViewerViewModel.swift
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

import CoreGraphics
import Foundation
import MaruReaderCore
import MaruVision
import Observation
import os
import UIKit
import WebKit

// MARK: - WebOverlayState

enum WebOverlayState {
    case none
    case showingToolbars

    var shouldShowToolbars: Bool {
        self == .showingToolbars
    }

    var shouldShowNavigationBackButton: Bool {
        self == .showingToolbars
    }
}

struct WebLookupSelection: Identifiable {
    let id: UUID
    let cluster: TextCluster
    let contextValues: LookupContextValues

    init(cluster: TextCluster, contextValues: LookupContextValues) {
        self.id = cluster.id
        self.cluster = cluster
        self.contextValues = contextValues
    }
}

struct WebTextSelection: Identifiable {
    let id = UUID()
    let text: String
    let contextValues: LookupContextValues
}

struct WebTabState: Identifiable {
    let id: UUID
    let session: WebSession

    var page: WebBrowserPage {
        session.page
    }
}

struct WebTabSummary: Identifiable {
    let id: UUID
    let title: String
    let host: String
    let isLoading: Bool
}

// MARK: - WebViewerViewModel

@MainActor
@Observable
final class WebViewerViewModel {
    var tabs: [WebTabState] = []
    var selectedTabID: UUID?
    var dismissViewerRequestID: UUID?
    var page: WebBrowserPage? {
        activeTab?.page
    }

    var isShowingNewTabPage: Bool {
        guard let page else { return false }
        return page.url == nil && !page.isLoading
    }

    var tabSummaries: [WebTabSummary] {
        tabs.map { tab in
            let page = tab.page
            let title = tabTitle(for: page)
            let host = page.url?.host ?? "New Tab"
            return WebTabSummary(
                id: tab.id,
                title: title,
                host: host,
                isLoading: page.isLoading
            )
        }
    }

    let ocrViewModel: WebOCRViewModel
    private let bookmarkManager: WebBookmarkManager
    private let sessionStore: WebSessionStore
    private var isPreparingSession = false
    private let logger = Logger.maru(category: "WebViewerViewModel")

    var addressBarText: String = ""
    var readingModeEnabled = false
    var showBoundingBoxes = false
    var highlightedCluster: TextCluster?
    var isBookmarked = false
    var bookmarks: [WebBookmarkSnapshot] = []
    var overlayState: WebOverlayState = .showingToolbars
    var editMenuSelection: WebTextSelection?

    private var initialURL: URL?
    private var activeTab: WebTabState? {
        guard let selectedTabID else { return nil }
        return tabs.first(where: { $0.id == selectedTabID })
    }

    /// Minimum scroll distance required to trigger toolbar visibility change
    private let scrollThreshold: CGFloat = 20

    init(
        initialURL: URL? = nil,
        ocrViewModel: WebOCRViewModel = WebOCRViewModel(),
        bookmarkManager: WebBookmarkManager = .shared,
        sessionStore: WebSessionStore = .shared
    ) {
        self.ocrViewModel = ocrViewModel
        self.bookmarkManager = bookmarkManager
        self.sessionStore = sessionStore
        self.initialURL = initialURL
        if let initialURL {
            addressBarText = initialURL.absoluteString
        }
    }

    func prepareSessionIfNeeded() async {
        guard tabs.isEmpty, !isPreparingSession else { return }
        isPreparingSession = true
        defer { isPreparingSession = false }
        _ = await createTab(select: true)
        loadInitialURLIfNeeded()
        refreshBookmarkState()
    }

    func toggleOverlay() {
        switch overlayState {
        case .none:
            overlayState = .showingToolbars
        case .showingToolbars:
            overlayState = .none
        }
    }

    /// Handles scroll offset changes to show/hide toolbars based on scroll direction.
    /// Scrolling down hides toolbars, scrolling up shows them.
    func handleScrollOffsetChange(from oldOffset: CGFloat, to newOffset: CGFloat) {
        // Don't auto-hide in reading mode (toolbars keep their layout reservation)
        guard !readingModeEnabled else {
            // Invalidate cached OCR results when scrolling in reading mode
            let delta = newOffset - oldOffset
            if abs(delta) >= scrollThreshold {
                ocrViewModel.reset()
            }
            return
        }

        let delta = newOffset - oldOffset
        guard abs(delta) >= scrollThreshold else { return }

        if delta > 0 {
            // Scrolling down - hide toolbars
            if overlayState == .showingToolbars {
                overlayState = .none
            }
        } else {
            // Scrolling up - show toolbars
            if overlayState == .none {
                overlayState = .showingToolbars
            }
        }
    }

    func loadInitialURLIfNeeded() {
        guard let initialURL, page != nil else { return }
        self.initialURL = nil
        navigate(to: initialURL)
    }

    func addTab() {
        Task {
            _ = await createTab(select: true)
        }
    }

    func switchToTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        guard selectedTabID != id else { return }
        selectedTabID = id
        readingModeEnabled = false
        showBoundingBoxes = false
        highlightedCluster = nil
        ocrViewModel.reset()
        overlayState = .showingToolbars
        updateAddressBar(from: page?.url)
        refreshBookmarkState()
    }

    func closeCurrentTab() {
        guard let selectedTabID else { return }
        closeTab(id: selectedTabID)
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedTabID == id
        if tabs.count == 1 {
            tabs.removeAll()
            selectedTabID = nil
            dismissViewerRequestID = UUID()
            return
        }
        tabs.remove(at: index)
        guard wasSelected else { return }
        let replacementIndex = min(index, tabs.count - 1)
        selectedTabID = tabs[replacementIndex].id
        readingModeEnabled = false
        showBoundingBoxes = false
        highlightedCluster = nil
        ocrViewModel.reset()
        overlayState = .showingToolbars
        updateAddressBar(from: page?.url)
        refreshBookmarkState()
    }

    func moveTabs(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty, source.allSatisfy({ $0 < tabs.count }) else { return }
        var reordered = tabs
        let movingItems = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) {
            reordered.remove(at: index)
        }
        let adjustedDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - adjustedDestination, reordered.count))
        reordered.insert(contentsOf: movingItems, at: insertionIndex)
        tabs = reordered
    }

    func navigate(to rawValue: String) {
        guard let url = WebAddressParser.resolvedURL(from: rawValue) else { return }
        navigate(to: url)
    }

    func navigate(to url: URL) {
        guard let page else { return }
        addressBarText = url.absoluteString
        page.load(url)
    }

    func goBack() {
        guard let page, page.canGoBack else { return }
        page.goBack()
    }

    func goForward() {
        guard let page, page.canGoForward else { return }
        page.goForward()
    }

    func reload() {
        guard let page else { return }
        page.reload()
    }

    func stopLoading() {
        page?.stopLoading()
    }

    func toggleBookmark() {
        guard let page, let url = page.url else { return }
        let title = page.title
        let favicon = page.faviconData
        Task {
            do {
                let isNowBookmarked = try await bookmarkManager.toggleBookmark(url: url, title: title, favicon: favicon)
                let snapshots = try await bookmarkManager.fetchBookmarks()
                await MainActor.run {
                    self.isBookmarked = isNowBookmarked
                    self.bookmarks = snapshots
                }
            } catch {
                return
            }
        }
    }

    func addBookmarkForCurrentPage() {
        guard let page, let url = page.url else { return }
        let title = page.title
        let favicon = page.faviconData
        Task {
            do {
                _ = try await bookmarkManager.addBookmark(url: url, title: title, favicon: favicon)
                let snapshots = try await bookmarkManager.fetchBookmarks()
                await MainActor.run {
                    self.isBookmarked = true
                    self.bookmarks = snapshots
                }
            } catch {
                return
            }
        }
    }

    func removeBookmarkForCurrentPage() {
        guard let page, let url = page.url else { return }
        Task {
            do {
                try await bookmarkManager.removeBookmark(url: url)
                let snapshots = try await bookmarkManager.fetchBookmarks()
                await MainActor.run {
                    self.isBookmarked = false
                    self.bookmarks = snapshots
                }
            } catch {
                return
            }
        }
    }

    /// Captures a viewport snapshot and runs OCR, caching the results for subsequent taps.
    func captureAndRunOCR(viewSize: CGSize) async {
        guard !ocrViewModel.isProcessing else { return }
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        guard let page else { return }

        do {
            let imageData = try await captureViewportSnapshot(page: page, viewportSize: viewSize)
            let clusters = await ocrViewModel.performOCR(imageData: imageData)
            logger.debug("OCR produced \(clusters.count, privacy: .public) clusters")
        } catch {
            logger.error("OCR capture failed: \(error.localizedDescription, privacy: .public)")
            ocrViewModel.errorMessage = error.localizedDescription
        }
    }

    /// Hit-tests cached OCR clusters at the given location.
    /// If no cached results exist, captures and runs OCR first.
    /// Returns the matched cluster wrapped in a lookup selection, or nil.
    func lookupCluster(at location: CGPoint, in viewSize: CGSize) async -> WebLookupSelection? {
        guard !ocrViewModel.isProcessing else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        guard page != nil else { return nil }

        // If no cached results, capture and run OCR first
        if ocrViewModel.clusters.isEmpty {
            await captureAndRunOCR(viewSize: viewSize)
            guard !ocrViewModel.clusters.isEmpty else { return nil }
        }

        let normalized = CGPoint(
            x: location.x / viewSize.width,
            y: 1 - (location.y / viewSize.height)
        )

        // Hit-test: require exact bounding box match (no nearest-cluster fallback)
        guard let cluster = ocrViewModel.clusters.first(where: { $0.boundingBox.contains(normalized) }) else {
            // Tap missed all clusters — re-OCR in case viewport changed
            logger.debug("OCR hit-test miss. Cached clusters: \(self.ocrViewModel.clusters.count, privacy: .public)")
            ocrViewModel.reset()
            await captureAndRunOCR(viewSize: viewSize)
            return nil
        }

        let screenshotURL = await writeJPEGContextImage(from: ocrViewModel.image, prefix: "web_snapshot")
        let contextValues = webContextValues(screenshotURL: screenshotURL)
        return WebLookupSelection(cluster: cluster, contextValues: contextValues)
    }

    func exitReadingModeAfterLookupSelection() {
        readingModeEnabled = false
        overlayState = .showingToolbars
    }

    func handleEditMenuLookup(_ selectedText: String) {
        Task {
            let screenshotURL = await captureScreenshotForContext()
            let contextValues = webContextValues(screenshotURL: screenshotURL)
            editMenuSelection = WebTextSelection(
                text: selectedText,
                contextValues: contextValues
            )
        }
    }

    func updateAddressBar(from url: URL?) {
        if let url {
            addressBarText = url.absoluteString
        } else {
            addressBarText = ""
        }
    }

    func refreshBookmarkState() {
        let page = page
        Task {
            let currentURL = page?.url
            let currentTitle = page?.title
            let currentFavicon = page?.faviconData

            let isBookmarkedForCurrentPage: Bool
            if let currentURL {
                isBookmarkedForCurrentPage = await bookmarkManager.isBookmarked(url: currentURL)
                if isBookmarkedForCurrentPage {
                    try? await bookmarkManager.updateBookmarkMetadata(
                        url: currentURL,
                        title: currentTitle,
                        favicon: currentFavicon
                    )
                }
            } else {
                isBookmarkedForCurrentPage = false
            }

            let snapshots: [WebBookmarkSnapshot]
            do {
                snapshots = try await bookmarkManager.fetchBookmarks()
            } catch {
                snapshots = []
            }

            await MainActor.run {
                self.isBookmarked = isBookmarkedForCurrentPage
                self.bookmarks = snapshots
            }
        }
    }

    struct ViewportInfo: Equatable {
        let rect: CGRect
        let snapshotWidth: CGFloat
    }

    private func captureViewportSnapshot(page: WebBrowserPage, viewportSize: CGSize) async throws -> Data {
        // WKWebView snapshots with no rect capture the currently visible viewport, which keeps
        // OCR bounding boxes aligned with tap coordinates after scrolling.
        try await page.takeSnapshot(
            region: nil,
            snapshotWidth: viewportSize.width > 0 ? viewportSize.width : nil
        )
    }

    private func createTab(
        initialURL: URL? = nil,
        initialRequest: URLRequest? = nil,
        select: Bool
    ) async -> UUID? {
        let session = await sessionStore.makeSession(
            enableContentBlocking: WebContentBlockingSettings.contentBlockingEnabled
        )
        guard !Task.isCancelled else { return nil }
        let page = session.page
        configureHandlers(for: page)
        let tabID = UUID()
        tabs.append(WebTabState(id: tabID, session: session))

        if let initialRequest {
            page.load(initialRequest)
        } else if let initialURL {
            page.load(initialURL)
        }

        if select || selectedTabID == nil {
            if selectedTabID == tabID {
                updateAddressBar(from: page.url)
            } else {
                switchToTab(id: tabID)
            }
        }
        return tabID
    }

    private func configureHandlers(for page: WebBrowserPage) {
        page.setDictionaryLookupHandler { [weak self] selectedText in
            self?.handleEditMenuLookup(selectedText)
        }
        page.setOpenRequestInNewTabHandler { [weak self] request in
            self?.openRequestInNewTab(request)
        }
        page.setLinkContextMenuHandlers(
            openInCurrentTab: { [weak self] url in
                self?.navigate(to: url)
            },
            openInNewTab: { [weak self] url in
                self?.openURLInNewTab(url)
            },
            copyLink: { [weak self] url in
                self?.copyLinkToPasteboard(url)
            }
        )
    }

    private func openRequestInNewTab(_ request: URLRequest) {
        Task {
            _ = await createTab(initialRequest: request, select: true)
        }
    }

    private func openURLInNewTab(_ url: URL) {
        Task {
            _ = await createTab(initialURL: url, select: true)
        }
    }

    private func copyLinkToPasteboard(_ url: URL) {
        UIPasteboard.general.url = url
    }

    private func tabTitle(for page: WebBrowserPage) -> String {
        if let title = page.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty
        {
            return title
        }
        if let host = page.url?.host, !host.isEmpty {
            return host
        }
        return "New Tab"
    }

    nonisolated static func viewportInfo(from result: Any?) -> ViewportInfo? {
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

    private nonisolated static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private func writeJPEGContextImage(from image: UIImage?, prefix: String) async -> URL? {
        guard let image else { return nil }
        return await Task.detached {
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
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

    private func webContextValues(screenshotURL: URL?) -> LookupContextValues {
        let title = page?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = title.isEmpty ? "Web page" : title
        let urlString = page?.url?.absoluteString ?? "Unknown URL"
        return LookupContextValues(
            contextInfo: "\(displayTitle) - \(urlString)",
            documentCoverImageURL: nil,
            screenshotURL: screenshotURL,
            sourceType: .web
        )
    }

    private func captureScreenshotForContext() async -> URL? {
        guard let page else { return nil }
        do {
            let imageData = try await page.takeSnapshot(region: nil, snapshotWidth: nil)
            guard let image = UIImage(data: imageData) else { return nil }
            return await writeJPEGContextImage(from: image, prefix: "web_snapshot")
        } catch {
            logger.error("Edit menu screenshot capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
