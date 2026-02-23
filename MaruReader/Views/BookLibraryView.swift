// BookLibraryView.swift
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

//  BookLibraryView.swift
//  MaruReader
//
//  Book library view with import progress and book grid display.
//
import CoreData
import SwiftUI
import UniformTypeIdentifiers

enum BookSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"

    var id: String {
        rawValue
    }

    var nsSortDescriptors: [NSSortDescriptor] {
        switch self {
        case .title:
            [
                NSSortDescriptor(keyPath: \Book.title, ascending: true),
                NSSortDescriptor(keyPath: \Book.author, ascending: true),
            ]
        case .author:
            [
                NSSortDescriptor(keyPath: \Book.author, ascending: true),
                NSSortDescriptor(keyPath: \Book.title, ascending: true),
            ]
        case .dateAdded:
            [
                NSSortDescriptor(keyPath: \Book.added, ascending: false),
            ]
        }
    }

    var sortDescriptors: [SortDescriptor<Book>] {
        switch self {
        case .title:
            [
                SortDescriptor(\Book.title, order: .forward),
                SortDescriptor(\Book.author, order: .forward),
            ]
        case .author:
            [
                SortDescriptor(\Book.author, order: .forward),
                SortDescriptor(\Book.title, order: .forward),
            ]
        case .dateAdded:
            [
                SortDescriptor(\Book.added, order: .reverse),
            ]
        }
    }
}

struct BookLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @AppStorage("selectedLibraryType") private var selectedLibraryType = LibraryType.books.rawValue
    @State private var sortOption: BookSortOption = .dateAdded
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var bookToDelete: Book?
    @State private var showingDeleteConfirmation = false
    @State private var selectedBook: Book?

    private var books: FetchRequest<Book>

    init() {
        let initialSortOption = BookSortOption.dateAdded
        books = FetchRequest<Book>(
            entity: Book.entity(),
            sortDescriptors: initialSortOption.nsSortDescriptors,
            predicate: NSPredicate(format: "pendingDeletion == NO"),
            animation: .default
        )
    }

    private var libraryTypeBinding: Binding<LibraryType> {
        Binding(
            get: { LibraryType(rawValue: selectedLibraryType) ?? .books },
            set: { selectedLibraryType = $0.rawValue }
        )
    }

    private var isShowingReader: Binding<Bool> {
        Binding(
            get: { selectedBook != nil },
            set: { if !$0 { selectedBook = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Library", selection: libraryTypeBinding) {
                            ForEach(LibraryType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingFilePicker = true }) {
                            Image(systemName: "plus")
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(BookSortOption.allCases) { option in
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
                    allowedContentTypes: [.epub],
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
                    "Delete Book",
                    isPresented: $showingDeleteConfirmation,
                    presenting: bookToDelete
                ) { book in
                    Button("Delete", role: .destructive) {
                        deleteBook(book)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { book in
                    Text("Are you sure you want to delete \"\(book.title ?? "Unknown Book")\"? This action cannot be undone.")
                }
                .fullScreenCover(isPresented: isShowingReader) {
                    if let book = selectedBook {
                        BookReaderView(book: book)
                    }
                }
                .onChange(of: sortOption) { _, newValue in
                    books.wrappedValue.sortDescriptors = newValue.sortDescriptors
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
            "No Books",
            systemImage: "books.vertical",
            description: Text("Import EPUB files to see them here")
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
                let state = BookImportState(book: book)
                Group {
                    if state.isComplete {
                        Button {
                            selectedBook = book
                        } label: {
                            BookGridItem(book: book, state: state, onCancel: {}, onRemove: {})
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
                        BookGridItem(
                            book: book,
                            state: state,
                            onCancel: { cancelImport(book) },
                            onRemove: { removeBook(book) }
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
                    _ = try await BookImportManager.shared.enqueueImport(from: url)
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

    private func cancelImport(_ book: Book) {
        Task {
            await BookImportManager.shared.cancelImport(jobID: book.objectID)
        }
    }

    private func deleteBook(_ book: Book) {
        Task {
            await BookImportManager.shared.deleteBook(bookID: book.objectID)
        }
    }

    private func removeBook(_ book: Book) {
        deleteBook(book)
    }
}

struct BookGridItem: View {
    @ObservedObject var book: Book
    let state: BookImportState
    let onCancel: () -> Void
    let onRemove: () -> Void

    private var coverImage: UIImage? {
        guard let coverFileName = book.coverFileName else { return nil }

        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }

        let coverURL = appSupportDir
            .appendingPathComponent("Covers")
            .appendingPathComponent(coverFileName)

        guard let data = try? Data(contentsOf: coverURL) else { return nil }
        return UIImage(data: data)
    }

    private var displayTitle: String {
        if let title = book.title, !title.isEmpty {
            return title
        }
        if let originalName = book.originalFileName, !originalName.isEmpty {
            return originalName
        }
        return "Untitled Book"
    }

    private var displayAuthor: String? {
        if let author = book.author, !author.isEmpty {
            return author
        }
        return nil
    }

    private var displayProgress: String? {
        if let progressPercent = book.progressPercent, !progressPercent.isEmpty {
            return progressPercent
        }
        return nil
    }

    private var statusMessage: String? {
        switch state.status {
        case .complete:
            nil
        case .inProgress:
            book.displayProgressMessage ?? String(localized: "Importing...")
        case .failed:
            book.errorMessage ?? book.displayProgressMessage ?? String(localized: "Import failed.")
        case .cancelled:
            book.displayProgressMessage ?? String(localized: "Import cancelled.")
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
                        .aspectRatio(contentMode: .fill)
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

            // Book Info
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

                if let progressPercent = displayProgress {
                    Text("\(progressPercent) Read")
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

struct BookImportState {
    enum Status {
        case complete
        case inProgress
        case failed
        case cancelled
    }

    let status: Status

    init(book: Book) {
        if book.isComplete {
            status = .complete
        } else if book.isCancelled {
            status = .cancelled
        } else if let errorMessage = book.errorMessage, !errorMessage.isEmpty {
            status = .failed
        } else {
            status = .inProgress
        }
    }

    var isComplete: Bool {
        status == .complete
    }
}
