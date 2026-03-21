// BookReaderSessionModelTests.swift
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
import ReadiumShared
import Testing
import UIKit

@MainActor
struct BookReaderSessionModelTests {
    private func makeSession(
        configureBook: (Book) -> Void = { _ in }
    ) throws -> (BookReaderSessionModel, BookReaderRepository, Book, NSManagedObjectContext) {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        configureBook(book)
        try context.save()

        let repository = BookReaderRepository(persistenceController: persistenceController)
        let session = BookReaderSessionModel(
            bookID: book.objectID,
            repository: repository,
            loadPublicationOnInit: false
        )
        return (session, repository, book, context)
    }

    private func makeLocator(
        href: String,
        position: Int? = nil,
        progression: Double? = nil,
        totalProgression: Double? = nil
    ) -> Locator {
        let anyURL = AnyURL(path: href)!
        return Locator(
            href: anyURL,
            mediaType: .html,
            locations: .init(
                progression: progression,
                totalProgression: totalProgression,
                position: position
            )
        )
    }

    @Test func init_UsesLoadingPhaseWhenNotAutoloading() throws {
        let (session, _, _, _) = try makeSession()

        if case .loading = session.phase {
            #expect(true)
        } else {
            Issue.record("Expected loading phase")
        }
    }

    @Test func loadPublication_WithoutFileNameTransitionsToError() async throws {
        let (session, _, _, _) = try makeSession()

        await session.loadPublication()

        if case let .error(error) = session.phase {
            if case .bookFileNotFound = error as? BookReaderError {
                #expect(true)
            } else {
                Issue.record("Expected bookFileNotFound error")
            }
        } else {
            Issue.record("Expected error phase")
        }
    }

    @Test func handleLocationDidChange_SavesLocatorAndProgress() throws {
        let (session, repository, book, _) = try makeSession()
        let locator = makeLocator(href: "chapter-1.xhtml", position: 4, totalProgression: 0.42)

        session.handleLocationDidChange(locator)

        let snapshot = try repository.loadBookSnapshot(bookID: book.objectID)
        #expect(snapshot.lastOpenedPage == locator.jsonString)
        #expect(snapshot.progressPercent == "42%")
    }

    @Test func makeChapterTitleIndex_CollectsNestedTitles() {
        let links = [
            Link(
                href: "chapter-1.xhtml",
                title: "Chapter 1",
                children: [
                    Link(href: "chapter-1-section.xhtml", title: "Section 1.1"),
                ]
            ),
            Link(href: "chapter-2.xhtml", title: "Chapter 2"),
        ]

        let index = BookReaderSessionModel.makeChapterTitleIndex(from: links)

        #expect(index["chapter-1.xhtml"] == "Chapter 1")
        #expect(index["chapter-1-section.xhtml"] == "Section 1.1")
        #expect(index["chapter-2.xhtml"] == "Chapter 2")
    }

    @Test func loadCoverImageIfNeeded_CachesLoadedImage() async throws {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let coversDirectory = appSupportURL.appendingPathComponent("Covers", isDirectory: true)
        try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)

        let coverFileName = "test-cover-\(UUID().uuidString).png"
        let coverURL = coversDirectory.appendingPathComponent(coverFileName)
        defer { try? FileManager.default.removeItem(at: coverURL) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let pngData = try #require(image.pngData())
        try pngData.write(to: coverURL)

        let (session, _, _, _) = try makeSession { book in
            book.coverFileName = coverFileName
        }

        let firstImage = await session.loadCoverImageIfNeeded()
        let secondImage = await session.loadCoverImageIfNeeded()

        #expect(firstImage != nil)
        #expect(firstImage === secondImage)
        #expect(session.coverImage === firstImage)
    }
}
