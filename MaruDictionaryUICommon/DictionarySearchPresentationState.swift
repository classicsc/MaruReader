// DictionarySearchPresentationState.swift
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

import MaruReaderCore
import Observation

@MainActor
@Observable
final class DictionarySearchPresentationState {
    var contextFontSize: Double = DictionaryDisplayDefaults.defaultContextFontSize
    var contextFuriganaEnabled: Bool = DictionaryDisplayDefaults.defaultContextFuriganaEnabled
    var furiganaOverride: Bool?
    var isEditingContext: Bool = false
    var editContextText: String = ""

    @ObservationIgnored
    private var cachedFuriganaSegments: [FuriganaSegment] = []
    @ObservationIgnored
    private var cachedFuriganaContext: String?

    var furiganaEnabled: Bool {
        furiganaOverride ?? contextFuriganaEnabled
    }

    func loadContextDisplaySettings() {
        contextFontSize = DictionaryDisplayPreferences.contextFontSize
        contextFuriganaEnabled = DictionaryDisplayPreferences.contextFuriganaEnabled
    }

    func toggleFurigana() {
        if furiganaOverride == nil {
            furiganaOverride = !contextFuriganaEnabled
        } else {
            furiganaOverride = !furiganaEnabled
        }
        cachedFuriganaContext = nil
    }

    func furiganaSegments(for context: String) -> [FuriganaSegment] {
        if cachedFuriganaContext == context {
            return cachedFuriganaSegments
        }

        let segments = FuriganaGenerator.generateSegments(from: context)
        cachedFuriganaContext = context
        cachedFuriganaSegments = segments
        return segments
    }

    func startEditing(context: String) {
        editContextText = context
        isEditingContext = true
    }

    func clearEditing() {
        isEditingContext = false
        editContextText = ""
    }
}
