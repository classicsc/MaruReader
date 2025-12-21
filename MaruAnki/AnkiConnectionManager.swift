//
//  AnkiConnectionManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/18/25.
//

import CoreData
import Foundation
import os.log

public enum AnkiConnectionManagerError: Error {
    case notReady
    case providerUnavailable
    case missingRequiredSettings
}

/// Converts resolved `TemplateValue`s into note fields based on persisted Anki settings.
public actor AnkiConnectionManager {
    public private(set) var isReady: Bool = false
    public private(set) var error: Error?

    private let persistence: AnkiPersistenceController

    private var provider: (any AnkiProvider)?
    private var duplicateOptions: DuplicateDetectionOptions?
    private var fieldMap: AnkiFieldMap?

    private var profileName: String?
    private var deckName: String?
    private var modelName: String?

    private var observationTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Error>?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AnkiConnectionManager")

    public init(persistence: AnkiPersistenceController = .shared) async {
        self.persistence = persistence
        await reload()
        startObservingSaves()
    }

    public func addNote(resolver: any TemplateValueResolver) async throws {
        guard isReady,
              let provider,
              let duplicateOptions,
              let fieldMap,
              let profileName,
              let deckName,
              let modelName
        else {
            throw AnkiConnectionManagerError.notReady
        }

        var fields: [String: [TemplateResolvedValue]] = [:]
        for (templateValue, fieldName) in fieldMap.map {
            let resolvedValue = await resolver.resolve(templateValue)
            fields[fieldName, default: []].append(resolvedValue)
        }

        try await provider.addNote(
            fields: fields,
            profileName: profileName,
            deckName: deckName,
            modelName: modelName,
            duplicateOptions: duplicateOptions
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
            object.entity.name != "AnkiNote" // Currently all entities other than notes should trigger a reload
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
                  !modelName.isEmpty,
                  let profileName = config.profileName,
                  !profileName.isEmpty
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard let provider = await makeProvider(
                host: config.apiHost,
                port: config.apiPort,
                apiKey: config.apiKey
            ) else {
                throw AnkiConnectionManagerError.providerUnavailable
            }

            self.provider = provider
            self.duplicateOptions = duplicateOptions
            self.fieldMap = fieldMap
            self.profileName = profileName
            self.deckName = deckName
            self.modelName = modelName

            isReady = true
        } catch {
            isReady = false
        }
    }

    private struct AnkiConfiguration {
        let duplicateNoteSettingsJSON: String?
        let fieldMapJSON: String?
        let deckName: String?
        let modelName: String?
        let profileName: String?
        let apiHost: String?
        let apiPort: Int
        let apiKey: String?
    }

    private func fetchSettings() async throws -> AnkiConfiguration {
        let context = persistence.container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            let settings = try context.fetch(request).first

            guard let settings,
                  let deck = settings.defaultTermCardDeck,
                  let model = settings.defaultTermCardModel,
                  let profile = deck.profile,
                  let api = profile.api
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            return AnkiConfiguration(
                duplicateNoteSettingsJSON: settings.duplicateNoteSettings,
                fieldMapJSON: model.maruSettings?.fieldMap,
                deckName: deck.name,
                modelName: model.name,
                profileName: profile.name,
                apiHost: api.connectHost,
                apiPort: Int(api.connectPort),
                apiKey: api.connectAPIKey
            )
        }
    }

    private func makeProvider(host: String?, port: Int, apiKey: String?) async -> (any AnkiProvider)? {
        guard let host, !host.isEmpty else {
            return nil
        }

        do {
            let provider = try await AnkiConnectProvider(
                host: host,
                port: port > 0 ? port : 8765,
                apiKey: apiKey
            )
            return provider
        } catch {
            self.error = error
            return UnimplementedAnkiProvider()
        }
    }
}

private struct UnimplementedAnkiProvider: AnkiProvider {
    func addNote(
        fields _: [String: [TemplateResolvedValue]],
        profileName _: String,
        deckName _: String,
        modelName _: String,
        duplicateOptions _: DuplicateDetectionOptions
    ) async throws {
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
