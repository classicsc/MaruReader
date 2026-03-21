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
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct BookLibraryView: View {
    private static let scrollAnchor = "book-library-top"

    @AppStorage("selectedLibraryType") private var selectedLibraryType = LibraryType.books.rawValue
    @Environment(\.managedObjectContext) private var viewContext
    @State private var coverImageLoader = BookLibraryCoverImageLoader()
    @State private var model = BookLibraryModel()
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false

    private var libraryTypeBinding: Binding<LibraryType> {
        Binding(
            get: { LibraryType(rawValue: selectedLibraryType) ?? .books },
            set: { selectedLibraryType = $0.rawValue }
        )
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollViewReader { proxy in
                contentView
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Picker("Library", selection: libraryTypeBinding) {
                                ForEach(LibraryType.allCases, id: \.self) { type in
                                    Text(type.localizedName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }

                        ToolbarItem(placement: .primaryAction) {
                            Button(action: showFilePicker) {
                                Image(systemName: "plus")
                            }
                        }

                        ToolbarItem(placement: .secondaryAction) {
                            Menu {
                                Picker("Sort By", selection: $model.sortOption) {
                                    ForEach(BookSortOption.allCases) { option in
                                        Text(option.localizedName).tag(option)
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
                        allowsMultipleSelection: false,
                        onCompletion: handleFileImport
                    )
                    .alert("Import Error", isPresented: $showingError) {} message: {
                        if let error = importError {
                            Text(error.localizedDescription)
                        }
                    }
                    .fullScreenCover(
                        isPresented: isShowingReaderBinding,
                        onDismiss: dismissSelectedBook
                    ) {
                        if let selectedBookID = model.selectedBookID {
                            BookReaderView(
                                bookID: selectedBookID,
                                onDismiss: dismissSelectedBook
                            )
                        }
                    }
                    .task {
                        await model.configureIfNeeded(viewContext: viewContext)
                    }
                    .onChange(of: model.sortOption) {
                        withAnimation {
                            proxy.scrollTo(Self.scrollAnchor, anchor: .top)
                        }
                        Task {
                            await model.reloadForCurrentSort()
                        }
                    }
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            Color.clear
                .frame(height: 0)
                .id(Self.scrollAnchor)

            if model.hasLoadedInitialPage == false && model.snapshots.isEmpty {
                ProgressView("Loading books...")
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding()
            } else if model.snapshots.isEmpty {
                emptyStateView
            } else {
                BookLibraryGrid(
                    model: model,
                    coverImageLoader: coverImageLoader,
                    onOpen: openBook,
                    onCancelImport: cancelImport,
                    onRemove: removeBook,
                    onDelete: model.showDeleteConfirmation(for:)
                )
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

    private var isShowingReaderBinding: Binding<Bool> {
        Binding(
            get: { model.selectedBookID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissSelectedBook()
                }
            }
        )
    }

    private func showFilePicker() {
        showingFilePicker = true
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

    private func openBook(_ bookID: NSManagedObjectID) {
        model.selectedBookID = bookID
    }

    private func dismissSelectedBook() {
        model.selectedBookID = nil
    }

    private func cancelImport(_ bookID: NSManagedObjectID) {
        Task {
            await BookImportManager.shared.cancelImport(jobID: bookID)
        }
    }

    private func deleteBook(_ bookID: NSManagedObjectID) {
        Task {
            await BookImportManager.shared.deleteBook(bookID: bookID)
        }
    }

    private func removeBook(_ bookID: NSManagedObjectID) {
        model.dismissDeleteConfirmation()
        deleteBook(bookID)
    }
}
