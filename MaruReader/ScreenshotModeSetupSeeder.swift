// ScreenshotModeSetupSeeder.swift
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
import MaruAnki
import MaruDictionaryUICommon
import MaruReaderCore
import os

enum ScreenshotModeSetupError: LocalizedError {
    case missingDictionary
    case missingConfiguredProfile

    var errorDescription: String? {
        switch self {
        case .missingDictionary:
            "No dictionary was available for screenshot-mode Anki setup."
        case .missingConfiguredProfile:
            "Unable to load the configured Lapis field mapping for screenshot mode."
        }
    }
}

actor ScreenshotModeSetupSeeder {
    private let ankiPersistence: AnkiPersistenceController
    private let dictionaryPersistence: DictionaryPersistenceController
    private let logger = Logger.maru(category: "ScreenshotModeSetupSeeder")

    init(
        ankiPersistence: AnkiPersistenceController = .shared,
        dictionaryPersistence: DictionaryPersistenceController = .shared
    ) {
        self.ankiPersistence = ankiPersistence
        self.dictionaryPersistence = dictionaryPersistence
    }

    func seedAnkiLapisConfiguration() async throws {
        let dictionaryID = try await firstAvailableDictionaryID()
        let profileID = try await saveConfiguredLapisProfile(dictionaryID: dictionaryID)
        try await saveAnkiSettings(profileID: profileID)
        logger.debug("Configured screenshot-mode AnkiMobile settings with Lapis field mapping")
    }

    private func firstAvailableDictionaryID() async throws -> UUID {
        let context = dictionaryPersistence.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<Dictionary>(entityName: "Dictionary")
            request.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO AND termCount > 0")
            request.sortDescriptors = [
                NSSortDescriptor(key: "termDisplayPriority", ascending: true),
                NSSortDescriptor(key: "title", ascending: true),
            ]
            request.fetchLimit = 1

            guard let dictionary = try context.fetch(request).first,
                  let dictionaryID = dictionary.id
            else {
                throw ScreenshotModeSetupError.missingDictionary
            }

            return dictionaryID
        }
    }

    private func saveConfiguredLapisProfile(dictionaryID: UUID) async throws -> UUID {
        let context = ankiPersistence.newBackgroundContext()
        let template = ConfigurableProfileTemplates.lapis
        let configuration = ConfiguredProfileData(
            templateID: template.id,
            mainDefinitionDictionaryID: dictionaryID,
            cardType: .vocabularyCard
        )

        let fieldMap = template.buildFieldMap(
            mainDefinitionDictionaryID: dictionaryID,
            cardType: .vocabularyCard
        )

        return try await SystemProfileManager.saveConfiguredProfile(
            templateID: template.id,
            fieldMap: fieldMap,
            configuration: configuration,
            in: context
        )
    }

    private func saveAnkiSettings(profileID: UUID) async throws {
        let context = ankiPersistence.newBackgroundContext()
        try await context.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: context)
            let profileRequest = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            profileRequest.predicate = NSPredicate(format: "id == %@", profileID as CVarArg)
            profileRequest.fetchLimit = 1

            guard let profile = try context.fetch(profileRequest).first else {
                throw ScreenshotModeSetupError.missingConfiguredProfile
            }

            settings.ankiEnabled = true
            settings.isAnkiConnect = false
            settings.defaultProfileName = "User 1"
            settings.defaultDeckName = "Japanese"
            settings.defaultModelName = "Lapis"
            settings.modelConfiguration = profile
            settings.duplicateNoteSettings = try Self.duplicateNoteSettingsJSON()

            try context.save()
        }
    }

    private static func duplicateNoteSettingsJSON() throws -> String {
        let options = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )
        let data = try JSONEncoder().encode(options)
        return String(decoding: data, as: UTF8.self)
    }
}
