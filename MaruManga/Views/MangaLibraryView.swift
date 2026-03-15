// MangaLibraryView.swift
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

//  MangaLibraryView.swift
//  MaruReader
//
//  MangaArchive library view with import progress and book grid display.
//
import CoreData
import SwiftUI
import UniformTypeIdentifiers

enum MangaLibraryType: String, CaseIterable {
    case books = "Books"
    case manga = "Manga"

    var localizedName: String {
        switch self {
        case .books:
            MangaLocalization.string("Books")
        case .manga:
            MangaLocalization.string("Manga")
        }
    }
}

enum MangaArchiveSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"

    var localizedName: String {
        switch self {
        case .title:
            MangaLocalization.string("Title")
        case .author:
            MangaLocalization.string("Author")
        case .dateAdded:
            MangaLocalization.string("Date Added")
        }
    }

    var id: String {
        rawValue
    }

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

    @AppStorage("selectedLibraryType") private var selectedLibraryType = MangaLibraryType.manga.rawValue
    @State private var sortOption: MangaArchiveSortOption = .dateAdded
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var bookToDelete: MangaArchive?
    @State private var showingDeleteConfirmation = false
    @State private var metadataEditorBook: MangaArchive?
    @State private var selectedManga: MangaArchive?

    private var books: FetchRequest<MangaArchive>

    public init() {
        let initialSortOption = MangaArchiveSortOption.dateAdded
        books = FetchRequest<MangaArchive>(
            entity: MangaArchive.entity(),
            sortDescriptors: initialSortOption.nsSortDescriptors,
            predicate: NSPredicate(format: "pendingDeletion == NO"),
            animation: .default
        )
    }

    private var libraryTypeBinding: Binding<MangaLibraryType> {
        Binding(
            get: { MangaLibraryType(rawValue: selectedLibraryType) ?? .manga },
            set: { selectedLibraryType = $0.rawValue }
        )
    }

    public var body: some View {
        NavigationStack {
            contentView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker(MangaLocalization.string("Library"), selection: libraryTypeBinding) {
                            ForEach(MangaLibraryType.allCases, id: \.self) { type in
                                Text(type.localizedName).tag(type)
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
                            Picker(MangaLocalization.string("Sort By"), selection: $sortOption) {
                                ForEach(MangaArchiveSortOption.allCases) { option in
                                    Text(option.localizedName).tag(option)
                                }
                            }
                        } label: {
                            Label(MangaLocalization.string("Sort"), systemImage: "arrow.up.arrow.down")
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
                .onChange(of: showingFilePicker) {
                    // When the file picker appears, prewarm the metadata extractor
                    if showingFilePicker {
                        Task {
                            await MangaImportManager.shared.prewarmMetadataExtractor()
                        }
                    }
                }
                .alert(MangaLocalization.string("Import Error"), isPresented: $showingError) {
                    Button(MangaLocalization.string("OK")) {
                        showingError = false
                        importError = nil
                    }
                } message: {
                    if let error = importError {
                        Text(error.localizedDescription)
                    }
                }
                .sheet(item: $metadataEditorBook, onDismiss: { metadataEditorBook = nil }) { book in
                    MangaMetadataEditorView(manga: book)
                }
                .fullScreenCover(item: $selectedManga) { manga in
                    MangaReaderView(manga: manga)
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
            MangaLocalization.string("No Manga"),
            systemImage: "books.vertical",
            description: Text(MangaLocalization.string("Import ZIP/CBZ files to see them here"))
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
                        Button {
                            selectedManga = book
                        } label: {
                            MangaArchiveGridItem(book: book, state: state, onCancel: {}, onRemove: {})
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                metadataEditorBook = book
                            } label: {
                                Label(MangaLocalization.string("Edit Metadata"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                bookToDelete = book
                                showingDeleteConfirmation = true
                            } label: {
                                Label(MangaLocalization.string("Delete"), systemImage: "trash")
                            }
                        }
                        .confirmationDialog(
                            MangaLocalization.string("Delete Manga"),
                            isPresented: deleteConfirmationBinding(for: book)
                        ) {
                            Button(MangaLocalization.string("Delete"), role: .destructive) {
                                deleteMangaArchive(book)
                            }
                            Button(MangaLocalization.string("Cancel"), role: .cancel) {}
                        } message: {
                            Text(MangaLocalization.deleteConfirmationMessage(title: book.title))
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

    private func deleteConfirmationBinding(for book: MangaArchive) -> Binding<Bool> {
        Binding(
            get: { showingDeleteConfirmation && bookToDelete?.objectID == book.objectID },
            set: { if !$0 { showingDeleteConfirmation = false; bookToDelete = nil } }
        )
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
    @ObservedObject var book: MangaArchive
    let state: MangaArchiveImportState
    let onCancel: () -> Void
    let onRemove: () -> Void
    @State private var coverImage: UIImage?
    @State private var coverImageLoader = MangaArchiveCoverImageLoader()

    private var coverImageURL: URL? {
        book.coverImage
    }

    private var displayTitle: String {
        if let title = book.title, !title.isEmpty {
            return title
        }
        return MangaLocalization.string("Untitled")
    }

    private var displayAuthor: String? {
        if let author = book.author, !author.isEmpty {
            return author
        }
        return nil
    }

    private var displayProgress: String? {
        MangaLibraryProgressFormatter.displayProgress(
            lastReadPage: book.lastReadPage,
            totalPages: book.totalPages
        )
    }

    private var statusMessage: String? {
        switch state.status {
        case .complete:
            nil
        case .inProgress:
            MangaLocalization.string("Importing...")
        case .failed:
            book.importErrorMessage ?? MangaLocalization.string("Import failed.")
        case .cancelled:
            MangaLocalization.string("Import cancelled.")
        }
    }

    private var actionLabel: String? {
        switch state.status {
        case .complete:
            nil
        case .inProgress:
            MangaLocalization.string("Cancel")
        case .failed, .cancelled:
            MangaLocalization.string("Remove")
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

                if let progress = displayProgress {
                    Text(progress)
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
        .contentShape(Rectangle())
        .task(id: coverImageURL) {
            await loadCoverImage()
        }
    }

    @MainActor
    private func loadCoverImage() async {
        coverImage = nil

        guard let coverImageURL else { return }

        let image = await coverImageLoader.image(at: coverImageURL)
        guard !Task.isCancelled else { return }

        coverImage = image
    }
}

private actor MangaArchiveCoverImageLoader {
    func image(at coverURL: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: coverURL) else { return nil }
        return UIImage(data: data)
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

struct MangaMetadataEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manga: MangaArchive

    @State private var title: String
    @State private var author: String
    @State private var titleWasExtracted: Bool
    @State private var authorWasExtracted: Bool
    @State private var saveError: Error?
    @State private var showingSaveError = false

    private let originalTitle: String
    private let originalAuthor: String

    init(manga: MangaArchive) {
        self.manga = manga
        let initialTitle = manga.title ?? ""
        let initialAuthor = manga.author ?? ""
        _title = State(initialValue: initialTitle)
        _author = State(initialValue: initialAuthor)
        _titleWasExtracted = State(initialValue: manga.titleWasExtracted)
        _authorWasExtracted = State(initialValue: manga.authorWasExtracted)
        originalTitle = initialTitle
        originalAuthor = initialAuthor
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(MangaLocalization.string("Metadata")) {
                    LabeledContent(MangaLocalization.string("Title")) {
                        HStack(spacing: 8) {
                            TextField(MangaLocalization.string("Title"), text: $title)
                                .multilineTextAlignment(.trailing)
                            metadataBadge(isVisible: titleWasExtracted)
                        }
                    }

                    LabeledContent(MangaLocalization.string("Author")) {
                        HStack(spacing: 8) {
                            TextField(MangaLocalization.string("Author"), text: $author)
                                .multilineTextAlignment(.trailing)
                            metadataBadge(isVisible: authorWasExtracted)
                        }
                    }
                }

                Section(MangaLocalization.string("Original Filename")) {
                    Text(manga.originalFileName ?? MangaLocalization.string("Unknown Filename"))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(MangaLocalization.string("Edit Metadata"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MangaLocalization.string("Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(MangaLocalization.string("Save")) {
                        saveChanges()
                    }
                }
            }
            .onChange(of: title) { _, newValue in
                if newValue != originalTitle {
                    titleWasExtracted = false
                }
            }
            .onChange(of: author) { _, newValue in
                if newValue != originalAuthor {
                    authorWasExtracted = false
                }
            }
            .alert(MangaLocalization.string("Unable to Save"), isPresented: $showingSaveError) {
                Button(MangaLocalization.string("OK")) {
                    showingSaveError = false
                    saveError = nil
                }
            } message: {
                if let error = saveError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        manga.title = trimmedTitle.isEmpty ? "" : trimmedTitle
        manga.author = trimmedAuthor.isEmpty ? nil : trimmedAuthor
        manga.titleWasExtracted = titleWasExtracted
        manga.authorWasExtracted = authorWasExtracted

        do {
            try viewContext.save()
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
        }
    }

    private func metadataBadge(isVisible: Bool) -> some View {
        Image(systemName: "character.textbox.badge.sparkles")
            .foregroundStyle(.secondary)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true)
            .frame(width: 20, alignment: .trailing)
    }
}
