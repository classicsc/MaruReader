// TableOfContentsView.swift
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

import ReadiumShared
import SwiftUI

@MainActor
struct TableOfContentsView: View {
    let publication: Publication
    let bookTitle: String?
    let bookAuthor: String?
    let coverImage: UIImage?
    let currentLocator: Locator?
    let onNavigate: (ReadiumShared.Link) -> Void
    let onNavigateToPosition: (Int) -> Void
    let onDismiss: () -> Void

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
                    .background(Color(.systemBackground))

                Divider()

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
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .task {
            await loadTableOfContents()
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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bookTitle ?? "Unknown Title")
                    .font(.headline)
                    .lineLimit(2)

                Text(displayAuthor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookProgressText ?? "Book --")
                    Text(chapterProgressText ?? "Chapter --")
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
                .foregroundStyle(.secondary)
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
                        onNavigate: onNavigate
                    )
                }
            }
            .listStyle(.plain)
            .onAppear {
                scrollToCurrentChapter(proxy: proxy)
            }
        }
    }

    private func loadTableOfContents() async {
        // Use manifest.tableOfContents directly to avoid concurrency issues
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
        return trimmedAuthor.isEmpty ? "Unknown Author" : trimmedAuthor
    }

    private var bookProgressText: String? {
        guard let totalProgression = currentLocator?.locations.totalProgression else { return nil }
        return "Book \(formatProgress(totalProgression))"
    }

    private var chapterProgressText: String? {
        guard let progression = currentLocator?.locations.progression else { return nil }
        return "Chapter \(formatProgress(progression))"
    }

    private var positionText: String {
        guard let position = currentLocator?.locations.position else { return "Position --" }
        return "Position \(position.formatted())"
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

private struct TOCItemView: View {
    let link: ReadiumShared.Link
    let level: Int
    @Binding var expandedItems: Set<String>
    let currentHref: String?
    let onNavigate: (ReadiumShared.Link) -> Void

    private var hasChildren: Bool { !link.children.isEmpty }
    private var isExpanded: Bool { expandedItems.contains(link.href) }
    private var isCurrent: Bool { link.href == currentHref }

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
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
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
                        onNavigate: onNavigate
                    )
                }
            }
        }
    }
}
