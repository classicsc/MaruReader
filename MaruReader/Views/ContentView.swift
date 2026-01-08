// ContentView.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import MaruDictionaryUICommon
import MaruManga
import MaruReaderCore
import SwiftUI

struct ContentView: View {
    private let bookPersistenceController = BookDataPersistenceController.shared
    private let dictionaryPersistenceController = DictionaryPersistenceController.shared
    private let mangaPersistenceController = MangaDataPersistenceController.shared

    @State private var searchViewModel = DictionarySearchViewModel()
    @State private var query: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                BookLibraryView()
                    .environment(\.managedObjectContext, bookPersistenceController.container.viewContext)
            }
            Tab("Manga", systemImage: "book.closed") {
                MangaArchiveLibraryView()
                    .environment(\.managedObjectContext, mangaPersistenceController.container.viewContext)
            }
            Tab("Scan", systemImage: "doc.text.viewfinder") {
                OCRScanView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
                    .environment(\.managedObjectContext, dictionaryPersistenceController.container.viewContext)
            }
            Tab(role: .search) {
                NavigationStack {
                    DictionarySearchView()
                        .environment(searchViewModel)
                }
                .searchable(text: $query, placement: .automatic, prompt: "Search Dictionary")
                .searchFocused($isSearchFieldFocused)
                .onChange(of: query) { _, newValue in
                    searchViewModel.performSearch(newValue)
                }
                .onChange(of: isSearchFieldFocused) { _, isFocused in
                    if isFocused {
                        searchViewModel.textFieldFocused()
                    } else {
                        searchViewModel.textFieldUnfocused()
                    }
                }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
    }
}
