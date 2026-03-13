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
import Testing

@MainActor
struct BookReaderViewModelTests {
    private func makeViewModel() -> BookReaderViewModel {
        let context = BookDataPersistenceController.shared.container.viewContext
        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"
        return BookReaderViewModel(book: book, loadPublicationOnInit: false)
    }

    @Test func presentDictionarySheet_SetsPresentationAndOverlayState() {
        let viewModel = makeViewModel()
        let searchViewModel = DictionarySearchViewModel()

        viewModel.presentDictionarySheet(with: searchViewModel)

        #expect(viewModel.dictionarySheetPresentation?.viewModel === searchViewModel)
        #expect(viewModel.overlayState == .showingDictionarySheet)
    }

    @Test func dismissDictionarySheet_ClearsPresentationAndOverlayState() {
        let viewModel = makeViewModel()

        viewModel.presentDictionarySheet(with: DictionarySearchViewModel())
        viewModel.dismissDictionarySheet()

        #expect(viewModel.dictionarySheetPresentation == nil)
        #expect(viewModel.overlayState == .none)
    }

    @Test func presentDictionarySheet_ReplacesExistingPresentation() {
        let viewModel = makeViewModel()
        let firstSearchViewModel = DictionarySearchViewModel()
        let secondSearchViewModel = DictionarySearchViewModel()

        viewModel.presentDictionarySheet(with: firstSearchViewModel)
        let firstPresentationID = viewModel.dictionarySheetPresentation?.id

        viewModel.presentDictionarySheet(with: secondSearchViewModel)

        #expect(viewModel.dictionarySheetPresentation?.viewModel === secondSearchViewModel)
        #expect(viewModel.dictionarySheetPresentation?.id != firstPresentationID)
    }

    @Test func dismissDictionarySheet_LeavesOtherOverlayStateUntouched() {
        let viewModel = makeViewModel()
        viewModel.overlayState = .showingBookmarks

        viewModel.dismissDictionarySheet()

        #expect(viewModel.overlayState == .showingBookmarks)
    }
}
