// MangaLibraryView.swift
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

//  MangaLibraryView.swift
//  MaruReader
//
//  MangaArchive library view with import progress and book grid display.
//
import CoreData
import SwiftUI
import UniformTypeIdentifiers

enum MangaArchiveSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"

    var id: String { rawValue }

    var nsSortDescriptors: [NSSortDescriptor] {
        switch self {
        case .title:
            [
                NSSortDescriptor(keyPath: \MangaArchive.title, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.author, ascending: true),
            ]
        case .author:
            [
                NSSortDescriptor(keyPath: \MangaArchive.author, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.title, ascending: true),
            ]
        case .dateAdded:
            [
                NSSortDescriptor(keyPath: \MangaArchive.dateAdded, ascending: false),
            ]
        }
    }

    var sortDescriptors: [SortDescriptor<MangaArchive>] {
        switch self {
        case .title:
            [
                SortDescriptor(\MangaArchive.title, order: .forward),
                SortDescriptor(\MangaArchive.author, order: .forward),
            ]
        case .author:
            [
                SortDescriptor(\MangaArchive.author, order: .forward),
                SortDescriptor(\MangaArchive.title, order: .forward),
            ]
        case .dateAdded:
            [
                SortDescriptor(\MangaArchive.dateAdded, order: .reverse),
            ]
        }
    }
}

public struct MangaArchiveLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var sortOption: MangaArchiveSortOption = .dateAdded
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var bookToDelete: MangaArchive?
    @State private var showingDeleteConfirmation = false

    private var books: FetchRequest<MangaArchive>

    public init() {
        let initialSortOption = MangaArchiveSortOption.dateAdded
        books = FetchRequest<MangaArchive>(
            entity: MangaArchive.entity(),
            sortDescriptors: initialSortOption.nsSortDescriptors,
            predicate: nil,
            animation: .default
        )
    }

    public var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Manga")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingFilePicker = true }) {
                            Image(systemName: "plus")
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(MangaArchiveSortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.zip, UTType(filenameExtension: "cbz")!],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result: result)
                }
                .alert("Import Error", isPresented: $showingError) {
                    Button("OK") {
                        showingError = false
                        importError = nil
                    }
                } message: {
                    if let error = importError {
                        Text(error.localizedDescription)
                    }
                }
                .confirmationDialog(
                    "Delete Manga",
                    isPresented: $showingDeleteConfirmation,
                    presenting: bookToDelete
                ) { book in
                    Button("Delete", role: .destructive) {
                        deleteMangaArchive(book)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { book in
                    Text("Are you sure you want to delete \"\(book.title ?? "Unknown Manga")\"? This action cannot be undone.")
                }
                .onChange(of: sortOption) { _, newValue in
                    books.wrappedValue.sortDescriptors = newValue.sortDescriptors
                }
                .navigationDestination(for: MangaArchive.self) { manga in
                    MangaReaderView(manga: manga)
                }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if books.wrappedValue.isEmpty {
                    emptyStateView
                } else {
                    booksGridView
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Manga",
            systemImage: "books.vertical",
            description: Text("Import ZIP/CBZ files to see them here")
        )
        .frame(maxHeight: .infinity)
    }

    private var booksGridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16),
            ],
            spacing: 20
        ) {
            ForEach(books.wrappedValue, id: \.objectID) { book in
                let state = MangaArchiveImportState(book: book)
                Group {
                    if state.isComplete {
                        NavigationLink(value: book) {
                            MangaArchiveGridItem(book: book, state: state, onCancel: {}, onRemove: {})
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                bookToDelete = book
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        MangaArchiveGridItem(
                            book: book,
                            state: state,
                            onCancel: { cancelImport(book) },
                            onRemove: { removeMangaArchive(book) }
                        )
                    }
                }
            }
        }
        .padding()
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    _ = try await MangaImportManager.shared.enqueueImport(from: url)
                } catch {
                    await MainActor.run {
                        importError = error
                        showingError = true
                    }
                }
            }

        case let .failure(error):
            importError = error
            showingError = true
        }
    }

    private func cancelImport(_ book: MangaArchive) {
        Task {
            await MangaImportManager.shared.cancelImport(jobID: book.objectID)
        }
    }

    private func deleteMangaArchive(_ book: MangaArchive) {
        Task {
            await MangaImportManager.shared.deleteManga(mangaID: book.objectID)
        }
    }

    private func removeMangaArchive(_ book: MangaArchive) {
        deleteMangaArchive(book)
    }
}

struct MangaArchiveGridItem: View {
    let book: MangaArchive
    let state: MangaArchiveImportState
    let onCancel: () -> Void
    let onRemove: () -> Void

    private var coverImage: UIImage? {
        guard let coverURL = book.coverImage else { return nil }

        guard let data = try? Data(contentsOf: coverURL) else { return nil }
        return UIImage(data: data)
    }

    private var displayTitle: String {
        if let title = book.title, !title.isEmpty {
            return title
        }
        return "Untitled"
    }

    private var displayAuthor: String? {
        if let author = book.author, !author.isEmpty {
            return author
        }
        return nil
    }

    private var statusMessage: String? {
        switch state.status {
        case .complete:
            nil
        case .inProgress:
            "Importing..."
        case .failed:
            book.importErrorMessage ?? "Import failed."
        case .cancelled:
            "Import cancelled."
        }
    }

    private var actionLabel: String? {
        switch state.status {
        case .complete:
            nil
        case .inProgress:
            "Cancel"
        case .failed, .cancelled:
            "Remove"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Cover Image
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "book.closed")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                        .padding(30)
                }
            }
            .frame(width: 120, height: 180)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .shadow(radius: 2)

            // MangaArchive Info
            VStack(alignment: .center, spacing: 2) {
                Text(displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let author = displayAuthor {
                    Text(author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(state.status == .failed ? .red : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 120)

            if let actionLabel {
                Button(actionLabel) {
                    switch state.status {
                    case .inProgress:
                        onCancel()
                    case .failed, .cancelled:
                        onRemove()
                    case .complete:
                        break
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct MangaArchiveImportState {
    enum Status {
        case complete
        case inProgress
        case failed
        case cancelled
    }

    let status: Status

    init(book: MangaArchive) {
        if book.importComplete {
            status = .complete
        } else if let errorMessage = book.importErrorMessage, !errorMessage.isEmpty {
            status = .failed
        } else {
            status = .inProgress
        }
    }

    var isComplete: Bool {
        status == .complete
    }
}
