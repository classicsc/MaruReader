// MangaMokuroFileURLTests.swift
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
import Foundation
@testable import MaruManga
import Testing

@MainActor
struct MangaMokuroFileURLTests {
    @Test func mokuroFile_nilFileName_returnsNil() {
        let persistenceController = makeMangaPersistenceController()
        let context = persistenceController.container.viewContext
        let manga = MangaArchive(context: context)
        manga.id = UUID()
        manga.title = "Test"

        #expect(manga.mokuroFile == nil)
    }

    @Test func mokuroFile_setFileName_resolvesToMangaDirectory() throws {
        let persistenceController = makeMangaPersistenceController()
        let context = persistenceController.container.viewContext
        let manga = MangaArchive(context: context)
        manga.id = UUID()
        manga.title = "Test"
        manga.mokuroFileName = "abc.mokuro"

        let expectedDirectory = try #require(MangaArchive.mangaDirectory())
        #expect(manga.mokuroFile == expectedDirectory.appendingPathComponent("abc.mokuro"))
    }
}
