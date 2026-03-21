// DictionarySearchPresentationStateTests.swift
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
@testable import MaruDictionaryUICommon
@testable import MaruReaderCore
import Testing

@MainActor
struct DictionarySearchPresentationStateTests {
    @Test func loadContextDisplaySettingsUsesDictionaryDisplayPreferences() {
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

        DictionaryDisplayPreferences.contextFontSize = 1.8
        DictionaryDisplayPreferences.contextFuriganaEnabled = false

        let state = DictionarySearchPresentationState()
        state.loadContextDisplaySettings()

        #expect(state.contextFontSize == 1.8)
        #expect(!state.contextFuriganaEnabled)
    }

    @Test func furiganaEnabledUsesPreferenceUntilOverrideToggles() {
        let state = DictionarySearchPresentationState()
        state.contextFuriganaEnabled = true

        #expect(state.furiganaEnabled)

        state.toggleFurigana()
        #expect(!state.furiganaEnabled)

        state.toggleFurigana()
        #expect(state.furiganaEnabled)
    }

    @Test func editingStateSeedsAndClearsDraftText() {
        let state = DictionarySearchPresentationState()

        state.startEditing(context: "日本語")
        #expect(state.isEditingContext)
        #expect(state.editContextText == "日本語")

        state.clearEditing()
        #expect(!state.isEditingContext)
        #expect(state.editContextText.isEmpty)
    }
}
