// WebBookmarksView.swift
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
import SwiftUI

public struct WebBookmarksView: View {
    @State private var addressText = ""
    @State private var navigationTarget: URL?

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true),
        ],
        animation: .default
    ) private var bookmarks: FetchedResults<WebBookmark>

    private let bookmarkManager = WebBookmarkManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                WebAddressBar(text: $addressText, onSubmit: openAddress)

                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmarks will appear here once saved.")
                    )
                } else {
                    List {
                        ForEach(bookmarks, id: \.objectID) { bookmark in
                            Button {
                                openBookmark(bookmark)
                            } label: {
                                WebBookmarkRow(bookmark: bookmark)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteBookmarks)
                        .onMove(perform: moveBookmarks)
                    }
                    .listStyle(.plain)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bookmarks")
            .fullScreenCover(isPresented: isShowingWebView) {
                if let target = navigationTarget {
                    WebViewerView(initialURL: target)
                }
            }
            .toolbar {
                if !bookmarks.isEmpty {
                    EditButton()
                }
            }
            .onAppear {
                WebSessionStore.shared.prewarm(
                    enableContentBlocking: WebContentBlockingSettings.contentBlockingEnabled
                )
                if ProcessInfo.processInfo.arguments.contains("--screenshotMode") {
                    navigationTarget = URL(string: "about:blank")
                }
            }
        }
    }

    private var isShowingWebView: Binding<Bool> {
        Binding(
            get: { navigationTarget != nil },
            set: { if !$0 { navigationTarget = nil } }
        )
    }

    private func openAddress() {
        guard let url = WebAddressParser.resolvedURL(from: addressText) else { return }
        navigationTarget = url
    }

    private func openBookmark(_ bookmark: WebBookmark) {
        guard let urlString = bookmark.url,
              let url = URL(string: urlString)
        else { return }
        navigationTarget = url
        Task {
            try? await bookmarkManager.updateBookmarkMetadata(url: url, title: bookmark.title)
        }
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        let ids = offsets.compactMap { bookmarks[$0].id }
        guard !ids.isEmpty else { return }
        Task {
            for id in ids {
                try? await bookmarkManager.removeBookmark(id: id)
            }
        }
    }

    private func moveBookmarks(from source: IndexSet, to destination: Int) {
        var ids = bookmarks.compactMap(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        Task {
            try? await bookmarkManager.updateSortOrder(idsInOrder: ids)
        }
    }
}

private struct WebBookmarkRow: View {
    let bookmark: WebBookmark

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BookmarkFaviconView(data: bookmark.favicon, size: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let urlString = bookmark.url {
                    Text(urlString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        if let title = bookmark.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let urlString = bookmark.url,
           let url = URL(string: urlString),
           let host = url.host
        {
            return host
        }
        return WebStrings.untitledBookmark()
    }
}
