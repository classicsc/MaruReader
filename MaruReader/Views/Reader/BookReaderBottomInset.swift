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

import CoreData
import MaruDictionaryUICommon
import SwiftUI

struct BookReaderBottomInset: View {
    @Bindable var viewModel: BookReaderViewModel
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

            if viewModel.overlayState.shouldShowToolbars {
                HStack(spacing: 32) {
                    Button {
                        viewModel.overlayState = .showingTableOfContents
                    } label: {
                        Image(systemName: "list.bullet")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Table of contents")
                    .accessibilityIdentifier("bookReader.tableOfContents")
                    .tourAnchor(BookReaderTourAnchor.tableOfContents)

                    Button {
                        viewModel.isDictionaryActive.toggle()
                    } label: {
                        Image(systemName: viewModel.isDictionaryActive ? "character.book.closed.fill.ja" : "character.book.closed.ja")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel(viewModel.isDictionaryActive ? "Disable dictionary mode" : "Enable dictionary mode")
                    .accessibilityIdentifier("bookReader.dictionaryMode")
                    .tourAnchor(BookReaderTourAnchor.dictionaryMode)

                    Button {
                        viewModel.isShowingBookmarks.toggle()
                    } label: {
                        Image(systemName: viewModel.currentLocationBookmark != nil ? "bookmark.fill" : "bookmark")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Bookmarks")
                    .accessibilityIdentifier("bookReader.bookmarksButton")
                    .tourAnchor(BookReaderTourAnchor.bookmark)
                    .popover(
                        isPresented: $viewModel.isShowingBookmarks,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderBookmarksPopover(
                            bookmarks: viewModel.bookmarks,
                            currentBookmarkID: viewModel.currentLocationBookmark?.objectID,
                            isCurrentLocationBookmarked: viewModel.currentLocationBookmark != nil,
                            canReturnToPreviousLocation: viewModel.previousLocation != nil,
                            theme: theme,
                            onAddBookmark: {
                                viewModel.bookmarkCurrentLocation()
                                viewModel.isShowingBookmarks = false
                            },
                            onRemoveBookmark: {
                                viewModel.removeBookmarkAtCurrentLocation()
                                viewModel.isShowingBookmarks = false
                            },
                            onNavigateToBookmark: { bookmark in
                                viewModel.navigateToBookmark(bookmark)
                            },
                            onReturnToPreviousLocation: {
                                viewModel.returnToPreviousLocation()
                            },
                            onDismiss: {
                                viewModel.isShowingBookmarks = false
                            }
                        )
                        .accessibilityIdentifier("bookReader.bookmarksPopover")
                    }

                    Button {
                        viewModel.isShowingQuickSettings.toggle()
                    } label: {
                        Image(systemName: "textformat")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Appearance and text")
                    .accessibilityIdentifier("bookReader.appearanceButton")
                    .tourAnchor(BookReaderTourAnchor.appearanceMenu)
                    .popover(
                        isPresented: $viewModel.isShowingQuickSettings,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderAppearancePopover(
                            readerPreferences: viewModel.readerPreferences,
                            theme: theme,
                            onSelectAppearanceMode: onSelectAppearanceMode,
                            onDismiss: {
                                viewModel.isShowingQuickSettings = false
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
                        .padding(.vertical, 8)
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
