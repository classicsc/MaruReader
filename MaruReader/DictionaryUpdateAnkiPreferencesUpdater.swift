// DictionaryUpdateAnkiPreferencesUpdater.swift
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
import MaruReaderCore

actor DictionaryUpdateAnkiPreferencesUpdater: DictionaryUpdateAnkiPreferencesUpdating {
    private let persistence: AnkiPersistenceController

    init(persistence: AnkiPersistenceController = .shared) {
        self.persistence = persistence
    }

    func replaceDictionaryIDs(oldID: UUID, newID: UUID) async {
        let context = persistence.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            let profiles = (try? context.fetch(request)) ?? []
            guard !profiles.isEmpty else { return }

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            var hasChanges = false

            for profile in profiles {
                if let fieldMapString = profile.fieldMap,
                   let data = fieldMapString.data(using: .utf8),
                   let fieldMap = try? decoder.decode(AnkiFieldMap.self, from: data),
                   let updatedMap = Self.updateFieldMap(fieldMap, oldID: oldID, newID: newID),
                   let updatedData = try? encoder.encode(updatedMap),
                   let updatedString = String(data: updatedData, encoding: .utf8)
                {
                    profile.fieldMap = updatedString
                    hasChanges = true
                }

                if let configString = profile.templateConfiguration,
                   let data = configString.data(using: .utf8),
                   let config = try? decoder.decode(ConfiguredProfileData.self, from: data),
                   config.mainDefinitionDictionaryID == oldID
                {
                    let updatedConfig = ConfiguredProfileData(
                        templateID: config.templateID,
                        mainDefinitionDictionaryID: newID,
                        cardType: config.lapisCardType
                    )
                    if let updatedData = try? encoder.encode(updatedConfig),
                       let updatedString = String(data: updatedData, encoding: .utf8)
                    {
                        profile.templateConfiguration = updatedString
                        hasChanges = true
                    }
                }
            }

            if hasChanges {
                try? context.save()
            }
        }
    }

    private nonisolated static func updateFieldMap(_ fieldMap: AnkiFieldMap, oldID: UUID, newID: UUID) -> AnkiFieldMap? {
        var updatedMap: [String: [TemplateValue]] = [:]
        var hasChanges = false

        for (key, values) in fieldMap.map {
            let updatedValues = values.map { value in
                replaceDictionaryValue(value, oldID: oldID, newID: newID)
            }
            if updatedValues != values {
                hasChanges = true
            }
            updatedMap[key] = updatedValues
        }

        guard hasChanges else { return nil }
        return AnkiFieldMap(map: updatedMap)
    }

    private nonisolated static func replaceDictionaryValue(_ value: TemplateValue, oldID: UUID, newID: UUID) -> TemplateValue {
        switch value {
        case let .singleDictionaryGlossary(dictionaryID) where dictionaryID == oldID:
            .singleDictionaryGlossary(dictionaryID: newID)
        case let .singlePitchAccentDictionary(dictionaryID) where dictionaryID == oldID:
            .singlePitchAccentDictionary(dictionaryID: newID)
        case let .singleFrequencyDictionary(dictionaryID) where dictionaryID == oldID:
            .singleFrequencyDictionary(dictionaryID: newID)
        case let .frequencyRankSortField(dictionaryID) where dictionaryID == oldID:
            .frequencyRankSortField(dictionaryID: newID)
        case let .frequencyOccurrenceSortField(dictionaryID) where dictionaryID == oldID:
            .frequencyOccurrenceSortField(dictionaryID: newID)
        default:
            value
        }
    }
}
