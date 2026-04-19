// AnkiConnectionManager.swift
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
import MaruReaderCore
import os

public enum AnkiConnectionManagerError: Error {
    case notReady
    case ankiDisabled
    case providerUnavailable
    case missingRequiredSettings
    case duplicateNote
}

/// Result of creating a note via the connection manager.
public struct NoteCreationResult: Sendable {
    /// The Anki note ID, if returned by the API.
    public let ankiNoteID: Int64?
    /// Whether the note should be marked as pending sync locally.
    public let pendingSync: Bool
    /// The profile name the note was added to.
    public let profileName: String
    /// The deck name the note was added to.
    public let deckName: String
    /// The model name used for the note.
    public let modelName: String
    /// The resolved fields stored for pending sync.
    public let resolvedFields: [String: String]
}

/// Converts resolved `TemplateValue`s into note fields based on persisted Anki settings.
public actor AnkiConnectionManager {
    public private(set) var isReady: Bool = false
    public private(set) var error: Error?

    private let persistence: AnkiPersistenceController

    private var provider: (any AnkiProvider)?
    private var duplicateOptions: DuplicateDetectionOptions?
    private var fieldMap: AnkiFieldMap?
    private var isAnkiConnect: Bool = false

    public private(set) var profileName: String?
    public private(set) var deckName: String?
    public private(set) var modelName: String?

    private var observationTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Error>?

    private let logger = Logger.maru(category: "AnkiConnectionManager")

    public init(persistence: AnkiPersistenceController = .shared) async {
        self.persistence = persistence
        await SystemProfileManager.ensureSystemProfilesExist(in: persistence.newBackgroundContext())
        await reload()
        startObservingSaves()
    }

    /// Add a note using the provided template resolver.
    /// - Returns: The result containing Anki note ID and configuration used.
    @discardableResult
    public func addNote(resolver: any TemplateValueResolver) async throws -> NoteCreationResult {
        guard isReady,
              let provider,
              let duplicateOptions,
              let fieldMap,
              let deckName,
              let modelName
        else {
            throw AnkiConnectionManagerError.notReady
        }

        var fields: [String: [TemplateResolvedValue]] = [:]
        for (fieldName, templateValues) in fieldMap.map {
            for templateValue in templateValues {
                let resolvedValue = await resolver.resolve(templateValue)
                fields[fieldName, default: []].append(resolvedValue)
            }
        }

        let resolvedFields = AnkiFieldValueFormatter.buildFieldValues(from: fields)
        let result: AddNoteResult
        do {
            result = try await provider.addNote(
                fields: fields,
                profileName: profileName ?? "",
                deckName: deckName,
                modelName: modelName,
                duplicateOptions: duplicateOptions
            )
        } catch let error as AnkiConnectError where error == .duplicateNote {
            throw AnkiConnectionManagerError.duplicateNote
        }

        return NoteCreationResult(
            ankiNoteID: result.ankiNoteID,
            pendingSync: result.pendingSync,
            profileName: profileName ?? "",
            deckName: deckName,
            modelName: modelName,
            resolvedFields: resolvedFields
        )
    }

    /// Add a note using pre-resolved fields (e.g., from pending sync).
    @discardableResult
    public func addNote(
        resolvedFields: [String: String],
        profileName: String?,
        deckName: String?,
        modelName: String?
    ) async throws -> NoteCreationResult {
        guard isReady,
              let provider,
              let duplicateOptions
        else {
            throw AnkiConnectionManagerError.notReady
        }

        let resolvedProfile = profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackProfile = self.profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetProfile = (resolvedProfile?.isEmpty == false ? resolvedProfile : fallbackProfile) ?? ""

        if isAnkiConnect, targetProfile.isEmpty {
            throw AnkiConnectionManagerError.missingRequiredSettings
        }

        let targetDeck = deckName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? self.deckName
        let targetModel = modelName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? self.modelName

        guard let targetDeck, !targetDeck.isEmpty,
              let targetModel, !targetModel.isEmpty
        else {
            throw AnkiConnectionManagerError.missingRequiredSettings
        }

        let resolvedValues = resolvedFields.mapValues { [TemplateResolvedValue.text($0)] }
        let result: AddNoteResult
        do {
            result = try await provider.addNote(
                fields: resolvedValues,
                profileName: targetProfile,
                deckName: targetDeck,
                modelName: targetModel,
                duplicateOptions: duplicateOptions
            )
        } catch let error as AnkiConnectError where error == .duplicateNote {
            throw AnkiConnectionManagerError.duplicateNote
        }

        return NoteCreationResult(
            ankiNoteID: result.ankiNoteID,
            pendingSync: result.pendingSync,
            profileName: targetProfile,
            deckName: targetDeck,
            modelName: targetModel,
            resolvedFields: resolvedFields
        )
    }

    private func startObservingSaves() {
        observationTask?.cancel()

        observationTask = Task {
            let notificationSequence = NotificationCenter.default.notifications(
                named: NSNotification.Name.NSManagedObjectContextDidSave
            )

            for await notification in notificationSequence {
                if containsAnkiChanges(notification) {
                    logger.debug("Anki changes detected, scheduling reload")
                    scheduleReload()
                }
            }
        }
    }

    /// Check if a Core Data save notification contains Anki entity changes that should trigger a reload
    private func containsAnkiChanges(_ notification: Notification) -> Bool {
        guard let userInfo = notification.userInfo else { return false }

        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

        let allChangedObjects = inserted.union(updated).union(deleted)

        return allChangedObjects.contains { object in
            object.entity.name == "MaruAnkiSettings" || object.entity.name == "MaruModelSettings"
        }
    }

    /// Schedule a provider reload with debouncing to handle rapid changes
    private func scheduleReload() {
        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task {
            try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
            try Task.checkCancellation()
            await self.reload()
        }
    }

    private nonisolated static func changedObjects(from notification: Notification) -> Set<NSManagedObject> {
        guard let userInfo = notification.userInfo else { return [] }

        var objects: Set<NSManagedObject> = []
        for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
            if let set = userInfo[key] as? Set<NSManagedObject> {
                objects.formUnion(set)
            }
        }
        return objects
    }

    private func reload() async {
        isReady = false
        provider = nil
        duplicateOptions = nil
        fieldMap = nil
        profileName = nil
        deckName = nil
        modelName = nil
        isAnkiConnect = false

        do {
            let config = try await fetchSettings()

            guard let duplicateNoteSettingsJSON = config.duplicateNoteSettingsJSON else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            let duplicateOptions = try JSONDecoder().decode(
                DuplicateDetectionOptions.self,
                from: Data(duplicateNoteSettingsJSON.utf8)
            )

            guard let fieldMapJSON = config.fieldMapJSON else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            let fieldMap = try JSONDecoder().decode(
                AnkiFieldMap.self,
                from: Data(fieldMapJSON.utf8)
            )

            guard let deckName = config.deckName,
                  !deckName.isEmpty,
                  let modelName = config.modelName,
                  !modelName.isEmpty
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            let trimmedProfileName = config.profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if config.isAnkiConnect, trimmedProfileName.isEmpty {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard let provider = await makeProvider(
                isAnkiConnect: config.isAnkiConnect,
                connectionInfo: config.connectionInfo
            ) else {
                throw AnkiConnectionManagerError.providerUnavailable
            }

            self.provider = provider
            self.duplicateOptions = duplicateOptions
            self.fieldMap = fieldMap
            self.profileName = trimmedProfileName
            self.deckName = deckName
            self.modelName = modelName
            self.isAnkiConnect = config.isAnkiConnect

            isReady = true
        } catch {
            isReady = false
            self.error = error
            logger.info("Failed to reload AnkiConnectionManager: \(error.localizedDescription)")
        }
    }

    private struct AnkiConfiguration {
        let duplicateNoteSettingsJSON: String?
        let fieldMapJSON: String?
        let deckName: String?
        let modelName: String?
        let profileName: String?
        let connectionInfo: AnkiConnectConnectionInfo?
        let isAnkiConnect: Bool
    }

    private func fetchSettings() async throws -> AnkiConfiguration {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            guard let settings = try AnkiSettingsStore.fetchSettings(in: context) else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard settings.ankiEnabled else {
                throw AnkiConnectionManagerError.ankiDisabled
            }

            let connectConfig = settings.isAnkiConnect ? settings.connectConfiguration : nil
            let connectionInfo: AnkiConnectConnectionInfo? = if let host = connectConfig?["hostname"] as? String,
                                                                let port = connectConfig?["port"] as? Int,
                                                                let scheme = AnkiConnectScheme.fromPersistedValue(
                                                                    connectConfig?["scheme"] as? String
                                                                )
            {
                AnkiConnectConnectionInfo(
                    host: host,
                    port: port,
                    scheme: scheme,
                    apiKey: connectConfig?["apiKey"] as? String
                )
            } else {
                nil
            }

            return AnkiConfiguration(
                duplicateNoteSettingsJSON: settings.duplicateNoteSettings,
                fieldMapJSON: settings.modelConfiguration?.fieldMap,
                deckName: settings.defaultDeckName,
                modelName: settings.defaultModelName,
                profileName: settings.defaultProfileName,
                connectionInfo: connectionInfo,
                isAnkiConnect: settings.isAnkiConnect
            )
        }
    }

    private func makeProvider(
        isAnkiConnect: Bool,
        connectionInfo: AnkiConnectConnectionInfo?
    ) async -> (any AnkiProvider)? {
        if isAnkiConnect {
            guard let connectionInfo,
                  !connectionInfo.host.isEmpty,
                  connectionInfo.port > 0
            else {
                return nil
            }

            do {
                return try await AnkiConnectProvider(
                    host: connectionInfo.host,
                    port: connectionInfo.port,
                    scheme: connectionInfo.scheme,
                    apiKey: connectionInfo.apiKey
                )
            } catch {
                self.error = error
                return UnimplementedAnkiProvider()
            }
        }

        let opener = await AnkiMobileURLOpenerStore.shared.get()
        let returnURL = await AnkiMobileURLOpenerStore.shared.getReturnURL()
        return AnkiMobileProvider(urlOpener: opener, returnURL: returnURL)
    }
}

private struct UnimplementedAnkiProvider: AnkiProvider {
    func addNote(
        fields _: [String: [TemplateResolvedValue]],
        profileName _: String,
        deckName _: String,
        modelName _: String,
        duplicateOptions _: DuplicateDetectionOptions
    ) async throws -> AddNoteResult {
        throw AnkiConnectionManagerError.providerUnavailable
    }

    func getAnkiProfiles() async -> AnkiProfileListingResponse {
        .apiCapabilityMissing
    }

    func getAnkiDecks(forProfile _: String) async -> AnkiDeckListingResponse {
        .apiCapabilityMissing
    }

    func getAnkiModels(forProfile _: String) async -> AnkiModelListingResponse {
        .apiCapabilityMissing
    }
}
