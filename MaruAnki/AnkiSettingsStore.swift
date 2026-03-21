// AnkiSettingsStore.swift
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

public enum AnkiSettingsStore {
    public static let settingsUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    public static func fetchSettings(in context: NSManagedObjectContext) throws -> MaruAnkiSettings? {
        try context.fetch(settingsRequest).first
    }

    public static func fetchOrCreateSettings(in context: NSManagedObjectContext) throws -> MaruAnkiSettings {
        if let existing = try fetchSettings(in: context) {
            return existing
        }

        let settings = MaruAnkiSettings(context: context)
        settings.id = settingsUUID
        settings.ankiEnabled = false
        settings.defaultDeckName = ""
        settings.defaultModelName = ""
        settings.defaultProfileName = ""
        settings.duplicateNoteSettings = defaultDuplicateSettingsJSON
        settings.isAnkiConnect = false
        return settings
    }

    private static var settingsRequest: NSFetchRequest<MaruAnkiSettings> {
        let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
        request.predicate = NSPredicate(format: "id == %@", settingsUUID as CVarArg)
        request.fetchLimit = 1
        return request
    }

    private static var defaultDuplicateSettingsJSON: String {
        let options = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )
        let data = try? JSONEncoder().encode(options)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
