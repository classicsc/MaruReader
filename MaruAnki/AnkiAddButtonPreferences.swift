// AnkiAddButtonPreferences.swift
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

/// What a short press of the add button in a lookup does. A long press always offers both.
public enum AnkiAddButtonTapAction: String, CaseIterable, Sendable {
    case addNote
    case openEditor
}

/// Display behaviour only, so it lives in user defaults rather than the Anki configuration store.
public enum AnkiAddButtonPreferences {
    public static let tapActionKey = "anki.addButton.tapAction"

    public static var tapAction: AnkiAddButtonTapAction {
        get {
            UserDefaults.standard.string(forKey: tapActionKey).flatMap(AnkiAddButtonTapAction.init) ?? .addNote
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: tapActionKey)
        }
    }
}
