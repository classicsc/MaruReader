// BookLibraryGrid.swift
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

struct BookLibraryGrid: View {
    let model: BookLibraryModel
    let coverImageLoader: BookLibraryCoverImageLoader
    let onOpen: (NSManagedObjectID) -> Void
    let onCancelImport: (NSManagedObjectID) -> Void
    let onRemove: (NSManagedObjectID) -> Void
    let onDelete: (NSManagedObjectID) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16),
            ],
            spacing: 20
        ) {
            ForEach(model.snapshots) { snapshot in
                if snapshot.isComplete {
                    Button {
                        onOpen(snapshot.objectID)
                    } label: {
                        BookLibraryGridItem(
                            snapshot: snapshot,
                            coverImageLoader: coverImageLoader,
                            onCancel: {},
                            onRemove: {}
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(snapshot.objectID)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .confirmationDialog(
                        "Delete Book",
                        isPresented: deleteConfirmationBinding(for: snapshot.objectID)
                    ) {
                        Button("Delete", role: .destructive) {
                            onRemove(snapshot.objectID)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(AppLocalization.deleteConfirmationActionCannotBeUndone(name: snapshot.title))
                    }
                } else {
                    BookLibraryGridItem(
                        snapshot: snapshot,
                        coverImageLoader: coverImageLoader,
                        onCancel: { onCancelImport(snapshot.objectID) },
                        onRemove: { onRemove(snapshot.objectID) }
                    )
                }
            }

            if model.hasMorePages || model.isLoadingPage {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(2)
                    .padding(.vertical, 12)
                    .onAppear {
                        Task {
                            await model.loadNextPage()
                        }
                    }
            }
        }
        .padding()
    }

    private func deleteConfirmationBinding(for objectID: NSManagedObjectID) -> Binding<Bool> {
        Binding(
            get: { model.pendingDeleteBookID == objectID },
            set: { isPresented in
                if isPresented {
                    model.showDeleteConfirmation(for: objectID)
                } else {
                    model.dismissDeleteConfirmation()
                }
            }
        )
    }
}
