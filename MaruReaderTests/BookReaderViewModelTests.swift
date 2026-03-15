// BookReaderViewModelTests.swift
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
import MaruDictionaryUICommon
@testable import MaruReader
import ReadiumShared
import Testing
import UIKit

@MainActor
struct BookReaderViewModelTests {
    private func makeViewModel() -> (viewModel: BookReaderViewModel, persistenceController: BookDataPersistenceController) {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        return (BookReaderViewModel(book: book, loadPublicationOnInit: false), persistenceController)
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

    @Test func presentDictionarySheet_SetsPresentationAndOverlayState() {
        let (viewModel, _) = makeViewModel()
        let searchViewModel = DictionarySearchViewModel()

        viewModel.presentDictionarySheet(with: searchViewModel)

        #expect(viewModel.dictionarySheetPresentation?.viewModel === searchViewModel)
        #expect(viewModel.overlayState == .showingDictionarySheet)
    }

    @Test func dismissDictionarySheet_ClearsPresentationAndOverlayState() {
        let (viewModel, _) = makeViewModel()

        viewModel.presentDictionarySheet(with: DictionarySearchViewModel())
        viewModel.dismissDictionarySheet()

        #expect(viewModel.dictionarySheetPresentation == nil)
        #expect(viewModel.overlayState == .none)
    }

    @Test func presentDictionarySheet_ReplacesExistingPresentation() {
        let (viewModel, _) = makeViewModel()
        let firstSearchViewModel = DictionarySearchViewModel()
        let secondSearchViewModel = DictionarySearchViewModel()

        viewModel.presentDictionarySheet(with: firstSearchViewModel)
        let firstPresentationID = viewModel.dictionarySheetPresentation?.id

        viewModel.presentDictionarySheet(with: secondSearchViewModel)

        #expect(viewModel.dictionarySheetPresentation?.viewModel === secondSearchViewModel)
        #expect(viewModel.dictionarySheetPresentation?.id != firstPresentationID)
    }

    @Test func dismissDictionarySheet_LeavesOtherOverlayStateUntouched() {
        let (viewModel, _) = makeViewModel()
        viewModel.overlayState = .showingBookmarks

        viewModel.dismissDictionarySheet()

        #expect(viewModel.overlayState == .showingBookmarks)
    }

    @Test func currentLocationBookmark_ReturnsBookmarkMatchingCurrentLocator() throws {
        let (viewModel, persistenceController) = makeViewModel()
        let context = persistenceController.container.viewContext
        let locator = makeLocator(href: "chapter-1.xhtml", position: 4, totalProgression: 0.2)
        let bookmark = Bookmark(context: context)
        bookmark.id = UUID()
        bookmark.location = locator.jsonString
        bookmark.createdAt = .now
        bookmark.book = viewModel.book
        try context.save()

        viewModel.loadBookmarks()
        viewModel.currentLocator = locator

        #expect(viewModel.currentLocationBookmark?.objectID == bookmark.objectID)
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

        let index = BookReaderViewModel.makeChapterTitleIndex(from: links)

        #expect(index["chapter-1.xhtml"] == "Chapter 1")
        #expect(index["chapter-1-section.xhtml"] == "Section 1.1")
        #expect(index["chapter-2.xhtml"] == "Chapter 2")
    }

    @Test func bookmarkRowData_MakesPresentationValuesFromCachedInputs() {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let currentLocator = makeLocator(
            href: "chapter-1.xhtml",
            position: 7,
            totalProgression: 0.42
        )
        let currentBookmark = Bookmark(context: context)
        currentBookmark.id = UUID()
        currentBookmark.title = "Current Bookmark"
        currentBookmark.location = currentLocator.jsonString

        let invalidBookmark = Bookmark(context: context)
        invalidBookmark.id = UUID()
        invalidBookmark.title = nil
        invalidBookmark.location = "{invalid json}"

        let rows = BookReaderBookmarkRowData.makeRows(
            bookmarks: [currentBookmark, invalidBookmark],
            currentHref: currentLocator.href.string,
            chapterTitleByHref: ["chapter-1.xhtml": "Chapter 1"]
        )

        #expect(rows.count == 2)
        #expect(rows[0].displayTitle == "Current Bookmark")
        #expect(rows[0].chapterTitle == "Chapter 1")
        #expect(rows[0].progressText == String(localized: "Book 42%"))
        #expect(rows[0].isCurrent)
        #expect(rows[1].displayTitle == "Bookmark")
        #expect(rows[1].chapterTitle == nil)
        #expect(rows[1].progressText == nil)
        #expect(!rows[1].isCurrent)
    }

    @Test func loadCoverImageIfNeeded_CachesLoadedImage() async throws {
        let (viewModel, _) = makeViewModel()
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

        viewModel.book.coverFileName = coverFileName

        let firstImage = await viewModel.loadCoverImageIfNeeded()
        let secondImage = await viewModel.loadCoverImageIfNeeded()

        #expect(firstImage != nil)
        #expect(firstImage === secondImage)
        #expect(viewModel.coverImage === firstImage)
    }
}
