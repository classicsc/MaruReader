// DictionaryUpdateAnkiPreferencesUpdaterTests.swift
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
@testable import MaruReader
import Testing

struct DictionaryUpdateAnkiPreferencesUpdaterTests {
    @Test @MainActor func updaterReplacesDictionaryIDsInFieldMapsAndTemplates() async throws {
        let persistenceController = makeAnkiPersistenceController()
        let updater = DictionaryUpdateAnkiPreferencesUpdater(persistence: persistenceController)

        let oldID = UUID()
        let newID = UUID()

        let fieldMap = AnkiFieldMap(map: [
            "Front": [.singleDictionaryGlossary(dictionaryID: oldID)],
            "Back": [
                .singleFrequencyDictionary(dictionaryID: oldID),
                .frequencyRankSortField(dictionaryID: oldID),
            ],
        ])
        let fieldMapData = try JSONEncoder().encode(fieldMap)
        let fieldMapString = try #require(String(data: fieldMapData, encoding: .utf8))

        let config = ConfiguredProfileData(
            templateID: "lapis",
            mainDefinitionDictionaryID: oldID,
            cardType: .clickCard
        )
        let configData = try JSONEncoder().encode(config)
        let configString = try #require(String(data: configData, encoding: .utf8))

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            let profile = MaruModelSettings(context: context)
            profile.id = UUID()
            profile.displayName = "Test Profile"
            profile.fieldMap = fieldMapString
            profile.templateConfiguration = configString
            try context.save()
        }

        await updater.replaceDictionaryIDs(oldID: oldID, newID: newID)

        let viewContext = persistenceController.container.viewContext
        let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
        request.fetchLimit = 1
        let profile = try viewContext.fetch(request).first
        #expect(profile != nil)

        let decoder = JSONDecoder()
        if let updatedFieldMapString = profile?.fieldMap,
           let data = updatedFieldMapString.data(using: .utf8),
           let updatedFieldMap = try? decoder.decode(AnkiFieldMap.self, from: data)
        {
            let frontValues = updatedFieldMap.map["Front"] ?? []
            let backValues = updatedFieldMap.map["Back"] ?? []
            #expect(frontValues.contains(.singleDictionaryGlossary(dictionaryID: newID)))
            #expect(backValues.contains(.singleFrequencyDictionary(dictionaryID: newID)))
            #expect(backValues.contains(.frequencyRankSortField(dictionaryID: newID)))
        } else {
            #expect(false, "Field map should be updated and decodable")
        }

        if let updatedConfigString = profile?.templateConfiguration,
           let data = updatedConfigString.data(using: .utf8),
           let updatedConfig = try? decoder.decode(ConfiguredProfileData.self, from: data)
        {
            #expect(updatedConfig.mainDefinitionDictionaryID == newID)
        } else {
            #expect(false, "Template configuration should be updated and decodable")
        }
    }
}
