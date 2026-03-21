// BookReaderOverlayStateTests.swift
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

@testable import MaruReader
import Testing

struct BookReaderChromeRouteTests {
    @Test func shouldShowToolbars_IncludesReaderPopovers() {
        #expect(BookReaderChromeRoute.showingQuickSettings.shouldShowToolbars)
        #expect(BookReaderChromeRoute.showingBookmarks.shouldShowToolbars)
    }

    @Test func settingPresentation_PresentsRequestedOverlay() {
        let state = BookReaderChromeRoute.showingToolbars.settingPresentation(true, for: .showingBookmarks)

        #expect(state == .showingBookmarks)
    }

    @Test func settingPresentation_DismissesPresentedOverlayToToolbars() {
        let bookmarksState = BookReaderChromeRoute.showingBookmarks.settingPresentation(false, for: .showingBookmarks)
        let quickSettingsState = BookReaderChromeRoute.showingQuickSettings.settingPresentation(false, for: .showingQuickSettings)

        #expect(bookmarksState == .showingToolbars)
        #expect(quickSettingsState == .showingToolbars)
    }

    @Test func settingPresentation_LeavesOtherOverlayUntouchedWhenDismissed() {
        let state = BookReaderChromeRoute.showingQuickSettings.settingPresentation(false, for: .showingBookmarks)

        #expect(state == .showingQuickSettings)
    }

    // MARK: - Computed Bool property behavior (via settingPresentation)

    @Test func settingPresentation_GetterReturnsTrueOnlyForMatchingState() {
        let toc = BookReaderChromeRoute.showingTableOfContents
        let quickSettings = BookReaderChromeRoute.showingQuickSettings
        let bookmarks = BookReaderChromeRoute.showingBookmarks

        // Each state should report true only for itself
        #expect(toc == .showingTableOfContents)
        #expect(quickSettings != .showingTableOfContents)
        #expect(bookmarks != .showingTableOfContents)

        #expect(quickSettings == .showingQuickSettings)
        #expect(toc != .showingQuickSettings)
        #expect(bookmarks != .showingQuickSettings)

        #expect(bookmarks == .showingBookmarks)
        #expect(toc != .showingBookmarks)
        #expect(quickSettings != .showingBookmarks)
    }

    @Test func settingPresentation_SetTruePresentsOverlay() {
        let fromToolbars = BookReaderChromeRoute.showingToolbars.settingPresentation(true, for: .showingTableOfContents)
        let fromNone = BookReaderChromeRoute.none.settingPresentation(true, for: .showingQuickSettings)
        let fromOther = BookReaderChromeRoute.showingBookmarks.settingPresentation(true, for: .showingTableOfContents)

        #expect(fromToolbars == .showingTableOfContents)
        #expect(fromNone == .showingQuickSettings)
        #expect(fromOther == .showingTableOfContents)
    }

    @Test func settingPresentation_SetFalseDismissesToToolbars() {
        let dismissToc = BookReaderChromeRoute.showingTableOfContents.settingPresentation(false, for: .showingTableOfContents)
        let dismissQuickSettings = BookReaderChromeRoute.showingQuickSettings.settingPresentation(false, for: .showingQuickSettings)
        let dismissBookmarks = BookReaderChromeRoute.showingBookmarks.settingPresentation(false, for: .showingBookmarks)

        #expect(dismissToc == .showingToolbars)
        #expect(dismissQuickSettings == .showingToolbars)
        #expect(dismissBookmarks == .showingToolbars)
    }

    @Test func settingPresentation_SetFalseForDifferentStateIsNoOp() {
        let state = BookReaderChromeRoute.showingQuickSettings.settingPresentation(false, for: .showingTableOfContents)

        #expect(state == .showingQuickSettings)
    }
}
