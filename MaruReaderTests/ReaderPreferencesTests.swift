// ReaderPreferencesTests.swift
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
@testable import MaruReader
import Testing

@MainActor
struct ReaderPreferencesTests {
    private func makeReaderPreferences(initialFontSize: Double) throws -> (ReaderPreferences, ReaderProfile) {
        let persistenceController = BookDataPersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"

        let profile = ReaderProfile(context: context)
        profile.id = UUID()
        profile.language = "ja"
        profile.name = "Test Profile"
        profile.fontSize = initialFontSize

        book.readerProfile = profile
        try context.save()

        return (ReaderPreferences(book: book, context: context), profile)
    }

    @Test func increaseFontSize_UsesEffectiveDefaultWhenNoStoredOverride() throws {
        let (preferences, profile) = try makeReaderPreferences(initialFontSize: 0.0)

        preferences.increaseFontSize()

        #expect(profile.fontSize == 110.0)
    }

    @Test func decreaseFontSize_UsesEffectiveDefaultWhenNoStoredOverride() throws {
        let (preferences, profile) = try makeReaderPreferences(initialFontSize: 0.0)

        preferences.decreaseFontSize()

        #expect(profile.fontSize == 90.0)
    }
}
