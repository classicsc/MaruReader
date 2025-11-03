//
//  ContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import MaruDictionaryUICommon
import MaruReaderCore
import MaruVisionUICommon
import SwiftUI

struct ContentView: View {
    private let bookPersistenceController = BookDataPersistenceController.shared
    private let dictionaryPersistenceController = DictionaryPersistenceController.shared

    @State private var searchViewModel = DictionarySearchViewModel()
    @State private var query: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                BookLibraryView()
                    .environment(\.managedObjectContext, bookPersistenceController.container.viewContext)
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
            }
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
        .tabViewSearchActivation(.searchTabSelection)
    }
}
