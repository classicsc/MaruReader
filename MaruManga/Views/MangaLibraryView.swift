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
import Observation
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

public struct MangaArchiveLibraryView: View {
    private static let scrollAnchor = "manga-library-top"

    @AppStorage("selectedLibraryType") private var selectedLibraryType = MangaLibraryType.manga.rawValue
    @Environment(\.managedObjectContext) private var viewContext
    @State private var coverImageLoader = MangaLibraryCoverImageLoader()
    @State private var model = MangaLibraryModel()
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false

    public init() {}

    private var libraryTypeBinding: Binding<MangaLibraryType> {
        Binding(
            get: { MangaLibraryType(rawValue: selectedLibraryType) ?? .manga },
            set: { selectedLibraryType = $0.rawValue }
        )
    }

    public var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollViewReader { proxy in
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
                            Button(action: showFilePicker) {
                                Label(MangaLocalization.string("Import"), systemImage: "plus")
                            }
                            .labelStyle(.iconOnly)
                        }

                        ToolbarItem(placement: .secondaryAction) {
                            Menu {
                                Picker(MangaLocalization.string("Sort By"), selection: $model.sortOption) {
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
                        allowsMultipleSelection: false,
                        onCompletion: handleFileImport
                    )
                    .onChange(of: showingFilePicker) {
                        if showingFilePicker {
                            Task {
                                await MangaImportManager.shared.prewarmMetadataExtractor()
                            }
                        }
                    }
                    .alert(MangaLocalization.string("Import Error"), isPresented: $showingError) {} message: {
                        if let error = importError {
                            Text(error.localizedDescription)
                        }
                    }
                    .sheet(
                        isPresented: isShowingMetadataEditorBinding,
                        onDismiss: dismissMetadataEditor
                    ) {
                        if let metadataEditorMangaID = model.metadataEditorMangaID {
                            MangaMetadataEditorView(mangaID: metadataEditorMangaID)
                        }
                    }
                    .fullScreenCover(
                        isPresented: isShowingReaderBinding,
                        onDismiss: dismissSelectedManga
                    ) {
                        if let selectedMangaID = model.selectedMangaID {
                            MangaReaderView(mangaID: selectedMangaID)
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
                ProgressView(MangaLocalization.string("Loading manga..."))
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding()
            } else if model.snapshots.isEmpty {
                emptyStateView
            } else {
                MangaLibraryGrid(
                    model: model,
                    coverImageLoader: coverImageLoader,
                    onOpen: openManga,
                    onEditMetadata: editMetadata,
                    onCancelImport: cancelImport,
                    onRemove: removeMangaArchive,
                    onDelete: model.showDeleteConfirmation(for:)
                )
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

    private var isShowingMetadataEditorBinding: Binding<Bool> {
        Binding(
            get: { model.metadataEditorMangaID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissMetadataEditor()
                }
            }
        )
    }

    private var isShowingReaderBinding: Binding<Bool> {
        Binding(
            get: { model.selectedMangaID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissSelectedManga()
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

    private func openManga(_ mangaID: NSManagedObjectID) {
        model.selectedMangaID = mangaID
    }

    private func dismissSelectedManga() {
        model.selectedMangaID = nil
    }

    private func editMetadata(_ mangaID: NSManagedObjectID) {
        model.metadataEditorMangaID = mangaID
    }

    private func dismissMetadataEditor() {
        model.metadataEditorMangaID = nil
    }

    private func cancelImport(_ mangaID: NSManagedObjectID) {
        Task {
            await MangaImportManager.shared.cancelImport(jobID: mangaID)
        }
    }

    private func deleteMangaArchive(_ mangaID: NSManagedObjectID) {
        Task {
            await MangaImportManager.shared.deleteManga(mangaID: mangaID)
        }
    }

    private func removeMangaArchive(_ mangaID: NSManagedObjectID) {
        model.dismissDeleteConfirmation()
        deleteMangaArchive(mangaID)
    }
}
