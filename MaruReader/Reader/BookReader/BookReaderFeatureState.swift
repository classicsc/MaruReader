// BookReaderFeatureState.swift
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
final class BookReaderFeatureState {
    let session: BookReaderSessionModel
    let chrome: BookReaderChromeModel
    let bookmarks: BookReaderBookmarksModel
    let lookup: BookReaderLookupModel
    let readerPreferences: ReaderPreferences

    init(bookID: NSManagedObjectID, persistenceController: BookDataPersistenceController = .shared) {
        let repository = BookReaderRepository(persistenceController: persistenceController)
        let session = BookReaderSessionModel(
            bookID: bookID,
            repository: repository,
            loadPublicationOnInit: false
        )
        let chrome = BookReaderChromeModel()
        let readerPreferences = ReaderPreferences(bookID: bookID, persistenceController: persistenceController)
        let lookup = BookReaderLookupModel(session: session, readerPreferences: readerPreferences)
        let bookmarks = BookReaderBookmarksModel(bookID: bookID, repository: repository, session: session)

        self.session = session
        self.chrome = chrome
        self.bookmarks = bookmarks
        self.lookup = lookup
        self.readerPreferences = readerPreferences
    }
}
