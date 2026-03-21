// BookReaderLookupModelTests.swift
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

import CoreGraphics
import Foundation
import MaruDictionaryUICommon
@testable import MaruReader
import Testing

@MainActor
struct BookReaderLookupModelTests {
    private func makeLookupModel() throws -> BookReaderLookupModel {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        try context.save()

        let repository = BookReaderRepository(persistenceController: persistenceController)
        let session = BookReaderSessionModel(bookID: book.objectID, repository: repository, loadPublicationOnInit: false)
        let preferences = ReaderPreferences(bookID: book.objectID, persistenceController: persistenceController, context: context)
        return BookReaderLookupModel(session: session, readerPreferences: preferences)
    }

    @Test func presentAndDismissDictionarySheet_ManagePresentation() throws {
        let lookup = try makeLookupModel()
        let searchViewModel = DictionarySearchViewModel()

        lookup.presentDictionarySheet(with: searchViewModel)
        #expect(lookup.dictionarySheetPresentation?.viewModel === searchViewModel)

        lookup.dismissDictionarySheet()
        #expect(lookup.dictionarySheetPresentation == nil)
    }

    @Test func hidePopup_ResetsVisibilityAndAnchor() throws {
        let lookup = try makeLookupModel()
        lookup.popupAnchorPosition = CGRect(x: 10, y: 20, width: 30, height: 40)
        lookup.showPopup = true

        lookup.hidePopup()

        #expect(!lookup.showPopup)
        #expect(lookup.popupAnchorPosition == .zero)
    }
}
