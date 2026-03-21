// AnkiSettingsSnapshot.swift
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
import MaruReaderCore

struct AnkiSettingsSnapshot: Equatable {
    enum ConnectionDisplay: Equatable {
        case ankiMobile
        case ankiConnect(server: String?)
    }

    let isEnabled: Bool
    let hasCompleteConfiguration: Bool
    let connection: ConnectionDisplay
    let profileName: String?
    let deckName: String?
    let modelName: String?
    let fieldMappingName: String?
    let duplicateScopeDisplayName: String
    let allowsDuplicates: Bool

    init(
        isEnabled: Bool,
        hasCompleteConfiguration: Bool,
        connection: ConnectionDisplay,
        profileName: String?,
        deckName: String?,
        modelName: String?,
        fieldMappingName: String?,
        duplicateScopeDisplayName: String,
        allowsDuplicates: Bool
    ) {
        self.isEnabled = isEnabled
        self.hasCompleteConfiguration = hasCompleteConfiguration
        self.connection = connection
        self.profileName = profileName
        self.deckName = deckName
        self.modelName = modelName
        self.fieldMappingName = fieldMappingName
        self.duplicateScopeDisplayName = duplicateScopeDisplayName
        self.allowsDuplicates = allowsDuplicates
    }

    init(settings: MaruAnkiSettings, duplicateOptions: DuplicateDetectionOptions?) {
        let host = Self.trimmedString(settings.connectConfiguration?["hostname"] as? String)
        let port = settings.connectConfiguration?["port"] as? Int

        self.init(
            isEnabled: settings.ankiEnabled,
            hasCompleteConfiguration: Self.hasCompleteConfiguration(settings),
            connection: settings.isAnkiConnect ? .ankiConnect(server: Self.serverDescription(host: host, port: port)) : .ankiMobile,
            profileName: Self.trimmedString(settings.defaultProfileName),
            deckName: Self.trimmedString(settings.defaultDeckName),
            modelName: Self.trimmedString(settings.defaultModelName),
            fieldMappingName: Self.trimmedString(settings.modelConfiguration?.displayName),
            duplicateScopeDisplayName: Self.duplicateScopeDisplayName(for: duplicateOptions),
            allowsDuplicates: duplicateOptions?.scope == DuplicateNoteScope.none
        )
    }

    static func hasCompleteConfiguration(_ settings: MaruAnkiSettings) -> Bool {
        guard trimmedString(settings.defaultDeckName) != nil,
              trimmedString(settings.defaultModelName) != nil,
              settings.modelConfiguration != nil
        else {
            return false
        }

        guard settings.isAnkiConnect else {
            return true
        }

        guard trimmedString(settings.defaultProfileName) != nil,
              let configuration = settings.connectConfiguration,
              trimmedString(configuration["hostname"] as? String) != nil,
              let port = configuration["port"] as? Int,
              port > 0
        else {
            return false
        }

        return true
    }

    private static func duplicateScopeDisplayName(for options: DuplicateDetectionOptions?) -> String {
        guard let options else {
            return String(localized: "Not Configured")
        }

        switch options.scope {
        case .none:
            return String(localized: "Allow Duplicates")
        case .deck:
            if let deckName = options.deckName {
                return AppLocalization.checkInDeck(deckName)
            }
            return String(localized: "Check in Target Deck")
        case .collection:
            return String(localized: "Check Entire Collection")
        @unknown default:
            return String(localized: "Unknown")
        }
    }

    private static func serverDescription(host: String?, port: Int?) -> String? {
        guard let host, let port else {
            return nil
        }
        return "\(host):\(port)"
    }

    private static func trimmedString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
