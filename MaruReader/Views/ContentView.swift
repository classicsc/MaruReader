// ContentView.swift
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

import MaruDictionaryUICommon
import MaruManga
import MaruReaderCore
import MaruWeb
import SwiftUI

struct ContentView: View {
    @Environment(\.dictionaryFeatureAvailability) private var dictionaryAvailability

    var body: some View {
        TabView {
            Tab("Read", systemImage: "books.vertical") {
                ReadLibraryView()
                    .accessibilityIdentifier("readLibrary")
            }
            Tab("Scan", systemImage: "doc.text.viewfinder") {
                OCRScanView()
            }
            Tab("Web", systemImage: "globe") {
                MaruWebRootView()
                    .accessibilityIdentifier("webBrowser")
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
            Tab(role: .search) {
                DictionarySearchRootView(availability: dictionaryAvailability)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSearchActivation(.searchTabSelection)
    }
}
