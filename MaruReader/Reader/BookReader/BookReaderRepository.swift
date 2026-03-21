// BookReaderRepository.swift
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

@MainActor
final class BookReaderRepository {
    private let persistenceController: BookDataPersistenceController

    init(persistenceController: BookDataPersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    func loadBookSnapshot(bookID: NSManagedObjectID) throws -> BookReaderBookSnapshot {
        let book = try book(for: bookID)
        return BookReaderBookSnapshot(
            id: book.objectID,
            title: book.title,
            author: book.author,
            fileName: book.fileName,
            coverFileName: book.coverFileName,
            lastOpenedPage: book.lastOpenedPage,
            progressPercent: book.progressPercent
        )
    }

    func saveReadingProgress(
        bookID: NSManagedObjectID,
        locatorJSON: String?,
        progressPercent: String?
    ) throws {
        let book = try book(for: bookID)
        book.lastOpenedPage = locatorJSON
        book.progressPercent = progressPercent
        try saveIfNeeded()
    }

    func fetchBookmarks(bookID: NSManagedObjectID) throws -> [BookReaderBookmarkSnapshot] {
        let book = try book(for: bookID)
        let request = NSFetchRequest<Bookmark>(entityName: "Bookmark")
        request.predicate = NSPredicate(format: "book == %@", book)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bookmark.createdAt, ascending: false)]

        return try viewContext.fetch(request).map {
            BookReaderBookmarkSnapshot(
                id: $0.objectID,
                title: $0.title,
                locationJSON: $0.location,
                createdAt: $0.createdAt
            )
        }
    }

    @discardableResult
    func createBookmark(
        bookID: NSManagedObjectID,
        locatorJSON: String,
        title: String
    ) throws -> BookReaderBookmarkSnapshot {
        let book = try book(for: bookID)
        let bookmark = Bookmark(context: viewContext)
        bookmark.id = UUID()
        bookmark.location = locatorJSON
        bookmark.createdAt = Date()
        bookmark.title = title
        bookmark.book = book
        try saveIfNeeded()

        return BookReaderBookmarkSnapshot(
            id: bookmark.objectID,
            title: bookmark.title,
            locationJSON: bookmark.location,
            createdAt: bookmark.createdAt
        )
    }

    func deleteBookmark(bookmarkID: NSManagedObjectID) throws {
        let bookmark = try bookmark(for: bookmarkID)
        viewContext.delete(bookmark)
        try saveIfNeeded()
    }

    func renameBookmark(bookmarkID: NSManagedObjectID, title: String?) throws {
        let bookmark = try bookmark(for: bookmarkID)
        bookmark.title = title
        try saveIfNeeded()
    }

    private func book(for objectID: NSManagedObjectID) throws -> Book {
        guard let book = try viewContext.existingObject(with: objectID) as? Book else {
            throw BookReaderError.bookNotFound
        }
        return book
    }

    private func bookmark(for objectID: NSManagedObjectID) throws -> Bookmark {
        guard let bookmark = try viewContext.existingObject(with: objectID) as? Bookmark else {
            throw BookReaderError.bookmarkNotFound
        }
        return bookmark
    }

    private func saveIfNeeded() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }
}
