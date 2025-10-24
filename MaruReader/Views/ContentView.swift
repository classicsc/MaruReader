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
            DictionarySearchView()
                .tabItem { Label("Dictionary", systemImage: "magnifyingglass") }
                .environment(\.managedObjectContext, dictionaryPersistenceController.container.viewContext)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .environment(\.managedObjectContext, dictionaryPersistenceController.container.viewContext)
        }
    }
}
