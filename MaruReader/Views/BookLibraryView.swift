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

    var id: String { rawValue }

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

    @State private var sortOption: BookSortOption = .dateAdded
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var bookToDelete: Book?
    @State private var showingDeleteConfirmation = false

    @FetchRequest(
        entity: BookEPUBImport.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \BookEPUBImport.timeQueued, ascending: false),
        ],
        animation: .default
    )
    private var importJobs: FetchedResults<BookEPUBImport>

    private var books: FetchRequest<Book>

    init() {
        let initialSortOption = BookSortOption.dateAdded
        books = FetchRequest<Book>(
            entity: Book.entity(),
            sortDescriptors: initialSortOption.nsSortDescriptors,
            predicate: NSPredicate(format: "isComplete == %@", NSNumber(value: true)),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Library")
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
                .onChange(of: sortOption) { _, newValue in
                    books.wrappedValue.sortDescriptors = newValue.sortDescriptors
                }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !importJobs.isEmpty {
                    importProgressSection
                }

                if books.wrappedValue.isEmpty {
                    emptyStateView
                } else {
                    booksGridView
                }
            }
        }
    }

    private var importProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Progress")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(importJobs, id: \.objectID) { job in
                    BookImportJobRow(
                        job: job,
                        onCancel: { cancelImport(job) },
                        onDismiss: { dismissImport(job) }
                    )
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
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
                BookGridItem(book: book)
                    .contextMenu {
                        Button(role: .destructive) {
                            bookToDelete = book
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
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

    private func cancelImport(_ job: BookEPUBImport) {
        Task {
            await BookImportManager.shared.cancelImport(jobID: job.objectID)
        }
    }

    private func dismissImport(_ job: BookEPUBImport) {
        viewContext.delete(job)
        do {
            try viewContext.save()
        } catch {
            importError = error
            showingError = true
        }
    }

    private func deleteBook(_ book: Book) {
        Task {
            await BookImportManager.shared.deleteBook(bookID: book.objectID)
        }
    }
}

struct BookImportJobRow: View {
    let job: BookEPUBImport
    let onCancel: () -> Void
    let onDismiss: () -> Void

    private var fileName: String {
        job.file?.lastPathComponent ?? "Unknown File"
    }

    private var statusIcon: String {
        if job.isCancelled {
            "xmark.circle.fill"
        } else if job.isComplete {
            "checkmark.circle.fill"
        } else if job.isStarted {
            "gear"
        } else {
            "clock"
        }
    }

    private var statusColor: Color {
        if job.isCancelled {
            .secondary
        } else if job.isComplete {
            .green
        } else if job.isStarted {
            .blue
        } else {
            .orange
        }
    }

    private var canCancel: Bool {
        !job.isComplete && !job.isCancelled
    }

    private var canDismiss: Bool {
        job.isComplete || job.isCancelled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)

                    if let message = job.displayProgressMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if canCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if canDismiss {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BookGridItem: View {
    let book: Book

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
                Text(book.title ?? "Unknown Title")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let author = book.author {
                    Text(author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 120)
        }
    }
}

#Preview {
    NavigationStack {
        BookLibraryView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
