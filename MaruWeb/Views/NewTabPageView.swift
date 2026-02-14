// NewTabPageView.swift
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

import SwiftUI

struct NewTabPageView: View {
    let bookmarks: [WebBookmarkSnapshot]
    let onNavigate: (URL) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            if bookmarks.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                bookmarksGrid
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Bookmarks",
            systemImage: "bookmark",
            description: Text("Bookmarked pages will appear here.")
        )
    }

    private var bookmarksGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(bookmarks) { bookmark in
                Button {
                    onNavigate(bookmark.url)
                } label: {
                    BookmarkCard(bookmark: bookmark)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BookmarkCard: View {
    let bookmark: WebBookmarkSnapshot

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(height: 32)

            Text(bookmark.title)
                .font(.callout.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(bookmark.url.host ?? bookmark.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
