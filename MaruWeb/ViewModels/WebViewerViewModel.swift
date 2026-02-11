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
    var page: WebPage?
    let ocrViewModel: WebOCRViewModel
    private let bookmarkManager: WebBookmarkManager
    private let sessionStore: WebSessionStore
    private var session: WebSession?
    private var isPreparingSession = false

    var addressBarText: String = ""
    var readingModeEnabled = false
    var isBookmarked = false
    var bookmarks: [WebBookmarkSnapshot] = []
    var overlayState: WebOverlayState = .showingToolbars

    private var initialURL: URL?

    /// Tracks the last scroll offset for scroll direction detection
    private var lastScrollOffset: CGFloat = 0
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
        guard !readingModeEnabled else { return }

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
        Task {
            let loadSequence = page.load(url)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func goBack() {
        guard let page, let item = page.backForwardList.backList.last else { return }
        Task {
            let loadSequence = page.load(item)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func goForward() {
        guard let page, let item = page.backForwardList.forwardList.first else { return }
        Task {
            let loadSequence = page.load(item)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func reload() {
        guard let page else { return }
        Task {
            let loadSequence = page.reload()
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
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

    func lookupCluster(at location: CGPoint, in viewSize: CGSize) async -> WebLookupSelection? {
        guard !ocrViewModel.isProcessing else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        guard let page else { return nil }

        do {
            let imageData = try await captureViewportSnapshot(page: page, viewportSize: viewSize)
            let screenshotURL = await writeJPEGContextImage(imageData, prefix: "web_snapshot")
            let clusters = await ocrViewModel.performOCR(imageData: imageData)
            guard !clusters.isEmpty else { return nil }

            let normalized = CGPoint(
                x: location.x / viewSize.width,
                y: 1 - (location.y / viewSize.height)
            )
            guard let cluster = ocrViewModel.nearestCluster(to: normalized) else { return nil }

            let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = title.isEmpty ? "Web page" : title
            let urlString = page.url?.absoluteString ?? "Unknown URL"
            let contextValues = LookupContextValues(
                contextInfo: "\(displayTitle) - \(urlString)",
                documentCoverImageURL: nil,
                screenshotURL: screenshotURL,
                sourceType: .web
            )
            return WebLookupSelection(cluster: cluster, contextValues: contextValues)
        } catch {
            ocrViewModel.errorMessage = error.localizedDescription
            return nil
        }
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

    private struct ViewportInfo {
        let rect: CGRect
        let snapshotWidth: CGFloat
    }

    private func captureViewportSnapshot(page: WebPage, viewportSize: CGSize) async throws -> Data {
        if let viewportInfo = try await fetchViewportInfo(page: page) {
            let configuration = WebPage.ExportedContentConfiguration.image(
                region: .rect(viewportInfo.rect),
                snapshotWidth: viewportInfo.snapshotWidth
            )
            return try await page.exported(as: configuration)
        }

        let configuration = WebPage.ExportedContentConfiguration.image(
            region: .contents,
            snapshotWidth: viewportSize.width > 0 ? viewportSize.width : nil
        )
        return try await page.exported(as: configuration)
    }

    private func fetchViewportInfo(page: WebPage) async throws -> ViewportInfo? {
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
}
