// WebViewerBookmarkButton.swift
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

import SwiftUI

struct WebViewerBookmarkButton: View {
    let isBookmarked: Bool
    let bookmarks: [WebBookmarkSnapshot]
    let iconSize: CGFloat
    let frameSize: CGFloat
    let onToggleBookmark: () -> Void
    let onNavigateToBookmark: (URL) -> Void

    var body: some View {
        Menu {
            if isBookmarked {
                Button(role: .destructive, action: onToggleBookmark) {
                    Label("Remove Bookmark", systemImage: "bookmark.slash")
                }
            } else {
                Button(action: onToggleBookmark) {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                }
            }

            if !bookmarks.isEmpty {
                Section {
                    ForEach(bookmarks, id: \.id) { bookmark in
                        Button {
                            onNavigateToBookmark(bookmark.url)
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
                            comment: "A section header in the bookmarks menu that lists saved bookmarks."
                        )
                    )
                }
            }
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: iconSize, weight: .semibold))
        }
        .frame(width: frameSize, height: frameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .accessibilityLabel("Bookmarks")
    }
}
