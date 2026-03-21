// BookReaderBookmarksModel.swift
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
import Observation
import os
import ReadiumShared

@MainActor
@Observable
final class BookReaderBookmarksModel {
    private(set) var bookmarks: [BookReaderBookmarkSnapshot] = []
    var previousLocation: Locator?

    private let bookID: NSManagedObjectID
    private let repository: BookReaderRepository
    private let session: BookReaderSessionModel
    private let logger = Logger.maru(category: "BookReaderBookmarksModel")

    init(
        bookID: NSManagedObjectID,
        repository: BookReaderRepository,
        session: BookReaderSessionModel
    ) {
        self.bookID = bookID
        self.repository = repository
        self.session = session
        loadBookmarks()
    }

    var currentLocationBookmark: BookReaderBookmarkSnapshot? {
        guard let currentJSON = session.currentLocator?.jsonString else { return nil }
        return bookmarks.first { $0.locationJSON == currentJSON }
    }

    var currentLocationBookmarkID: NSManagedObjectID? {
        currentLocationBookmark?.id
    }

    var isCurrentLocationBookmarked: Bool {
        currentLocationBookmark != nil
    }

    var bookmarkRows: [BookReaderBookmarkRowData] {
        BookReaderBookmarkRowData.makeRows(
            bookmarks: bookmarks,
            currentHref: session.currentLocator?.href.string,
            chapterTitleByHref: session.chapterTitleByHref
        )
    }

    func loadBookmarks() {
        do {
            bookmarks = try repository.fetchBookmarks(bookID: bookID)
        } catch {
            logger.error("Failed to fetch bookmarks: \(error.localizedDescription)")
            bookmarks = []
        }
    }

    func bookmarkCurrentLocation() {
        guard let locator = session.currentLocator else {
            logger.warning("Cannot bookmark: no current location")
            return
        }

        do {
            try repository.createBookmark(
                bookID: bookID,
                locatorJSON: locator.jsonString ?? "",
                title: generateDefaultBookmarkTitle(for: locator)
            )
            loadBookmarks()
        } catch {
            logger.error("Failed to save bookmark: \(error.localizedDescription)")
        }
    }

    func removeBookmarkAtCurrentLocation() {
        guard let bookmark = currentLocationBookmark else {
            logger.warning("Cannot remove bookmark: no bookmark at current location")
            return
        }

        deleteBookmark(bookmark)
    }

    func navigateToBookmark(_ bookmark: BookReaderBookmarkSnapshot, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard let locator = bookmark.locator else {
            logger.warning("Cannot navigate to bookmark: invalid location")
            return
        }

        previousLocation = session.currentLocator
        session.navigate(to: locator, onSuccess: onSuccess)
    }

    func returnToPreviousLocation(onSuccess: @escaping @MainActor () -> Void = {}) {
        guard let locator = previousLocation else {
            logger.warning("Cannot return: no previous location")
            return
        }

        session.navigate(to: locator) { [weak self] in
            self?.previousLocation = nil
            onSuccess()
        }
    }

    func deleteBookmark(_ bookmark: BookReaderBookmarkSnapshot) {
        do {
            try repository.deleteBookmark(bookmarkID: bookmark.id)
            loadBookmarks()
        } catch {
            logger.error("Failed to delete bookmark: \(error.localizedDescription)")
        }
    }

    func updateBookmarkTitle(_ bookmark: BookReaderBookmarkSnapshot, title: String) {
        let newTitle = title.isEmpty ? nil : title

        do {
            try repository.renameBookmark(bookmarkID: bookmark.id, title: newTitle)
            loadBookmarks()
        } catch {
            logger.error("Failed to update bookmark title: \(error.localizedDescription)")
        }
    }

    private func generateDefaultBookmarkTitle(for locator: Locator) -> String {
        if let chapterTitle = session.chapterTitleByHref[locator.href.string] {
            return chapterTitle
        }
        if let position = locator.locations.position {
            return String(localized: "Position \(position)")
        }
        if let totalProgression = locator.locations.totalProgression {
            let percent = Int(totalProgression * 100)
            return String(localized: "Book \(percent)%")
        }
        return String(localized: "Bookmark")
    }
}
