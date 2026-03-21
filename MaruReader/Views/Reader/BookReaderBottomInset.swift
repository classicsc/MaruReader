// BookReaderBottomInset.swift
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

import MaruDictionaryUICommon
import SwiftUI

struct BookReaderBottomInset: View {
    @Bindable var chrome: BookReaderChromeModel
    @Bindable var bookmarks: BookReaderBookmarksModel
    @Bindable var readerPreferences: ReaderPreferences
    let progressDisplayText: String?
    let toolbarForegroundColor: SwiftUI.Color
    let toolbarSecondaryColor: SwiftUI.Color
    let theme: DictionaryPresentationTheme
    let onSelectAppearanceMode: (ReaderAppearanceMode) -> Void
    let onCycleProgressDisplayMode: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(height: 88)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .hidden()

            if chrome.showsToolbars {
                HStack(spacing: 32) {
                    Button("Table of contents", systemImage: "list.bullet") {
                        chrome.route = .showingTableOfContents
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("bookReader.tableOfContents")
                    .tourAnchor(BookReaderTourAnchor.tableOfContents)

                    Button(
                        chrome.isDictionaryActive ? "Disable dictionary mode" : "Enable dictionary mode",
                        systemImage: chrome.isDictionaryActive ? "character.book.closed.fill.ja" : "character.book.closed.ja"
                    ) {
                        chrome.isDictionaryActive.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("bookReader.dictionaryMode")
                    .tourAnchor(BookReaderTourAnchor.dictionaryMode)

                    Button("Bookmarks", systemImage: bookmarks.isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark") {
                        chrome.isShowingBookmarks.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("bookReader.bookmarksButton")
                    .tourAnchor(BookReaderTourAnchor.bookmark)
                    .popover(
                        isPresented: $chrome.isShowingBookmarks,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderBookmarksPopover(
                            rows: bookmarks.bookmarkRows,
                            currentBookmarkID: bookmarks.currentLocationBookmarkID,
                            isCurrentLocationBookmarked: bookmarks.isCurrentLocationBookmarked,
                            canReturnToPreviousLocation: bookmarks.previousLocation != nil,
                            theme: theme,
                            onAddBookmark: {
                                bookmarks.bookmarkCurrentLocation()
                                chrome.isShowingBookmarks = false
                            },
                            onRemoveBookmark: {
                                bookmarks.removeBookmarkAtCurrentLocation()
                                chrome.isShowingBookmarks = false
                            },
                            onNavigateToBookmark: { bookmark in
                                bookmarks.navigateToBookmark(bookmark) {
                                    chrome.route = .none
                                }
                            },
                            onReturnToPreviousLocation: {
                                bookmarks.returnToPreviousLocation {
                                    chrome.route = .none
                                }
                            },
                            onDismiss: {
                                chrome.isShowingBookmarks = false
                            }
                        )
                        .accessibilityIdentifier("bookReader.bookmarksPopover")
                    }

                    Button("Appearance and text", systemImage: "textformat") {
                        chrome.isShowingQuickSettings.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("bookReader.appearanceButton")
                    .tourAnchor(BookReaderTourAnchor.appearanceMenu)
                    .popover(
                        isPresented: $chrome.isShowingQuickSettings,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderAppearancePopover(
                            readerPreferences: readerPreferences,
                            theme: theme,
                            onSelectAppearanceMode: onSelectAppearanceMode,
                            onDismiss: {
                                chrome.isShowingQuickSettings = false
                            }
                        )
                        .accessibilityIdentifier("bookReader.appearancePopover")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .buttonStyle(.plain)
                .foregroundStyle(toolbarForegroundColor)
                .background(
                    Capsule()
                        .fill(.clear)
                        .glassEffect()
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let progressDisplayText {
                Button(action: onCycleProgressDisplayMode) {
                    Text(progressDisplayText)
                        .font(.caption)
                        .foregroundStyle(toolbarSecondaryColor.opacity(0.6))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityLabel("Reading progress")
                .accessibilityValue(progressDisplayText)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
