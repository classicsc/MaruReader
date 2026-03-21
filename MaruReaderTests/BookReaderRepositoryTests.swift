// BookReaderRepositoryTests.swift
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
@testable import MaruReader
import Testing

@MainActor
struct BookReaderRepositoryTests {
    private func makeRepository() throws -> (BookReaderRepository, Book, NSManagedObjectContext) {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        book.title = "Kokoro"
        book.author = "Soseki"
        try context.save()

        return (BookReaderRepository(persistenceController: persistenceController), book, context)
    }

    @Test func loadBookSnapshot_ReturnsStoredMetadata() throws {
        let (repository, book, _) = try makeRepository()

        let snapshot = try repository.loadBookSnapshot(bookID: book.objectID)

        #expect(snapshot.id == book.objectID)
        #expect(snapshot.title == "Kokoro")
        #expect(snapshot.author == "Soseki")
    }

    @Test func saveReadingProgress_PersistsLocatorAndPercent() throws {
        let (repository, book, context) = try makeRepository()

        try repository.saveReadingProgress(
            bookID: book.objectID,
            locatorJSON: "{\"href\":\"chapter-1.xhtml\"}",
            progressPercent: "42%"
        )

        let savedBook = try #require(context.existingObject(with: book.objectID) as? Book)
        #expect(savedBook.lastOpenedPage == "{\"href\":\"chapter-1.xhtml\"}")
        #expect(savedBook.progressPercent == "42%")
    }

    @Test func bookmarkCRUD_UsesSnapshots() throws {
        let (repository, book, _) = try makeRepository()

        let created = try repository.createBookmark(
            bookID: book.objectID,
            locatorJSON: "{\"href\":\"chapter-1.xhtml\"}",
            title: "Chapter 1"
        )
        #expect(created.title == "Chapter 1")

        var bookmarks = try repository.fetchBookmarks(bookID: book.objectID)
        #expect(bookmarks.count == 1)
        #expect(bookmarks[0].id == created.id)

        try repository.renameBookmark(bookmarkID: created.id, title: "Updated")
        bookmarks = try repository.fetchBookmarks(bookID: book.objectID)
        #expect(bookmarks[0].title == "Updated")

        try repository.deleteBookmark(bookmarkID: created.id)
        bookmarks = try repository.fetchBookmarks(bookID: book.objectID)
        #expect(bookmarks.isEmpty)
    }
}
