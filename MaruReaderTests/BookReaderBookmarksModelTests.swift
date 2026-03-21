// BookReaderBookmarksModelTests.swift
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

import Foundation
@testable import MaruReader
import ReadiumShared
import Testing

@MainActor
struct BookReaderBookmarksModelTests {
    private func makeLocator(
        href: String,
        position: Int? = nil,
        totalProgression: Double? = nil
    ) -> Locator {
        let anyURL = AnyURL(path: href)!
        return Locator(
            href: anyURL,
            mediaType: .html,
            locations: .init(
                totalProgression: totalProgression,
                position: position
            )
        )
    }

    private func makeBookmarksModel() throws -> (BookReaderBookmarksModel, BookReaderSessionModel, BookReaderRepository, Book) {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        try context.save()

        let repository = BookReaderRepository(persistenceController: persistenceController)
        let session = BookReaderSessionModel(bookID: book.objectID, repository: repository, loadPublicationOnInit: false)
        let bookmarks = BookReaderBookmarksModel(bookID: book.objectID, repository: repository, session: session)
        return (bookmarks, session, repository, book)
    }

    @Test func bookmarkCurrentLocation_CreatesSnapshotAndMarksCurrent() throws {
        let (bookmarks, session, _, _) = try makeBookmarksModel()
        session.currentLocator = makeLocator(href: "chapter-1.xhtml", position: 4, totalProgression: 0.2)

        bookmarks.bookmarkCurrentLocation()

        #expect(bookmarks.bookmarks.count == 1)
        #expect(bookmarks.currentLocationBookmark?.title == "Position 4")
        #expect(bookmarks.currentLocationBookmarkID == bookmarks.bookmarks[0].id)
    }

    @Test func updateBookmarkTitle_RefreshesSnapshots() throws {
        let (bookmarks, session, _, _) = try makeBookmarksModel()
        session.currentLocator = makeLocator(href: "chapter-1.xhtml", position: 4, totalProgression: 0.2)
        bookmarks.bookmarkCurrentLocation()
        let created = try #require(bookmarks.bookmarks.first)

        bookmarks.updateBookmarkTitle(created, title: "Renamed")

        #expect(bookmarks.bookmarks.first?.title == "Renamed")
    }

    @Test func bookmarkRows_MakePresentationValuesFromSnapshots() throws {
        let (_, session, repository, book) = try makeBookmarksModel()
        let currentLocator = makeLocator(href: "chapter-1.xhtml", position: 7, totalProgression: 0.42)
        session.currentLocator = currentLocator

        let currentBookmark = try repository.createBookmark(
            bookID: book.objectID,
            locatorJSON: currentLocator.jsonString ?? "",
            title: "Current Bookmark"
        )
        let invalidBookmark = try repository.createBookmark(
            bookID: book.objectID,
            locatorJSON: "{invalid json}",
            title: "Temporary"
        )
        try repository.renameBookmark(bookmarkID: invalidBookmark.id, title: nil)

        let rows = try BookReaderBookmarkRowData.makeRows(
            bookmarks: repository.fetchBookmarks(bookID: book.objectID),
            currentHref: currentLocator.href.string,
            chapterTitleByHref: ["chapter-1.xhtml": "Chapter 1"]
        )

        #expect(rows.count == 2)
        let currentRow = rows.first { $0.snapshot.id == currentBookmark.id }
        let invalidRow = rows.first { $0.snapshot.id == invalidBookmark.id }
        #expect(invalidRow?.displayTitle == "Bookmark")
        #expect(currentRow?.displayTitle == "Current Bookmark")
        #expect(currentRow?.chapterTitle == "Chapter 1")
        #expect(currentRow?.progressText == "Book 42%")
        #expect(currentRow?.isCurrent == true)
    }
}
