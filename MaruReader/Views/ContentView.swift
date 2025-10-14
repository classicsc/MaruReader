//
//  ContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BookLibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            DictionarySearchView()
                .tabItem { Label("Dictionary", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
