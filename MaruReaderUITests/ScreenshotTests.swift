// ScreenshotTests.swift
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

import XCTest

/// Automated screenshot capture for documentation and App Store submissions.
///
/// Run via fastlane:
/// ```
/// just screenshots
/// ```
///
/// Run a single screenshot test (without fastlane collection):
/// ```
/// just test-one 'MaruReaderUITests/ScreenshotTests/testScreenshot_BookLibrary()' MaruReaderUITests
/// ```
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["--screenshotMode"]
        setupSnapshot(app)
        app.launch()

        // Wait for startup to complete and main UI to appear.
        // In screenshot mode the welcome screen auto-dismisses.
        let readTab = app.buttons["Read"].firstMatch
        XCTAssertTrue(
            readTab.waitForExistence(timeout: 60),
            "App did not finish startup within timeout"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Library Screenshots

    @MainActor
    func testScreenshot_BookLibrary() {
        navigateToTab("Read")
        selectLibrarySegment("Books")
        sleep(2)
        snapshot("01-BookLibrary")
    }

    @MainActor
    func testScreenshot_MangaLibrary() {
        navigateToTab("Read")
        selectLibrarySegment("Manga")
        sleep(2)
        snapshot("02-MangaLibrary")
    }

    // MARK: - Book Reader Screenshots

    @MainActor
    func testScreenshot_BookDictionary() {
        openBook("こころ")
        sleep(3)

        // In screenshot mode, dictionary mode is auto-enabled and a lookup
        // for "呼んでいた" is auto-triggered to demonstrate verb deinflection.
        // Wait for the popover to appear.
        let dictionaryPopover = app.otherElements["bookReader.dictionaryPopover"].firstMatch
        if !dictionaryPopover.waitForExistence(timeout: 15) {
            // Fallback: tap on text content in the reader to trigger a lookup.
            let readerArea = app.otherElements.firstMatch
            let center = readerArea.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
            sleep(2)
        }

        snapshot("03-BookDictionary")
    }

    // MARK: - Manga Reader Screenshots

    @MainActor
    func testScreenshot_MangaDictionary() {
        openManga()
        sleep(3)

        // In screenshot mode, the manga viewer auto-triggers a dictionary lookup
        // using the OCR cluster that begins with "教授の実験" when available.
        // Wait for the sheet to appear.
        let dictionarySheet = app.otherElements["mangaReader.dictionarySheet"].firstMatch
        if dictionarySheet.waitForExistence(timeout: 10) {
            snapshot("04-MangaDictionary")
        } else {
            // Fallback: tap in the center of the page where OCR text clusters are likely
            let pageArea = app.windows.firstMatch
            let center = pageArea.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            center.tap()
            sleep(2)
            snapshot("04-MangaDictionary")
        }
    }

    // MARK: - Web Browser Screenshots

    @MainActor
    func testScreenshot_WebDictionary() {
        navigateToWebViewer()

        // In screenshot mode, the web viewer auto-triggers a dictionary lookup
        // for "咲き誇り" after a delay to demonstrate edit-menu dictionary integration.
        let dictionarySheet = app.otherElements["web.editMenuDictionarySheet"].firstMatch
        if !dictionarySheet.waitForExistence(timeout: 15) {
            // Fallback: long-press on text and tap the Dictionary button in the edit menu.
            let webView = app.webViews.firstMatch
            if webView.waitForExistence(timeout: 5) {
                let textArea = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                textArea.press(forDuration: 1.0)
                sleep(1)
                let dictionaryButton = app.menuItems["Dictionary"].firstMatch
                if dictionaryButton.waitForExistence(timeout: 5) {
                    dictionaryButton.tap()
                }
            }
        }
        sleep(2)
        snapshot("05-WebDictionary")
    }

    // MARK: - Dictionary Search Screenshot

    @MainActor
    func testScreenshot_DictionarySearch() {
        // Tap the search tab (role: .search shows as a magnifying glass)
        let searchTab = app.buttons["Search"].firstMatch
        if searchTab.waitForExistence(timeout: 5) {
            searchTab.tap()
        }

        // Type a search query
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("読む")
        }
        sleep(2)
        snapshot("06-DictionarySearch")
    }

    // MARK: - Helpers

    private func navigateToTab(_ tabName: String) {
        let tab = app.buttons[tabName].firstMatch
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        }
    }

    private func selectLibrarySegment(_ segmentName: String) {
        let segment = app.buttons[segmentName].firstMatch
        if segment.waitForExistence(timeout: 5) {
            segment.tap()
        }
    }

    /// Navigates to the Web tab and waits for the web viewer to auto-present.
    /// In screenshot mode, the bookmarks view auto-navigates and sample content loads.
    private func navigateToWebViewer() {
        navigateToTab("Web")

        let webView = app.webViews.firstMatch
        _ = webView.waitForExistence(timeout: 10)
    }

    private func openBook(_ titleSubstring: String) {
        navigateToTab("Read")
        selectLibrarySegment("Books")
        sleep(1)

        let bookButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", titleSubstring)
        ).firstMatch
        if bookButton.waitForExistence(timeout: 10) {
            bookButton.tap()
        }
        sleep(3)
    }

    private func openManga() {
        navigateToTab("Read")
        selectLibrarySegment("Manga")
        sleep(1)

        let mangaButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "ブラックジャックによろしく 01")
        ).firstMatch
        if mangaButton.waitForExistence(timeout: 10) {
            mangaButton.tap()
        }
        sleep(3)
    }
}
