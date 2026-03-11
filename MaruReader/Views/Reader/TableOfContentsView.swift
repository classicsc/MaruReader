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

@MainActor
struct TableOfContentsView: View {
    let publication: Publication
    let bookTitle: String?
    let bookAuthor: String?
    let coverImage: UIImage?
    let currentLocator: Locator?
    let bookmarks: [Bookmark]
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
    @State private var positionInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding()
                    .background(theme.backgroundColor)

                Divider()
                    .overlay(theme.separatorColor)

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
                        publication: publication,
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
                TextField("Position", text: $positionInput)
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
                    .cornerRadius(4)
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
                        Button("Go to...") {
                            presentPositionPrompt()
                        }
                        .controlSize(.mini)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        if let position = currentLocator?.locations.position {
            positionInput = String(position)
        } else {
            positionInput = ""
        }
        isShowingPositionPrompt = true
    }

    private func clampPosition(_ position: Int) -> Int {
        max(position, 1)
    }

    private func handlePositionJump() {
        let trimmedInput = positionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let position = Int(trimmedInput) else { return }
        onNavigateToPosition(clampPosition(position))
    }
}

private extension View {
    @ViewBuilder
    func applyLocalColorScheme(_ colorScheme: ColorScheme?) -> some View {
        if let colorScheme {
            environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }
}

// MARK: - BookmarksListView

private struct BookmarksListView: View {
    let bookmarks: [Bookmark]
    let publication: Publication
    let currentLocator: Locator?
    let theme: TableOfContentsTheme
    let onNavigate: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    let onUpdateTitle: (Bookmark, String) -> Void

    @State private var editingBookmark: Bookmark?
    @State private var editingTitle: String = ""

    var body: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView(
                "No Bookmarks",
                systemImage: "bookmark",
                description: Text("Tap the bookmark button to save your place")
            )
        } else {
            List {
                ForEach(bookmarks, id: \.id) { bookmark in
                    BookmarkRowView(
                        bookmark: bookmark,
                        publication: publication,
                        currentLocator: currentLocator,
                        theme: theme
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onNavigate(bookmark)
                    }
                    .contextMenu {
                        Button {
                            editingTitle = bookmark.title ?? ""
                            editingBookmark = bookmark
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(bookmark)
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
            .alert("Rename Bookmark", isPresented: .init(
                get: { editingBookmark != nil },
                set: { if !$0 { editingBookmark = nil } }
            )) {
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
}

// MARK: - BookmarkRowView

private struct BookmarkRowView: View {
    @ObservedObject var bookmark: Bookmark
    let publication: Publication
    let currentLocator: Locator?
    let theme: TableOfContentsTheme

    private var locator: Locator? {
        guard let locationJSON = bookmark.location else { return nil }
        return try? Locator(jsonString: locationJSON)
    }

    private var displayTitle: String {
        bookmark.title ?? String(localized: "Bookmark")
    }

    private var chapterTitle: String? {
        guard let locator else { return nil }
        return findChapterTitle(for: locator, in: publication)
    }

    private var progressText: String? {
        guard let locator else { return nil }
        if let totalProgression = locator.locations.totalProgression {
            let percent = Int(totalProgression * 100)
            return String(localized: "Book \(percent)%")
        }
        if let position = locator.locations.position {
            return String(localized: "Position \(position)")
        }
        return nil
    }

    private var isCurrent: Bool {
        guard let locator, let currentLocator else { return false }
        return locator.href.string == currentLocator.href.string
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.body)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? Color.accentColor : theme.foregroundColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let chapter = chapterTitle {
                        Text(chapter)
                            .lineLimit(1)
                    }
                    if let progress = progressText {
                        Text(progress)
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func findChapterTitle(for locator: Locator, in publication: Publication) -> String? {
        func searchLinks(_ links: [ReadiumShared.Link]) -> String? {
            for link in links {
                if link.href == locator.href.string, let title = link.title, !title.isEmpty {
                    return title
                }
                if let found = searchLinks(link.children) {
                    return found
                }
            }
            return nil
        }
        return searchLinks(publication.manifest.tableOfContents)
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
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedItems.remove(link.href)
                            } else {
                                expandedItems.insert(link.href)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 16, height: 16)
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
}
