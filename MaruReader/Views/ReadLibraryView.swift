// ReadLibraryView.swift
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

import MaruManga
import MaruReaderCore
import SwiftUI

enum LibraryType: String, CaseIterable {
    case books = "Books"
    case manga = "Manga"
}

struct ReadLibraryView: View {
    // Store references to ensure Core Data stacks are initialized before views that use them
    private let bookPersistenceController = BookDataPersistenceController.shared
    private let mangaPersistenceController = MangaDataPersistenceController.shared

    @AppStorage("selectedLibraryType") private var selectedType = LibraryType.books.rawValue

    var body: some View {
        if selectedType == LibraryType.manga.rawValue {
            MangaArchiveLibraryView()
                .environment(\.managedObjectContext, mangaPersistenceController.container.viewContext)
        } else {
            BookLibraryView()
                .environment(\.managedObjectContext, bookPersistenceController.container.viewContext)
        }
    }
}
