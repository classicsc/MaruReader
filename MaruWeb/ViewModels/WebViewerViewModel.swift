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

// MARK: - ReadingPagingMode

/// Determines how swipe gestures behave in reading mode.
enum ReadingPagingMode: String, CaseIterable {
    /// Vertical swipes scroll content one screen at a time (for articles/blogs).
    case verticalScroll

    /// Horizontal swipes send arrow key presses for paged readers (ebooks/manga).
    case horizontalPaging
}

// MARK: - WebViewerViewModel

@MainActor
@Observable
final class WebViewerViewModel {
    let page: WebPage
    let ocrViewModel: WebOCRViewModel
    private let bookmarkManager: WebBookmarkManager

    var addressBarText: String = ""
    var readingModeEnabled = false
    var isBookmarked = false
    var overlayState: WebOverlayState = .showingToolbars
    var pagingMode: ReadingPagingMode = .verticalScroll

    private let session: WebSession
    private var initialURL: URL?

    /// Tracks the last scroll offset for scroll direction detection
    private var lastScrollOffset: CGFloat = 0
    /// Minimum scroll distance required to trigger toolbar visibility change
    private let scrollThreshold: CGFloat = 20

    init(
        initialURL: URL? = nil,
        session: WebSession = WebSession(),
        ocrViewModel: WebOCRViewModel = WebOCRViewModel(),
        bookmarkManager: WebBookmarkManager = .shared
    ) {
        self.session = session
        self.ocrViewModel = ocrViewModel
        self.bookmarkManager = bookmarkManager
        self.page = session.page
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

    func togglePagingMode() {
        switch pagingMode {
        case .verticalScroll:
            pagingMode = .horizontalPaging
        case .horizontalPaging:
            pagingMode = .verticalScroll
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

    func lookupCluster(at location: CGPoint, in viewSize: CGSize) async -> TextCluster? {
        guard !ocrViewModel.isProcessing else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        do {
            let imageData = try await captureViewportSnapshot(viewportSize: viewSize)
            let clusters = await ocrViewModel.performOCR(imageData: imageData)
            guard !clusters.isEmpty else { return nil }

            let normalized = CGPoint(
                x: location.x / viewSize.width,
                y: 1 - (location.y / viewSize.height)
            )
            return ocrViewModel.nearestCluster(to: normalized)
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

    // MARK: - Reading Mode Paging

    /// Scrolls the page by a specified amount relative to the viewport height.
    /// - Parameter direction: Positive scrolls down, negative scrolls up.
    func scrollByPage(direction: Int) {
        let script = """
        window.scrollBy({
            top: window.innerHeight * \(direction) * 0.9,
            behavior: 'smooth'
        });
        """
        Task { @MainActor in
            _ = try? await self.page.callJavaScript(script)
        }
    }

    /// Sends an arrow key press to the page for horizontal paging.
    /// Tries multiple dispatch targets and event types to maximize compatibility with web readers.
    /// - Parameter isLeft: true for left arrow (previous), false for right arrow (next).
    func sendArrowKey(isLeft: Bool) {
        let key = isLeft ? "ArrowLeft" : "ArrowRight"
        let keyCode = isLeft ? 37 : 39
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
