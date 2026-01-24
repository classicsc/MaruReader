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

// MARK: - Reading Paging

/// Determines the swipe axis in reading mode.
enum ReadingPagingAxis: String, CaseIterable {
    case vertical
    case horizontal
}

/// Determines how paging is triggered for a given axis.
enum ReadingPagingBehavior: String, CaseIterable {
    case scroll
    case keypress
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
    let page: WebPage
    let ocrViewModel: WebOCRViewModel
    private let bookmarkManager: WebBookmarkManager
    private let session: WebSession

    var addressBarText: String = ""
    var readingModeEnabled = false
    var isBookmarked = false
    var overlayState: WebOverlayState = .showingToolbars
    var pagingAxis: ReadingPagingAxis = .vertical
    var pagingBehavior: ReadingPagingBehavior = .scroll

    private var initialURL: URL?

    /// Tracks the last scroll offset for scroll direction detection
    private var lastScrollOffset: CGFloat = 0
    /// Minimum scroll distance required to trigger toolbar visibility change
    private let scrollThreshold: CGFloat = 20

    init(
        initialURL: URL? = nil,
        ocrViewModel: WebOCRViewModel = WebOCRViewModel(),
        bookmarkManager: WebBookmarkManager = .shared
    ) {
        let session = WebSession(enableContentBlocking: WebContentBlockingSettings.contentBlockingEnabled)
        self.session = session
        self.page = session.page
        self.ocrViewModel = ocrViewModel
        self.bookmarkManager = bookmarkManager
        self.initialURL = initialURL
        if let initialURL {
            addressBarText = initialURL.absoluteString
        }
    }

    func toggleOverlay() {
        switch overlayState {
        case .none:
            overlayState = .showingToolbars
        case .showingToolbars:
            overlayState = .none
        }
    }

    func togglePagingAxis() {
        pagingAxis = pagingAxis == .vertical ? .horizontal : .vertical
    }

    func togglePagingBehavior() {
        pagingBehavior = pagingBehavior == .scroll ? .keypress : .scroll
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
        guard let initialURL else { return }
        self.initialURL = nil
        navigate(to: initialURL)
    }

    func navigate(to rawValue: String) {
        guard let url = WebAddressParser.normalizedURL(from: rawValue) else { return }
        navigate(to: url)
    }

    func navigate(to url: URL) {
        addressBarText = url.absoluteString
        Task {
            let loadSequence = page.load(url)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func goBack() {
        guard let item = page.backForwardList.backList.last else { return }
        Task {
            let loadSequence = page.load(item)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func goForward() {
        guard let item = page.backForwardList.forwardList.first else { return }
        Task {
            let loadSequence = page.load(item)
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func reload() {
        Task {
            let loadSequence = page.reload()
            for try await _ in loadSequence {
                if Task.isCancelled { return }
            }
        }
    }

    func stopLoading() {
        page.stopLoading()
    }

    func toggleBookmark() {
        guard let url = page.url else { return }
        let title = page.title
        Task {
            do {
                let isNowBookmarked = try await bookmarkManager.toggleBookmark(url: url, title: title)
                await MainActor.run {
                    self.isBookmarked = isNowBookmarked
                }
            } catch {
                return
            }
        }
    }

    func lookupCluster(at location: CGPoint, in viewSize: CGSize) async -> WebLookupSelection? {
        guard !ocrViewModel.isProcessing else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        do {
            let imageData = try await captureViewportSnapshot(viewportSize: viewSize)
            let screenshotURL = await writeJPEGContextImage(imageData, prefix: "web_snapshot")
            let clusters = await ocrViewModel.performOCR(imageData: imageData)
            guard !clusters.isEmpty else { return nil }

            let normalized = CGPoint(
                x: location.x / viewSize.width,
                y: 1 - (location.y / viewSize.height)
            )
            guard let cluster = ocrViewModel.nearestCluster(to: normalized) else { return nil }

            let contextValues = LookupContextValues(
                documentTitle: page.title,
                documentURL: page.url,
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
        Task {
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

    private func captureViewportSnapshot(viewportSize: CGSize) async throws -> Data {
        if let viewportInfo = try await fetchViewportInfo() {
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

    // MARK: - Reading Mode Paging

    func performPagingAction(axis: ReadingPagingAxis, behavior: ReadingPagingBehavior, direction: Int) {
        switch behavior {
        case .scroll:
            scrollByPage(axis: axis, direction: direction)
        case .keypress:
            sendPagingKey(axis: axis, direction: direction)
        }
    }

    /// Scrolls the page by a specified amount relative to the viewport.
    /// - Parameter direction: Positive scrolls down/right, negative scrolls up/left.
    func scrollByPage(axis: ReadingPagingAxis, direction: Int) {
        let script = switch axis {
        case .vertical:
            """
            window.scrollBy({
                top: window.innerHeight * \(direction) * 0.9,
                behavior: 'smooth'
            });
            """
        case .horizontal:
            """
            window.scrollBy({
                left: window.innerWidth * \(direction) * 0.9,
                behavior: 'smooth'
            });
            """
        }
        Task { @MainActor in
            _ = try? await self.page.callJavaScript(script)
        }
    }

    /// Sends an arrow key press to the page for paging.
    /// Tries multiple dispatch targets and event types to maximize compatibility with web readers.
    /// - Parameter direction: Positive moves down/right, negative moves up/left.
    func sendPagingKey(axis: ReadingPagingAxis, direction: Int) {
        let (key, keyCode): (String, Int)
        switch axis {
        case .horizontal:
            let isLeft = direction < 0
            key = isLeft ? "ArrowLeft" : "ArrowRight"
            keyCode = isLeft ? 37 : 39
        case .vertical:
            let isUp = direction < 0
            key = isUp ? "ArrowUp" : "ArrowDown"
            keyCode = isUp ? 38 : 40
        }
        let script = """
        if (!document.activeElement || document.activeElement === document.body) {
          document.body.tabIndex = document.body.tabIndex || 0;
          document.body.focus();
        }
        const opts = {
            key: '\(key)',
            code: '\(key)',
            keyCode: \(keyCode),
            which: \(keyCode),
            bubbles: true,
            cancelable: true
        };

        const target = document.activeElement || document;
        target.dispatchEvent(new KeyboardEvent('keydown', opts));
        target.dispatchEvent(new KeyboardEvent('keyup', opts));
        """
        Task { @MainActor in
            _ = try? await self.page.callJavaScript(script)
        }
    }
}
