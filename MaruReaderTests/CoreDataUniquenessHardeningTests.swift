// CoreDataUniquenessHardeningTests.swift
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
import MaruAnki
@testable import MaruReader
import Testing

struct CoreDataUniquenessHardeningTests {
    private struct AnkiSettingsSnapshot {
        let id: UUID?
        let ankiEnabled: Bool
        let defaultDeckName: String?
        let defaultModelName: String?
        let defaultProfileName: String?
    }

    private struct ConfiguredProfileSnapshot {
        let id: UUID?
        let fieldMap: AnkiFieldMap
        let configuration: ConfiguredProfileData
    }

    @Test func ankiWriterContextsUseStoreTrumpMergePolicy() async {
        let persistence = makeAnkiPersistenceController()

        #expect(
            await mergePolicyType(for: persistence.container.viewContext)
                == NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType
        )
        #expect(
            await mergePolicyType(for: persistence.newBackgroundContext())
                == NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType
        )
    }

    @Test func ankiSettingsStoreReusesSingletonSettingsRow() async throws {
        let persistence = makeAnkiPersistenceController()

        let firstContext = persistence.newBackgroundContext()
        try await firstContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: firstContext)
            settings.ankiEnabled = true
            settings.defaultDeckName = "Deck One"
            settings.defaultModelName = "Basic"
            settings.defaultProfileName = "Profile One"
            try firstContext.save()
        }

        let secondContext = persistence.newBackgroundContext()
        try await secondContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: secondContext)
            settings.defaultDeckName = "Deck Two"
            settings.defaultModelName = "Basic 2"
            settings.defaultProfileName = "Profile Two"
            try secondContext.save()
        }

        let viewContext = persistence.container.viewContext
        let count = try await viewContext.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            return try viewContext.count(for: request)
        }
        #expect(count == 1)

        let settings = try await viewContext.perform {
            let fetchedSettings = try AnkiSettingsStore.fetchSettings(in: viewContext)
            let settings = try #require(fetchedSettings)
            return AnkiSettingsSnapshot(
                id: settings.id,
                ankiEnabled: settings.ankiEnabled,
                defaultDeckName: settings.defaultDeckName,
                defaultModelName: settings.defaultModelName,
                defaultProfileName: settings.defaultProfileName
            )
        }
        #expect(settings.id == AnkiSettingsStore.settingsUUID)
        #expect(settings.ankiEnabled == true)
        #expect(settings.defaultDeckName == "Deck Two")
        #expect(settings.defaultModelName == "Basic 2")
        #expect(settings.defaultProfileName == "Profile Two")
    }

    @Test func saveConfiguredProfileUpdatesExistingTemplateRow() async throws {
        let persistence = makeAnkiPersistenceController()

        let firstFieldMap = AnkiFieldMap(map: [
            "Front": [.expression],
        ])
        let firstConfiguration = ConfiguredProfileData(
            templateID: "lapis",
            mainDefinitionDictionaryID: UUID(),
            cardType: .vocabularyCard
        )

        let firstID = try await SystemProfileManager.saveConfiguredProfile(
            templateID: "lapis",
            fieldMap: firstFieldMap,
            configuration: firstConfiguration,
            in: persistence.newBackgroundContext()
        )

        let replacementDictionaryID = UUID()
        let secondFieldMap = AnkiFieldMap(map: [
            "Front": [.singleDictionaryGlossary(dictionaryID: replacementDictionaryID)],
        ])
        let secondConfiguration = ConfiguredProfileData(
            templateID: "lapis",
            mainDefinitionDictionaryID: replacementDictionaryID,
            cardType: .audioCard
        )

        let secondID = try await SystemProfileManager.saveConfiguredProfile(
            templateID: "lapis",
            fieldMap: secondFieldMap,
            configuration: secondConfiguration,
            in: persistence.newBackgroundContext()
        )

        #expect(firstID == secondID)
        let expectedFrontValues: [TemplateValue] = [
            .singleDictionaryGlossary(dictionaryID: replacementDictionaryID),
        ]

        let viewContext = persistence.container.viewContext
        let profile = try await viewContext.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "sourceTemplateID == %@", "lapis")
            let profiles = try viewContext.fetch(request)
            #expect(profiles.count == 1)

            let profile = try #require(profiles.first)
            let decoder = JSONDecoder()
            let fieldMapData = try #require(profile.fieldMap?.data(using: .utf8))
            let configurationData = try #require(profile.templateConfiguration?.data(using: .utf8))

            return try ConfiguredProfileSnapshot(
                id: profile.id,
                fieldMap: decoder.decode(AnkiFieldMap.self, from: fieldMapData),
                configuration: decoder.decode(ConfiguredProfileData.self, from: configurationData)
            )
        }

        #expect(profile.id == firstID)
        #expect(profile.fieldMap.map["Front"] == expectedFrontValues)
        #expect(profile.configuration.mainDefinitionDictionaryID == replacementDictionaryID)
        #expect(profile.configuration.lapisCardType == LapisCardType.audioCard)
    }

    @Test func sampleContentWriterContextUsesStoreTrumpMergePolicy() async {
        let bookContext = makeBookPersistenceController().container.newBackgroundContext()
        SampleContentSeeder.configureUniquenessWriteContext(bookContext)
        #expect(
            await mergePolicyType(for: bookContext)
                == NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType
        )

        let mangaContext = makeMangaPersistenceController().container.newBackgroundContext()
        SampleContentSeeder.configureUniquenessWriteContext(mangaContext)
        #expect(
            await mergePolicyType(for: mangaContext)
                == NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType
        )
    }

    private func mergePolicyType(for context: NSManagedObjectContext) async -> NSMergePolicyType? {
        await context.perform {
            (context.mergePolicy as? NSMergePolicy)?.mergeType
        }
    }
}
