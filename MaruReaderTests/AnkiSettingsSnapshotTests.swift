// AnkiSettingsSnapshotTests.swift
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
import MaruAnki
@testable import MaruReader
import Testing

struct AnkiSettingsSnapshotTests {
    @Test func placeholderSingletonRowIsNotACompleteConfiguration() async throws {
        let persistence = makeAnkiPersistenceController()
        let viewContext = persistence.container.viewContext

        let snapshot = try await viewContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: viewContext)
            return AnkiSettingsSnapshot(settings: settings, duplicateOptions: nil)
        }

        #expect(snapshot.hasCompleteConfiguration == false)
        #expect(snapshot.isEnabled == false)
    }

    @Test func validAnkiMobileConfigurationIsComplete() async throws {
        let persistence = makeAnkiPersistenceController()
        let viewContext = persistence.container.viewContext

        let snapshot = try await viewContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: viewContext)
            let fieldMapping = MaruModelSettings(context: viewContext)
            fieldMapping.id = UUID()
            fieldMapping.displayName = "Basic Mapping"

            settings.ankiEnabled = true
            settings.isAnkiConnect = false
            settings.defaultDeckName = "Default"
            settings.defaultModelName = "Basic"
            settings.defaultProfileName = ""
            settings.modelConfiguration = fieldMapping

            return AnkiSettingsSnapshot(settings: settings, duplicateOptions: nil)
        }

        #expect(snapshot.hasCompleteConfiguration)
    }

    @Test func validAnkiConnectConfigurationIsComplete() async throws {
        let persistence = makeAnkiPersistenceController()
        let viewContext = persistence.container.viewContext

        let snapshot = try await viewContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: viewContext)
            let fieldMapping = MaruModelSettings(context: viewContext)
            fieldMapping.id = UUID()
            fieldMapping.displayName = "Basic Mapping"

            settings.ankiEnabled = true
            settings.isAnkiConnect = true
            settings.defaultProfileName = "User 1"
            settings.defaultDeckName = "Default"
            settings.defaultModelName = "Basic"
            settings.modelConfiguration = fieldMapping
            settings.connectConfiguration = [
                "hostname": "localhost",
                "port": 8765,
            ]

            return AnkiSettingsSnapshot(settings: settings, duplicateOptions: nil)
        }

        #expect(snapshot.hasCompleteConfiguration)
        #expect(snapshot.connection == .ankiConnect(server: "https://localhost:8765"))
    }

    @Test func validAnkiConnectHTTPConfigurationIsComplete() async throws {
        let persistence = makeAnkiPersistenceController()
        let viewContext = persistence.container.viewContext

        try await viewContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: viewContext)
            let fieldMapping = MaruModelSettings(context: viewContext)
            fieldMapping.id = UUID()
            fieldMapping.displayName = "Basic Mapping"
            fieldMapping.fieldMap = "{}"

            settings.ankiEnabled = true
            settings.isAnkiConnect = true
            settings.defaultProfileName = "User 1"
            settings.defaultDeckName = "Default"
            settings.defaultModelName = "Basic"
            settings.modelConfiguration = fieldMapping
            settings.connectConfiguration = [
                "hostname": "anki.local",
                "port": 8765,
                "scheme": "http",
            ]

            try viewContext.save()
        }

        let backgroundContext = persistence.newBackgroundContext()
        let (persistedScheme, snapshot) = try await backgroundContext.perform {
            let settings = try #require(try AnkiSettingsStore.fetchSettings(in: backgroundContext))
            let persistedScheme = settings.connectConfiguration?["scheme"] as? String
            let snapshot = AnkiSettingsSnapshot(settings: settings, duplicateOptions: nil)
            return (persistedScheme, snapshot)
        }

        #expect(persistedScheme == "http")
        #expect(snapshot.hasCompleteConfiguration)
        #expect(snapshot.connection == .ankiConnect(server: "http://anki.local:8765"))
    }

    @Test func incompleteAnkiConnectConfigurationIsNotComplete() async throws {
        let persistence = makeAnkiPersistenceController()
        let viewContext = persistence.container.viewContext

        let snapshot = try await viewContext.perform {
            let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: viewContext)
            let fieldMapping = MaruModelSettings(context: viewContext)
            fieldMapping.id = UUID()
            fieldMapping.displayName = "Basic Mapping"

            settings.ankiEnabled = true
            settings.isAnkiConnect = true
            settings.defaultProfileName = ""
            settings.defaultDeckName = "Default"
            settings.defaultModelName = "Basic"
            settings.modelConfiguration = fieldMapping
            settings.connectConfiguration = [
                "hostname": "localhost",
                "port": 8765,
            ]

            return AnkiSettingsSnapshot(settings: settings, duplicateOptions: nil)
        }

        #expect(snapshot.hasCompleteConfiguration == false)
    }

    @Test func enablingFromEmptyStateShowsConfigurationFlow() {
        let action = AnkiSettingsToggleAction.resolve(
            currentSnapshot: AnkiSettingsSnapshot(
                isEnabled: false,
                hasCompleteConfiguration: false,
                connection: .ankiMobile,
                profileName: nil,
                deckName: nil,
                modelName: nil,
                fieldMappingName: nil,
                duplicateScopeDisplayName: "Not Configured",
                allowsDuplicates: false
            ),
            newValue: true
        )

        #expect(action == .showConfigurationFlow)
    }

    @Test func enablingWithCompleteConfigurationPersistsEnabledState() {
        let action = AnkiSettingsToggleAction.resolve(
            currentSnapshot: AnkiSettingsSnapshot(
                isEnabled: false,
                hasCompleteConfiguration: true,
                connection: .ankiMobile,
                profileName: nil,
                deckName: "Default",
                modelName: "Basic",
                fieldMappingName: "Basic Mapping",
                duplicateScopeDisplayName: "Check in Target Deck",
                allowsDuplicates: false
            ),
            newValue: true
        )

        #expect(action == .persistEnabled(true))
    }
}
