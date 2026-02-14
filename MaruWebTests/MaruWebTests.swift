// MaruWebTests.swift
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
@testable import MaruWeb
import Testing
import WebKit

struct MaruWebTests {
    @Test func normalizedURLAddsScheme() {
        let url = WebAddressParser.normalizedURL(from: "bookwalker.jp")
        #expect(url?.absoluteString == "https://bookwalker.jp")
    }

    @Test func normalizedURLPreservesScheme() {
        let url = WebAddressParser.normalizedURL(from: "https://example.com/path")
        #expect(url?.absoluteString == "https://example.com/path")
    }

    @Test func normalizedURLRejectsWhitespace() {
        let url = WebAddressParser.normalizedURL(from: "not a url")
        #expect(url == nil)
    }

    @Test func addBookmarkPersistsEntry() async throws {
        let persistence = WebDataPersistenceController(inMemory: true)
        let manager = WebBookmarkManager(persistenceController: persistence)
        let url = try #require(URL(string: "https://bookwalker.jp"))

        let snapshot = try await manager.addBookmark(url: url, title: "Bookwalker")
        #expect(snapshot.url == url)
        #expect(snapshot.title == "Bookwalker")

        let bookmarks = try await manager.fetchBookmarks()
        #expect(bookmarks.count == 1)
        #expect(bookmarks.first?.url == url)
    }

    @Test func toggleBookmarkRemovesExisting() async throws {
        let persistence = WebDataPersistenceController(inMemory: true)
        let manager = WebBookmarkManager(persistenceController: persistence)
        let url = try #require(URL(string: "https://example.com"))

        let isBookmarked = try await manager.toggleBookmark(url: url, title: "Example")
        #expect(isBookmarked == true)

        let isNowBookmarked = try await manager.toggleBookmark(url: url, title: "Example")
        #expect(isNowBookmarked == false)

        let bookmarks = try await manager.fetchBookmarks()
        #expect(bookmarks.isEmpty)
    }

    @Test func contentBlockingDefaultsToEnabled() {
        let defaults = UserDefaults.standard
        let key = WebContentBlockingSettings.contentBlockingEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        #expect(
            WebContentBlockingSettings.contentBlockingEnabled
                == WebContentBlockingSettings.contentBlockingEnabledDefault
        )
    }

    @Test func contentBlockingPersistsChanges() {
        let defaults = UserDefaults.standard
        let key = WebContentBlockingSettings.contentBlockingEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        WebContentBlockingSettings.contentBlockingEnabled = false
        #expect(WebContentBlockingSettings.contentBlockingEnabled == false)
        WebContentBlockingSettings.contentBlockingEnabled = true
        #expect(WebContentBlockingSettings.contentBlockingEnabled == true)
    }

    @Test @MainActor func webSessionStoreConsumesPrewarm() async {
        let store = WebSessionStore()
        store.prewarm(enableContentBlocking: false)
        let firstSession = await store.makeSession(enableContentBlocking: false)
        let secondSession = await store.makeSession(enableContentBlocking: false)
        #expect(firstSession !== secondSession)
    }

    @Test @MainActor func extensionManagerReturnsSameController() async {
        let manager = WebExtensionManager()
        let first = await manager.extensionController()
        let second = await manager.extensionController()
        #expect(first === second)
    }

    @Test @MainActor func extensionManagerCoalescesConcurrentCalls() async {
        let manager = WebExtensionManager()
        async let a = manager.extensionController()
        async let b = manager.extensionController()
        let (first, second) = await (a, b)
        #expect(first === second)
    }

    @Test @MainActor func sessionsShareExtensionController() async {
        let store = WebSessionStore()
        let first = await store.makeSession(enableContentBlocking: true)
        let second = await store.makeSession(enableContentBlocking: true)
        let firstController = first.page.webView.configuration.webExtensionController
        let secondController = second.page.webView.configuration.webExtensionController
        #expect(firstController != nil)
        #expect(firstController === secondController)
    }

    @Test @MainActor func sessionHasNoControllerWhenBlockingDisabled() async {
        let store = WebSessionStore()
        let session = await store.makeSession(enableContentBlocking: false)
        #expect(session.page.webView.configuration.webExtensionController == nil)
    }

    @Test @MainActor func webViewerPreparesSingleInitialTab() async {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTabID == viewModel.tabs.first?.id)
        #expect(viewModel.page != nil)
    }

    @Test @MainActor func closingLastTabRequestsDismissal() async throws {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()
        let tabID = try #require(viewModel.selectedTabID)

        viewModel.closeTab(id: tabID)

        #expect(viewModel.dismissViewerRequestID != nil)
        #expect(viewModel.tabs.isEmpty)
    }

    @Test @MainActor func addTabSelectsNewTab() async throws {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()
        let initialSelected = try #require(viewModel.selectedTabID)

        viewModel.addTab()
        await waitForTabCount(2, in: viewModel)

        #expect(viewModel.tabs.count == 2)
        #expect(viewModel.selectedTabID != initialSelected)
    }

    @Test @MainActor func closingSelectedTabSelectsAdjacentTab() async throws {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()
        viewModel.addTab()
        await waitForTabCount(2, in: viewModel)

        let firstTab = try #require(viewModel.tabs.first?.id)
        let secondTab = try #require(viewModel.tabs.last?.id)
        viewModel.switchToTab(id: firstTab)

        viewModel.closeTab(id: firstTab)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.selectedTabID == secondTab)
    }

    @Test @MainActor func moveTabsReordersAndPreservesSelection() async {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()
        viewModel.addTab()
        viewModel.addTab()
        await waitForTabCount(3, in: viewModel)

        let originalIDs = viewModel.tabs.map(\.id)
        let selectedBeforeMove = viewModel.selectedTabID

        viewModel.moveTabs(from: IndexSet(integer: 2), to: 0)

        #expect(viewModel.tabs.count == 3)
        #expect(viewModel.tabs.first?.id == originalIDs[2])
        #expect(viewModel.selectedTabID == selectedBeforeMove)
    }

    @Test @MainActor func scrollHidesAndShowsToolbarsWhenNotInOCRMode() {
        let viewModel = WebViewerViewModel()
        viewModel.readingModeEnabled = false
        viewModel.overlayState = .showingToolbars

        viewModel.handleScrollOffsetChange(from: 0, to: 24)
        #expect(viewModel.overlayState == .none)

        viewModel.handleScrollOffsetChange(from: 24, to: 0)
        #expect(viewModel.overlayState == .showingToolbars)
    }

    @Test @MainActor func scrollDoesNotChangeToolbarVisibilityInOCRMode() {
        let viewModel = WebViewerViewModel()
        viewModel.readingModeEnabled = true
        viewModel.overlayState = .showingToolbars

        viewModel.handleScrollOffsetChange(from: 0, to: 24)
        #expect(viewModel.overlayState == .showingToolbars)

        viewModel.overlayState = .none
        viewModel.handleScrollOffsetChange(from: 24, to: 0)
        #expect(viewModel.overlayState == .none)
    }

    @Test @MainActor func scrollInReadingModeInvalidatesOCRCache() {
        let viewModel = WebViewerViewModel()
        viewModel.readingModeEnabled = true

        // Simulate cached OCR results (empty observations, but cluster exists)
        viewModel.ocrViewModel.clusters = [
            TextCluster(observations: [], direction: .horizontal),
        ]
        #expect(!viewModel.ocrViewModel.clusters.isEmpty)

        // Scroll should clear cached results
        viewModel.handleScrollOffsetChange(from: 0, to: 24)
        #expect(viewModel.ocrViewModel.clusters.isEmpty)
    }

    @Test @MainActor func showBoundingBoxesDefaultsToFalse() {
        let viewModel = WebViewerViewModel()
        #expect(viewModel.showBoundingBoxes == false)
    }

    @Test @MainActor func highlightedClusterDefaultsToNil() {
        let viewModel = WebViewerViewModel()
        #expect(viewModel.highlightedCluster == nil)
    }

    @Test @MainActor func lookupSelectionExitsReadingMode() {
        let viewModel = WebViewerViewModel()
        viewModel.readingModeEnabled = true
        viewModel.overlayState = .none

        viewModel.exitReadingModeAfterLookupSelection()

        #expect(viewModel.readingModeEnabled == false)
        #expect(viewModel.overlayState == .showingToolbars)
    }

    @Test @MainActor func ocrCacheResetClearsAllState() {
        let ocrVM = WebOCRViewModel()
        ocrVM.clusters = [
            TextCluster(observations: [], direction: .vertical),
        ]
        ocrVM.errorMessage = "test error"

        ocrVM.reset()

        #expect(ocrVM.clusters.isEmpty)
        #expect(ocrVM.image == nil)
        #expect(ocrVM.errorMessage == nil)
        #expect(ocrVM.isProcessing == false)
    }

    @Test func viewportInfoParsesNSNumberValues() {
        let value: [String: Any] = [
            "scrollX": NSNumber(value: 12.5),
            "scrollY": NSNumber(value: 48),
            "width": NSNumber(value: 375),
            "height": NSNumber(value: 812),
        ]

        let viewportInfo = WebViewerViewModel.viewportInfo(from: value)

        #expect(viewportInfo?.rect == CGRect(x: 12.5, y: 48, width: 375, height: 812))
        #expect(viewportInfo?.snapshotWidth == 375)
    }

    @Test func viewportInfoRejectsMissingKeys() {
        let value: [String: Any] = [
            "scrollX": NSNumber(value: 12.5),
            "width": NSNumber(value: 375),
            "height": NSNumber(value: 812),
        ]

        let viewportInfo = WebViewerViewModel.viewportInfo(from: value)

        #expect(viewportInfo == nil)
    }

    @Test @MainActor func newTabPageShownForFreshTab() async {
        let viewModel = WebViewerViewModel()
        await viewModel.prepareSessionIfNeeded()

        #expect(viewModel.isShowingNewTabPage == true)
    }

    @Test @MainActor func newTabPageHiddenWhenPageHasURL() async throws {
        let viewModel = WebViewerViewModel(
            initialURL: URL(string: "https://example.com")
        )
        await viewModel.prepareSessionIfNeeded()

        // Wait for WKWebView KVO to propagate url/isLoading
        for _ in 0 ..< 60 {
            if !viewModel.isShowingNewTabPage { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(viewModel.isShowingNewTabPage == false)
    }

    @Test @MainActor func newTabPageFalseWithoutPage() {
        let viewModel = WebViewerViewModel()
        #expect(viewModel.page == nil)
        #expect(viewModel.isShowingNewTabPage == false)
    }

    @MainActor
    private func waitForTabCount(_ expectedCount: Int, in viewModel: WebViewerViewModel) async {
        for _ in 0 ..< 60 {
            if viewModel.tabs.count == expectedCount {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
