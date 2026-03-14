// WebViewerOverflowMenuButton.swift
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
import Observation
import SwiftUI

struct WebViewerOverflowMenuButton: View {
    @Bindable var viewModel: WebViewerViewModel
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let glassNamespace: Namespace.ID
    let onDismiss: () -> Void

    var body: some View {
        let isLoading = viewModel.page?.isLoading == true

        Menu {
            Button(action: reloadOrStopLoading) {
                if isLoading {
                    Label("Stop Loading", systemImage: "xmark")
                } else {
                    Label {
                        Text(WebLocalization.string("Reload", comment: "A button label that reloads the current webpage."))
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }

            Menu {
                if viewModel.isBookmarked {
                    Button(role: .destructive, action: removeBookmark) {
                        Label("Remove Bookmark", systemImage: "bookmark.slash")
                    }
                } else {
                    Button(action: addBookmark) {
                        Label("Add Bookmark", systemImage: "bookmark.fill")
                    }
                }

                if !viewModel.bookmarks.isEmpty {
                    Section {
                        ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                            Button {
                                navigate(to: bookmark.url)
                            } label: {
                                HStack(spacing: 8) {
                                    BookmarkFaviconView(data: bookmark.favicon, size: 16)
                                    Text(bookmark.title)
                                }
                            }
                        }
                    } header: {
                        Text(
                            WebLocalization.string(
                                "Saved Bookmarks",
                                comment: "A section header in the more actions overflow menu that lists saved bookmarks."
                            )
                        )
                    }
                }
            } label: {
                Label("Bookmarks", systemImage: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
            }

            Divider()

            Button(action: onDismiss) {
                Label {
                    Text(WebLocalization.string("Exit Web Viewer", comment: "A button that exits the web viewer."))
                } icon: {
                    Image(systemName: "xmark")
                }
            }
        } label: {
            ZStack {
                Image(systemName: "ellipsis")
                    .font(.system(size: floatingButtonIconSize, weight: .semibold))

                Color.clear
                    .allowsHitTesting(false)
                    .tourAnchor(WebViewerToolbarTourAnchor.dismissButton)
            }
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .glassEffectID("overflow", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .accessibilityLabel("More Actions")
    }

    private func reloadOrStopLoading() {
        if viewModel.page?.isLoading == true {
            viewModel.stopLoading()
        } else {
            viewModel.reload()
        }
    }

    private func removeBookmark() {
        viewModel.removeBookmarkForCurrentPage()
    }

    private func addBookmark() {
        viewModel.addBookmarkForCurrentPage()
    }

    private func navigate(to url: URL) {
        viewModel.navigate(to: url)
    }
}
