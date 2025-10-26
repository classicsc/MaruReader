//
//  ContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import MaruDictionaryUICommon
import MaruReaderCore
import SwiftUI

struct ContentView: View {
    private let bookPersistenceController = BookDataPersistenceController.shared
    private let dictionaryPersistenceController = DictionaryPersistenceController.shared

    var body: some View {
        TabView {
            BookLibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .environment(\.managedObjectContext, bookPersistenceController.container.viewContext)
            DictionarySearchTab()
                .tabItem { Label("Dictionary", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .environment(\.managedObjectContext, dictionaryPersistenceController.container.viewContext)
        }
    }
}

struct DictionarySearchTab: View {
    @State private var searchViewModel = DictionarySearchViewModel()
    @State private var query: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
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
