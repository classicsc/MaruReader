// ReaderAppearancePreferencesTests.swift
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
@testable import MaruReader
import Testing

@MainActor
struct ReaderAppearancePreferencesTests {
    @Test func defaultsMatchExpectedValues() {
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

        #expect(ReaderAppearancePreferences.fontScale == ReaderAppearancePreferences.fontScaleDefault)
        #expect(ReaderAppearancePreferences.fontFamilyOption == ReaderAppearancePreferences.fontFamilyOptionDefault)
        #expect(ReaderAppearancePreferences.appearanceMode == ReaderAppearancePreferences.appearanceModeDefault)
    }

    @Test func persistedValuesRoundTripThroughUserDefaults() {
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

        ReaderAppearancePreferences.fontScale = 130.0
        ReaderAppearancePreferences.fontFamilyOption = .gothic
        ReaderAppearancePreferences.appearanceMode = .sepia

        #expect(UserDefaults.standard.object(forKey: ReaderAppearancePreferences.fontScaleKey) as? Double == 130.0)
        #expect(UserDefaults.standard.string(forKey: ReaderAppearancePreferences.fontFamilyOptionKey) == ReaderFontFamilyOption.gothic.rawValue)
        #expect(UserDefaults.standard.string(forKey: ReaderAppearancePreferences.appearanceModeKey) == ReaderAppearanceMode.sepia.rawValue)
        #expect(ReaderAppearancePreferences.fontScale == 130.0)
        #expect(ReaderAppearancePreferences.fontFamilyOption == .gothic)
        #expect(ReaderAppearancePreferences.appearanceMode == .sepia)
    }
}
