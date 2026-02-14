// WebViewerViewModel.swift
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

import CoreGraphics
import Foundation
import MaruReaderCore
import MaruVision
import Observation
import os.log
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

// MARK: - WebViewerViewModel

@MainActor
@Observable
final class WebViewerViewModel {
    var page: WebBrowserPage?
    let ocrViewModel: WebOCRViewModel
    private let bookmarkManager: WebBookmarkManager
    private let sessionStore: WebSessionStore
    private var session: WebSession?
    private var isPreparingSession = false
    private let logger = Logger(subsystem: "net.undefinedstar.MaruWeb", category: "WebViewerViewModel")

    var addressBarText: String = ""
    var readingModeEnabled = false
    var showBoundingBoxes = false
    var highlightedCluster: TextCluster?
    var isBookmarked = false
    var bookmarks: [WebBookmarkSnapshot] = []
    var overlayState: WebOverlayState = .showingToolbars

    private var initialURL: URL?

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
        guard session == nil, !isPreparingSession else { return }
        isPreparingSession = true
        defer { isPreparingSession = false }
        let session = await sessionStore.makeSession(
            enableContentBlocking: WebContentBlockingSettings.contentBlockingEnabled
        )
        guard !Task.isCancelled else { return }
        self.session = session
        page = session.page
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
        // Don't auto-hide in reading mode (already hidden)
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

    func navigate(to rawValue: String) {
        guard let url = WebAddressParser.normalizedURL(from: rawValue) else { return }
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
        Task {
            do {
                let isNowBookmarked = try await bookmarkManager.toggleBookmark(url: url, title: title)
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
        Task {
            do {
                _ = try await bookmarkManager.addBookmark(url: url, title: title)
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
        guard let page else { return nil }

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
        let title = page.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = title.isEmpty ? "Web page" : title
        let urlString = page.url?.absoluteString ?? "Unknown URL"
        let contextValues = LookupContextValues(
            contextInfo: "\(displayTitle) - \(urlString)",
            documentCoverImageURL: nil,
            screenshotURL: screenshotURL,
            sourceType: .web
        )
        return WebLookupSelection(cluster: cluster, contextValues: contextValues)
    }

    func exitReadingModeAfterLookupSelection() {
        readingModeEnabled = false
        overlayState = .showingToolbars
    }

    func updateAddressBar(from url: URL?) {
        guard let url else { return }
        addressBarText = url.absoluteString
    }

    func refreshBookmarkState() {
        let page = page
        Task {
            let snapshots: [WebBookmarkSnapshot]
            do {
                snapshots = try await bookmarkManager.fetchBookmarks()
            } catch {
                snapshots = []
            }
            await MainActor.run {
                self.bookmarks = snapshots
            }

            guard let page else {
                await MainActor.run {
                    self.isBookmarked = false
                }
                return
            }

            guard let url = page.url else {
                await MainActor.run {
                    self.isBookmarked = false
                }
                return
            }

            let bookmarked = await bookmarkManager.isBookmarked(url: url)
            await MainActor.run {
                self.isBookmarked = bookmarked
            }

            if bookmarked {
                try? await bookmarkManager.updateBookmarkMetadata(url: url, title: page.title)
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
}
