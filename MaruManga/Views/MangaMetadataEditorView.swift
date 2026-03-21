// MangaMetadataEditorView.swift
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

struct MangaMetadataEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    private let mangaID: NSManagedObjectID

    @State private var manga: MangaArchive?
    @State private var title = ""
    @State private var author = ""
    @State private var titleWasExtracted = false
    @State private var authorWasExtracted = false
    @State private var saveError: Error?
    @State private var showingSaveError = false
    @State private var originalTitle = ""
    @State private var originalAuthor = ""

    init(manga: MangaArchive) {
        mangaID = manga.objectID
    }

    init(mangaID: NSManagedObjectID) {
        self.mangaID = mangaID
    }

    var body: some View {
        NavigationStack {
            Group {
                if let manga {
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
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .disabled(manga == nil)
                }
            }
            .task {
                resolveMangaIfNeeded()
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
                if let saveError {
                    Text(saveError.localizedDescription)
                }
            }
        }
    }

    private func resolveMangaIfNeeded() {
        guard manga == nil else { return }
        guard let resolvedManga = try? viewContext.existingObject(with: mangaID) as? MangaArchive else { return }

        manga = resolvedManga
        let resolvedTitle = resolvedManga.title ?? ""
        let resolvedAuthor = resolvedManga.author ?? ""
        title = resolvedTitle
        author = resolvedAuthor
        titleWasExtracted = resolvedManga.titleWasExtracted
        authorWasExtracted = resolvedManga.authorWasExtracted
        originalTitle = resolvedTitle
        originalAuthor = resolvedAuthor
    }

    private func saveChanges() {
        guard let manga else { return }

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
