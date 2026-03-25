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
    private func withAppearancePreferencesIsolation<T>(
        _ body: () throws -> T
    ) rethrows -> T {
        let defaults = UserDefaults.standard
        let savedValues = ReaderAppearancePreferences.allKeys.reduce(into: [String: Any]()) { partialResult, key in
            if let value = defaults.object(forKey: key) {
                partialResult[key] = value
            }
        }
        ReaderAppearancePreferences.allKeys.forEach { defaults.removeObject(forKey: $0) }

        defer {
            ReaderAppearancePreferences.allKeys.forEach { defaults.removeObject(forKey: $0) }
            for (key, value) in savedValues {
                defaults.set(value, forKey: key)
            }
        }

        return try body()
    }

    private func makeReaderPreferences() -> (ReaderPreferences, Book, NSManagedObjectContext) {
        let persistenceController = makeBookPersistenceController()
        let context = persistenceController.container.viewContext

        let book = Book(context: context)
        book.id = UUID()
        book.language = "ja"

        return (
            ReaderPreferences(
                bookID: book.objectID,
                persistenceController: persistenceController,
                context: context
            ),
            book,
            context
        )
    }

    @Test func increaseFontSize_UsesGlobalDefaultWhenNoStoredOverride() {
        withAppearancePreferencesIsolation {
            ReaderAppearancePreferences.fontScale = 0.0
            let (preferences, _, _) = makeReaderPreferences()

            preferences.increaseFontSize()

            #expect(ReaderAppearancePreferences.fontScale == 160.0)
            #expect(preferences.effectiveFontSize == 160.0)
        }
    }

    @Test func decreaseFontSize_UsesGlobalDefaultWhenNoStoredOverride() {
        withAppearancePreferencesIsolation {
            ReaderAppearancePreferences.fontScale = 0.0
            let (preferences, _, _) = makeReaderPreferences()

            preferences.decreaseFontSize()

            #expect(ReaderAppearancePreferences.fontScale == 140.0)
            #expect(preferences.effectiveFontSize == 140.0)
        }
    }

    @Test func fontSizeAdjustmentsClampToSupportedBounds() {
        withAppearancePreferencesIsolation {
            ReaderAppearancePreferences.fontScale = 200.0
            let (preferences, _, _) = makeReaderPreferences()

            preferences.increaseFontSize()
            #expect(ReaderAppearancePreferences.fontScale == 200.0)

            ReaderAppearancePreferences.fontScale = 50.0
            preferences.decreaseFontSize()
            #expect(ReaderAppearancePreferences.fontScale == 50.0)
        }
    }

    @Test func fontFamilyOption_DefaultsToMinchoAndCanToggleGothic() {
        withAppearancePreferencesIsolation {
            let (preferences, _, _) = makeReaderPreferences()

            #expect(preferences.selectedFontFamilyOption == .mincho)
            #expect(preferences.buildEPUBPreferences().fontFamily == nil)

            preferences.setFontFamilyOption(.gothic)
            #expect(preferences.selectedFontFamilyOption == .gothic)
            #expect(ReaderAppearancePreferences.fontFamilyOption == .gothic)

            let gothicPreferences = preferences.buildEPUBPreferences()
            #expect(gothicPreferences.fontFamily?.rawValue == ReaderFontFamilyOption.gothic.fontFamilyStack)

            preferences.setFontFamilyOption(.mincho)
            #expect(preferences.selectedFontFamilyOption == .mincho)

            let minchoPreferences = preferences.buildEPUBPreferences()
            #expect(minchoPreferences.fontFamily?.rawValue == ReaderFontFamilyOption.mincho.fontFamilyStack)
        }
    }

    @Test func appearanceMode_UsesStoredSelection() {
        withAppearancePreferencesIsolation {
            let (preferences, _, _) = makeReaderPreferences()

            #expect(preferences.selectedAppearanceMode == .followSystem)

            preferences.setAppearanceMode(.sepia)
            #expect(preferences.selectedAppearanceMode == .sepia)
            #expect(ReaderAppearancePreferences.appearanceMode == .sepia)

            preferences.setAppearanceMode(.dark)
            #expect(preferences.selectedAppearanceMode == .dark)
            #expect(ReaderAppearancePreferences.appearanceMode == .dark)
        }
    }

    @Test func buildEPUBPreferences_UsesSelectedAppearanceModeAndSystemColorScheme() {
        withAppearancePreferencesIsolation {
            let (preferences, _, _) = makeReaderPreferences()

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
    }

    @Test func resolvedThemeColorsMatchExpectedPalette() {
        withAppearancePreferencesIsolation {
            let (preferences, _, _) = makeReaderPreferences()

            preferences.setAppearanceMode(.light)
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentPageBackgroundColor)?.cssHex == "#FFFFFF")
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentInterfaceForegroundColor)?.cssHex == "#000000")

            preferences.setAppearanceMode(.dark)
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentPageBackgroundColor)?.cssHex == "#000000")
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentInterfaceForegroundColor)?.cssHex == "#FFFFFF")

            preferences.setAppearanceMode(.sepia)
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentPageBackgroundColor)?.cssHex == "#F9F4E9")
            #expect(ReadiumNavigator.Color(swiftUIColor: preferences.currentInterfaceBackgroundColor)?.cssHex == "#F5EDD6")
        }
    }
}
