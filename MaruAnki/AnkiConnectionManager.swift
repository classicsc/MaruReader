// AnkiConnectionManager.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import os.log

public enum AnkiConnectionManagerError: Error {
    case notReady
    case ankiDisabled
    case providerUnavailable
    case missingRequiredSettings
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

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AnkiConnectionManager")

    public init(persistence: AnkiPersistenceController = .shared) async {
        self.persistence = persistence
        await SystemProfileManager.ensureSystemProfilesExist(in: persistence.newBackgroundContext())
        await reload()
        startObservingSaves()
    }

    // MARK: - Temporary Connection Methods

    /// Tests connection to Anki-Connect with temporary settings (not persisted).
    /// Throws on failure.
    public func testConnection(host: String, port: Int, apiKey: String?) async throws {
        _ = try await AnkiConnectProvider(host: host, port: port, apiKey: apiKey)
    }

    /// Fetches profiles using temporary connection settings.
    public func getProfiles(host: String, port: Int, apiKey: String?) async throws -> [AnkiProfileMeta] {
        let provider = try await AnkiConnectProvider(host: host, port: port, apiKey: apiKey)
        let response = await provider.getAnkiProfiles()
        switch response {
        case let .success(profiles):
            return profiles
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
    }

    /// Fetches decks for a profile using temporary connection settings.
    public func getDecks(host: String, port: Int, apiKey: String?, forProfile profileName: String) async throws -> [AnkiDeckMeta] {
        let provider = try await AnkiConnectProvider(host: host, port: port, apiKey: apiKey)
        let response = await provider.getAnkiDecks(forProfile: profileName)
        switch response {
        case let .success(decks):
            return decks
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
    }

    /// Fetches models for a profile using temporary connection settings.
    public func getModels(host: String, port: Int, apiKey: String?, forProfile profileName: String) async throws -> [AnkiModelMeta] {
        let provider = try await AnkiConnectProvider(host: host, port: port, apiKey: apiKey)
        let response = await provider.getAnkiModels(forProfile: profileName)
        switch response {
        case let .success(models):
            return models
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
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
        let result = try await provider.addNote(
            fields: fields,
            profileName: profileName ?? "",
            deckName: deckName,
            modelName: modelName,
            duplicateOptions: duplicateOptions
        )

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
        let result = try await provider.addNote(
            fields: resolvedValues,
            profileName: targetProfile,
            deckName: targetDeck,
            modelName: targetModel,
            duplicateOptions: duplicateOptions
        )

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
                host: config.apiHost,
                port: config.apiPort,
                apiKey: config.apiKey
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
        let apiHost: String?
        let apiPort: Int?
        let apiKey: String?
        let isAnkiConnect: Bool
    }

    private func fetchSettings() async throws -> AnkiConfiguration {
        let context = persistence.container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            let settings = try context.fetch(request).first

            guard let settings else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard settings.ankiEnabled else {
                throw AnkiConnectionManagerError.ankiDisabled
            }

            let connectConfig = settings.isAnkiConnect ? settings.connectConfiguration : nil

            return AnkiConfiguration(
                duplicateNoteSettingsJSON: settings.duplicateNoteSettings,
                fieldMapJSON: settings.modelConfiguration?.fieldMap,
                deckName: settings.defaultDeckName,
                modelName: settings.defaultModelName,
                profileName: settings.defaultProfileName,
                apiHost: connectConfig?["hostname"] as? String,
                apiPort: connectConfig?["port"] as? Int,
                apiKey: connectConfig?["apiKey"] as? String,
                isAnkiConnect: settings.isAnkiConnect
            )
        }
    }

    private func makeProvider(isAnkiConnect: Bool, host: String?, port: Int?, apiKey: String?) async -> (any AnkiProvider)? {
        if isAnkiConnect {
            guard let host, port != nil, (port ?? 0) > 0, !host.isEmpty else {
                return nil
            }

            do {
                let provider = try await AnkiConnectProvider(
                    host: host,
                    port: port!,
                    apiKey: apiKey
                )
                return provider
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
