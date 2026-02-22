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
import ReadiumNavigator
import Testing

@MainActor
struct ReaderPreferencesTests {
    private func makeReaderPreferences(initialFontSize: Double) throws -> (ReaderPreferences, ReaderProfile, NSManagedObjectContext) {
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

        return (ReaderPreferences(book: book, context: context), profile, context)
    }

    @Test func increaseFontSize_UsesEffectiveDefaultWhenNoStoredOverride() throws {
        let (preferences, profile, _) = try makeReaderPreferences(initialFontSize: 0.0)

        preferences.increaseFontSize()

        #expect(profile.fontSize == 110.0)
    }

    @Test func decreaseFontSize_UsesEffectiveDefaultWhenNoStoredOverride() throws {
        let (preferences, profile, _) = try makeReaderPreferences(initialFontSize: 0.0)

        preferences.decreaseFontSize()

        #expect(profile.fontSize == 90.0)
    }

    @Test func fontFamilyOption_DefaultsToMinchoAndCanToggleGothic() throws {
        let (preferences, profile, _) = try makeReaderPreferences(initialFontSize: 100.0)

        #expect(preferences.selectedFontFamilyOption == .mincho)

        preferences.setFontFamilyOption(.gothic)
        #expect(preferences.selectedFontFamilyOption == .gothic)
        #expect(profile.fontFamily?.contains("Hiragino Kaku") == true)

        preferences.setFontFamilyOption(.mincho)
        #expect(preferences.selectedFontFamilyOption == .mincho)
        #expect(profile.fontFamily?.contains("Hiragino Mincho") == true)
    }

    @Test func appearanceMode_DefaultsAndExplicitModesUpdateProfileThemes() throws {
        let (preferences, profile, context) = try makeReaderPreferences(initialFontSize: 100.0)

        let themeManager = SystemThemeManager(context: context)
        themeManager.ensureSystemThemesExist()

        preferences.setAppearanceMode(.followSystem)
        #expect(preferences.selectedAppearanceMode == .followSystem)
        #expect(themeManager.kind(for: profile.theme) == .light)
        #expect(themeManager.kind(for: profile.darkTheme) == .dark)

        preferences.setAppearanceMode(.sepia)
        #expect(preferences.selectedAppearanceMode == .sepia)
        #expect(themeManager.kind(for: profile.theme) == .sepia)
        #expect(profile.darkTheme == nil)

        preferences.setAppearanceMode(.dark)
        #expect(preferences.selectedAppearanceMode == .dark)
        #expect(themeManager.kind(for: profile.theme) == .dark)
        #expect(profile.darkTheme == nil)
    }

    @Test func buildEPUBPreferences_UsesSelectedAppearanceModeAndSystemColorScheme() throws {
        let (preferences, _, context) = try makeReaderPreferences(initialFontSize: 100.0)

        _ = SystemThemeManager(context: context)

        preferences.setAppearanceMode(.sepia)
        var epubPreferences = preferences.buildEPUBPreferences()
        #expect(epubPreferences.theme == .sepia)

        preferences.setAppearanceMode(.followSystem)
        preferences.systemColorScheme = .dark
        epubPreferences = preferences.buildEPUBPreferences()
        #expect(epubPreferences.theme == .dark)

        preferences.systemColorScheme = .light
        epubPreferences = preferences.buildEPUBPreferences()
        #expect(epubPreferences.theme == .light)
    }

    @Test func systemThemeManager_SeedsLightDarkAndSepiaThemes() throws {
        let persistenceController = BookDataPersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext
        let themeManager = SystemThemeManager(context: context)

        themeManager.ensureSystemThemesExist()

        let request = ReaderTheme.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemTheme == YES")
        let themes = try context.fetch(request)

        #expect(themes.count == 3)
        #expect(themeManager.fetchSystemTheme(.light) != nil)
        #expect(themeManager.fetchSystemTheme(.dark) != nil)
        #expect(themeManager.fetchSystemTheme(.sepia) != nil)
    }
}
