// TableOfContentsView.swift
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
import ReadiumShared
import SwiftUI

private enum ContentTab: String, CaseIterable {
    case contents = "Contents"
    case bookmarks = "Bookmarks"

    var localizedName: String {
        switch self {
        case .contents:
            String(localized: "Contents")
        case .bookmarks:
            String(localized: "Bookmarks")
        }
    }
}

struct TableOfContentsTheme {
    let preferredColorScheme: ColorScheme?
    let backgroundColor: Color
    let foregroundColor: Color
    let secondaryForegroundColor: Color
    let separatorColor: Color
}

struct BookReaderBookmarkRowData: Identifiable {
    let bookmark: Bookmark
    let displayTitle: String
    let chapterTitle: String?
    let progressText: String?
    let isCurrent: Bool

    var id: NSManagedObjectID {
        bookmark.objectID
    }

    static func makeRows(
        bookmarks: [Bookmark],
        currentHref: String?,
        chapterTitleByHref: [String: String]
    ) -> [Self] {
        bookmarks.map { bookmark in
            let locator = locator(for: bookmark)
            let href = locator?.href.string

            return BookReaderBookmarkRowData(
                bookmark: bookmark,
                displayTitle: bookmark.title ?? String(localized: "Bookmark"),
                chapterTitle: href.flatMap { chapterTitleByHref[$0] },
                progressText: locator.flatMap(progressText(for:)),
                isCurrent: href == currentHref
            )
        }
    }

    private static func locator(for bookmark: Bookmark) -> Locator? {
        guard let locationJSON = bookmark.location else { return nil }
        return try? Locator(jsonString: locationJSON)
    }

    private static func progressText(for locator: Locator) -> String? {
        if let totalProgression = locator.locations.totalProgression {
            let percent = Int(totalProgression * 100)
            return String(localized: "Book \(percent)%")
        }
        if let position = locator.locations.position {
            return String(localized: "Position \(position)")
        }
        return nil
    }
}

@MainActor
struct TableOfContentsView: View {
    let publication: Publication
    let bookTitle: String?
    let bookAuthor: String?
    let coverImage: UIImage?
    let currentLocator: Locator?
    let bookmarks: [Bookmark]
    let chapterTitleByHref: [String: String]
    let onNavigate: (ReadiumShared.Link) -> Void
    let onNavigateToPosition: (Int) -> Void
    let onNavigateToBookmark: (Bookmark) -> Void
    let onDeleteBookmark: (Bookmark) -> Void
    let onUpdateBookmarkTitle: (Bookmark, String) -> Void
    let theme: TableOfContentsTheme
    let onDismiss: () -> Void

    @State private var selectedTab: ContentTab = .contents
    @State private var tableOfContents: [ReadiumShared.Link] = []
    @State private var expandedItems: Set<String> = []
    @State private var isLoading = true
    @State private var isShowingPositionPrompt = false
    @State private var positionInput: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding()
                    .background(theme.backgroundColor)

                Divider()
                    .overlay {
                        theme.separatorColor
                    }

                Picker("Tab", selection: $selectedTab) {
                    ForEach(ContentTab.allCases, id: \.self) { tab in
                        Text(tab.localizedName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .contents:
                    contentsTabView
                case .bookmarks:
                    BookmarksListView(
                        bookmarks: bookmarks,
                        chapterTitleByHref: chapterTitleByHref,
                        currentLocator: currentLocator,
                        theme: theme,
                        onNavigate: onNavigateToBookmark,
                        onDelete: onDeleteBookmark,
                        onUpdateTitle: onUpdateBookmarkTitle
                    )
                }
            }
            .background(theme.backgroundColor)
            .alert("Go to position", isPresented: $isShowingPositionPrompt) {
                TextField("Position", value: $positionInput, format: .number)
                    .keyboardType(.numberPad)
                Button("Go") {
                    handlePositionJump()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(positionPromptMessage)
            }
            .navigationTitle(selectedTab.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .background(theme.backgroundColor)
        .applyLocalColorScheme(theme.preferredColorScheme)
        .tint(theme.foregroundColor)
        .task {
            await loadTableOfContents()
        }
    }

    @ViewBuilder
    private var contentsTabView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tableOfContents.isEmpty {
            ContentUnavailableView(
                "No Table of Contents",
                systemImage: "list.bullet",
                description: Text("This book doesn't have a table of contents")
            )
        } else {
            tocListView
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            if let cover = coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 75)
                    .clipShape(.rect(cornerRadius: 4))
                    .shadow(radius: 1)
            } else {
                Image(systemName: "book.closed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 50)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .padding(.horizontal, 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bookTitle ?? String(localized: "Unknown Title"))
                    .font(.headline)
                    .foregroundStyle(theme.foregroundColor)
                    .lineLimit(2)

                Text(displayAuthor)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookProgressText ?? String(localized: "Book --"))
                    Text(chapterProgressText ?? String(localized: "Chapter --"))
                    HStack(spacing: 8) {
                        Text(positionText)
                        Button("Go to...", action: presentPositionPrompt)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                            .accessibilityLabel("Go to position")
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
            }

            Spacer()
        }
    }

    private var tocListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(tableOfContents, id: \.href) { link in
                    TOCItemView(
                        link: link,
                        level: 0,
                        expandedItems: $expandedItems,
                        currentHref: currentLocator?.href.string,
                        theme: theme,
                        onNavigate: onNavigate
                    )
                    .listRowBackground(theme.backgroundColor)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
            .onAppear {
                scrollToCurrentChapter(proxy: proxy)
            }
        }
    }

    private func loadTableOfContents() async {
        let toc = publication.manifest.tableOfContents
        if !toc.isEmpty {
            tableOfContents = toc
        } else {
            tableOfContents = publication.readingOrder
        }

        expandParentsOfCurrentChapter()
        isLoading = false
    }

    private func expandParentsOfCurrentChapter() {
        guard let currentHref = currentLocator?.href.string else { return }

        func expandParents(in links: [ReadiumShared.Link]) -> Bool {
            for link in links {
                if link.href == currentHref || expandParents(in: link.children) {
                    expandedItems.insert(link.href)
                    return true
                }
            }
            return false
        }

        _ = expandParents(in: tableOfContents)
    }

    private func scrollToCurrentChapter(proxy: ScrollViewProxy) {
        guard let currentHref = currentLocator?.href.string else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation {
                proxy.scrollTo(currentHref, anchor: .center)
            }
        }
    }

    private var displayAuthor: String {
        let trimmedAuthor = bookAuthor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedAuthor.isEmpty ? String(localized: "Unknown Author") : trimmedAuthor
    }

    private var bookProgressText: String? {
        guard let totalProgression = currentLocator?.locations.totalProgression else { return nil }
        return String(localized: "Book \(formatProgress(totalProgression))")
    }

    private var chapterProgressText: String? {
        guard let progression = currentLocator?.locations.progression else { return nil }
        return String(localized: "Chapter \(formatProgress(progression))")
    }

    private var positionText: String {
        guard let position = currentLocator?.locations.position else { return String(localized: "Position --") }
        return String(localized: "Position \(position.formatted())")
    }

    private var positionPromptMessage: String {
        "Enter a position number."
    }

    private func formatProgress(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
    }

    private func presentPositionPrompt() {
        positionInput = currentLocator?.locations.position
        isShowingPositionPrompt = true
    }

    private func handlePositionJump() {
        guard let position = positionInput else { return }
        onNavigateToPosition(max(position, 1))
    }
}

// MARK: - BookmarksListView

private struct BookmarksListView: View {
    let bookmarks: [Bookmark]
    let chapterTitleByHref: [String: String]
    let currentLocator: Locator?
    let theme: TableOfContentsTheme
    let onNavigate: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    let onUpdateTitle: (Bookmark, String) -> Void

    @State private var editingBookmark: Bookmark?
    @State private var isShowingRenameAlert = false
    @State private var editingTitle: String = ""
    @State private var bookmarkRows: [BookReaderBookmarkRowData] = []

    var body: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView(
                "No Bookmarks",
                systemImage: "bookmark",
                description: Text("Tap the bookmark button to save your place")
            )
        } else {
            List {
                ForEach(bookmarkRows) { row in
                    Button {
                        onNavigate(row.bookmark)
                    } label: {
                        BookmarkRowView(
                            row: row,
                            theme: theme
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingTitle = row.bookmark.title ?? ""
                            editingBookmark = row.bookmark
                            isShowingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(row.bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(theme.backgroundColor)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
            .task(id: bookmarkRowsRefreshKey) {
                bookmarkRows = BookReaderBookmarkRowData.makeRows(
                    bookmarks: bookmarks,
                    currentHref: currentLocator?.href.string,
                    chapterTitleByHref: chapterTitleByHref
                )
            }
            .alert("Rename Bookmark", isPresented: $isShowingRenameAlert) {
                TextField("Title", text: $editingTitle)
                Button("Save") {
                    if let bookmark = editingBookmark {
                        onUpdateTitle(bookmark, editingTitle)
                    }
                    editingBookmark = nil
                }
                Button("Cancel", role: .cancel) {
                    editingBookmark = nil
                }
            } message: {
                Text("Enter a new title for this bookmark")
            }
        }
    }

    private var bookmarkRowsRefreshKey: BookmarkRowsRefreshKey {
        BookmarkRowsRefreshKey(
            currentHref: currentLocator?.href.string,
            bookmarks: bookmarks.map { bookmark in
                BookmarkRowsRefreshItem(
                    id: bookmark.objectID.uriRepresentation().absoluteString,
                    title: bookmark.title,
                    location: bookmark.location
                )
            }
        )
    }
}

private struct BookmarkRowsRefreshKey: Equatable {
    let currentHref: String?
    let bookmarks: [BookmarkRowsRefreshItem]
}

private struct BookmarkRowsRefreshItem: Equatable {
    let id: String
    let title: String?
    let location: String?
}

// MARK: - BookmarkRowView

private struct BookmarkRowView: View {
    let row: BookReaderBookmarkRowData
    let theme: TableOfContentsTheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayTitle)
                    .font(.body)
                    .fontWeight(row.isCurrent ? .semibold : .regular)
                    .foregroundStyle(row.isCurrent ? Color.accentColor : theme.foregroundColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let chapter = row.chapterTitle {
                        Text(chapter)
                            .lineLimit(1)
                    }
                    if let progress = row.progressText {
                        Text(progress)
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
            }

            Spacer()

            if row.isCurrent {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - TOCItemView

private struct TOCItemView: View {
    let link: ReadiumShared.Link
    let level: Int
    @Binding var expandedItems: Set<String>
    let currentHref: String?
    let theme: TableOfContentsTheme
    let onNavigate: (ReadiumShared.Link) -> Void

    private var hasChildren: Bool {
        !link.children.isEmpty
    }

    private var isExpanded: Bool {
        expandedItems.contains(link.href)
    }

    private var isCurrent: Bool {
        link.href == currentHref
    }

    private var displayTitle: String {
        if let title = link.title, !title.isEmpty {
            return title
        }
        let href = link.href
        if let lastComponent = href.split(separator: "/").last {
            let filename = String(lastComponent)
            if let dotIndex = filename.lastIndex(of: ".") {
                return String(filename[..<dotIndex])
            }
            return filename
        }
        return href
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if hasChildren {
                    Button(action: toggleExpansion) {
                        Label(expandButtonLabel, systemImage: isExpanded ? "chevron.down" : "chevron.right")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                }

                Button {
                    onNavigate(link)
                } label: {
                    HStack {
                        Text(displayTitle)
                            .foregroundStyle(isCurrent ? Color.accentColor : theme.foregroundColor)
                            .fontWeight(isCurrent ? .semibold : .regular)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if isCurrent {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(level) * 20)
            .id(link.href)

            if hasChildren, isExpanded {
                ForEach(link.children, id: \.href) { child in
                    TOCItemView(
                        link: child,
                        level: level + 1,
                        expandedItems: $expandedItems,
                        currentHref: currentHref,
                        theme: theme,
                        onNavigate: onNavigate
                    )
                }
            }
        }
    }

    private var expandButtonLabel: String {
        isExpanded ? String(localized: "Collapse section") : String(localized: "Expand section")
    }

    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedItems.remove(link.href)
            } else {
                expandedItems.insert(link.href)
            }
        }
    }
}
