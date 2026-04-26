// DictionaryDisplayPreferencesTests.swift
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

import Foundation
@testable import MaruReaderCore
import Testing

private actor DictionaryDisplayPreferencesTestIsolation {
    func run<T>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }
}

struct DictionaryDisplayPreferencesTests {
    private static let isolation = DictionaryDisplayPreferencesTestIsolation()

    private func withStandardDefaultsSnapshot<T>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await Self.isolation.run {
            let defaults = UserDefaults.standard
            let savedValues = DictionaryDisplayPreferences.allKeys.reduce(into: [String: Any]()) { partialResult, key in
                if let value = defaults.object(forKey: key) {
                    partialResult[key] = value
                }
            }
            DictionaryDisplayPreferences.allKeys.forEach { defaults.removeObject(forKey: $0) }

            defer {
                DictionaryDisplayPreferences.allKeys.forEach { defaults.removeObject(forKey: $0) }
                for (key, value) in savedValues {
                    defaults.set(value, forKey: key)
                }
            }

            return try await operation()
        }
    }

    @Test func defaultsMatchDictionaryDisplayDefaults() async {
        await withStandardDefaultsSnapshot {
            #expect(DictionaryDisplayPreferences.fontFamily == DictionaryDisplayPreferences.fontFamilyDefault)
            #expect(DictionaryDisplayPreferences.fontSize == DictionaryDisplayPreferences.fontSizeDefault)
            #expect(DictionaryDisplayPreferences.popupFontSize == DictionaryDisplayPreferences.popupFontSizeDefault)
            #expect(DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabled == DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabledDefault)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplay == DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplayDefault)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabled == DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabledDefault)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabled == DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabledDefault)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaEnabled == DictionaryDisplayPreferences.pitchResultsAreaEnabledDefault)
            #expect(DictionaryDisplayPreferences.contextFontSize == DictionaryDisplayPreferences.contextFontSizeDefault)
            #expect(DictionaryDisplayPreferences.contextFuriganaEnabled == DictionaryDisplayPreferences.contextFuriganaEnabledDefault)
        }
    }

    @Test func persistedValuesRoundTripThroughUserDefaults() async {
        await withStandardDefaultsSnapshot {
            DictionaryDisplayPreferences.fontFamily = "Test Font Stack"
            DictionaryDisplayPreferences.fontSize = 1.7
            DictionaryDisplayPreferences.popupFontSize = 1.4
            DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplay = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabled = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaEnabled = true
            DictionaryDisplayPreferences.contextFontSize = 1.6
            DictionaryDisplayPreferences.contextFuriganaEnabled = false

            #expect(UserDefaults.standard.string(forKey: DictionaryDisplayPreferences.fontFamilyKey) == "Test Font Stack")
            #expect(DictionaryDisplayPreferences.fontFamily == "Test Font Stack")
            #expect(DictionaryDisplayPreferences.fontSize == 1.7)
            #expect(DictionaryDisplayPreferences.popupFontSize == 1.4)
            #expect(!DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabled)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplay)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabled)
            #expect(!DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabled)
            #expect(DictionaryDisplayPreferences.pitchResultsAreaEnabled)
            #expect(DictionaryDisplayPreferences.contextFontSize == 1.6)
            #expect(!DictionaryDisplayPreferences.contextFuriganaEnabled)
        }
    }

    @Test func fontFamily_migratesLegacySystemStackFromStoredDefaults() async {
        await withStandardDefaultsSnapshot {
            UserDefaults.standard.set(DictionaryDisplayFontFamilyStacks.legacySystem, forKey: DictionaryDisplayPreferences.fontFamilyKey)

            let fontFamily = DictionaryDisplayPreferences.fontFamily

            #expect(fontFamily == DictionaryDisplayFontFamilyStacks.sansSerif)
            #expect(UserDefaults.standard.string(forKey: DictionaryDisplayPreferences.fontFamilyKey) == DictionaryDisplayFontFamilyStacks.sansSerif)
        }
    }

    @Test func fontFamily_setterNormalizesLegacySystemStack() async {
        await withStandardDefaultsSnapshot {
            DictionaryDisplayPreferences.fontFamily = DictionaryDisplayFontFamilyStacks.legacySystem

            #expect(DictionaryDisplayPreferences.fontFamily == DictionaryDisplayFontFamilyStacks.sansSerif)
            #expect(UserDefaults.standard.string(forKey: DictionaryDisplayPreferences.fontFamilyKey) == DictionaryDisplayFontFamilyStacks.sansSerif)
        }
    }

    @Test func displayStylesReflectStoredPreferences() async {
        await withStandardDefaultsSnapshot {
            DictionaryDisplayPreferences.fontFamily = "Display Font"
            DictionaryDisplayPreferences.fontSize = 1.25
            DictionaryDisplayPreferences.popupFontSize = 0.9
            DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplay = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabled = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaEnabled = true

            let styles = DictionaryDisplayPreferences.displayStyles

            #expect(styles.fontFamily == "Display Font")
            #expect(styles.contentFontSize == 1.25)
            #expect(styles.popupFontSize == 0.9)
            #expect(!styles.pitchDownstepNotationInHeaderEnabled)
            #expect(styles.pitchResultsAreaCollapsedDisplay)
            #expect(styles.pitchResultsAreaDownstepNotationEnabled)
            #expect(!styles.pitchResultsAreaDownstepPositionEnabled)
            #expect(styles.pitchResultsAreaEnabled)
        }
    }

    @Test func displayStyles_normalizeLegacySystemFontFamilyFromStorage() async {
        await withStandardDefaultsSnapshot {
            UserDefaults.standard.set(DictionaryDisplayFontFamilyStacks.legacySystem, forKey: DictionaryDisplayPreferences.fontFamilyKey)

            let styles = DictionaryDisplayPreferences.displayStyles

            #expect(styles.fontFamily == DictionaryDisplayFontFamilyStacks.sansSerif)
            #expect(UserDefaults.standard.string(forKey: DictionaryDisplayPreferences.fontFamilyKey) == DictionaryDisplayFontFamilyStacks.sansSerif)
        }
    }

    @Test func searchServiceUsesUserDefaultsBackedDisplayStyles() async throws {
        try await withStandardDefaultsSnapshot {
            DictionaryDisplayPreferences.fontFamily = "Lookup Font"
            DictionaryDisplayPreferences.fontSize = 1.33
            DictionaryDisplayPreferences.popupFontSize = 1.11
            DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplay = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabled = true
            DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabled = false
            DictionaryDisplayPreferences.pitchResultsAreaEnabled = true

            let service = DictionarySearchService(persistenceController: makeDictionaryPersistenceController())
            let request = TextLookupRequest(context: "猫")
            let session = try await service.startTextLookup(request: request)

            #expect(session != nil)
            guard let session else { return }

            let styles = await session.styles
            #expect(styles.fontFamily == "Lookup Font")
            #expect(styles.contentFontSize == 1.33)
            #expect(styles.popupFontSize == 1.11)
            #expect(!styles.pitchDownstepNotationInHeaderEnabled)
            #expect(styles.pitchResultsAreaCollapsedDisplay)
            #expect(styles.pitchResultsAreaDownstepNotationEnabled)
            #expect(!styles.pitchResultsAreaDownstepPositionEnabled)
            #expect(styles.pitchResultsAreaEnabled)
        }
    }
}
