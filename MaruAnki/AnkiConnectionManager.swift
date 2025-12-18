//
//  AnkiConnectionManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/18/25.
//

import CoreData
import Foundation

public enum AnkiConnectionManagerError: Error {
    case notReady
    case providerUnavailable
    case missingRequiredSettings
}

/// Converts resolved `TemplateValue`s into note fields based on persisted Anki settings.
@MainActor
public final class AnkiConnectionManager {
    public private(set) var isReady: Bool = false
    public private(set) var error: Error?

    private let persistence: AnkiPersistenceController

    private var provider: (any AnkiProvider)?
    private var duplicateOptions: DuplicateDetectionOptions?
    private var fieldMap: AnkiFieldMap?

    private var profileName: String?
    private var deckName: String?
    private var modelName: String?

    private var didSaveObserver: NSObjectProtocol?

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
        guard didSaveObserver == nil else { return }

        didSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            guard let context = notification.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === self.persistence.container.persistentStoreCoordinator
            else { return }

            let changedObjects = Self.changedObjects(from: notification)
            guard !changedObjects.isEmpty else { return }

            // Reload on any saved entity other than AnkiNote.
            let containsNonNote = changedObjects.contains { $0.entity.name != "AnkiNote" }
            guard containsNonNote else { return }

            Task { @MainActor in
                await self.reload()
            }
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
            let (settings, deck, model) = try fetchSettings()

            guard let profile = deck.profile,
                  let api = profile.api
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard let duplicateNoteSettingsJSON = settings.duplicateNoteSettings else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            let duplicateOptions = try JSONDecoder().decode(
                DuplicateDetectionOptions.self,
                from: Data(duplicateNoteSettingsJSON.utf8)
            )

            guard let modelSettings = model.maruSettings,
                  let fieldMapJSON = modelSettings.fieldMap
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            let fieldMap = try JSONDecoder().decode(
                AnkiFieldMap.self,
                from: Data(fieldMapJSON.utf8)
            )

            guard let deckName = deck.name,
                  !deckName.isEmpty,
                  let modelName = model.name,
                  !modelName.isEmpty,
                  let profileName = profile.name,
                  !profileName.isEmpty
            else {
                throw AnkiConnectionManagerError.missingRequiredSettings
            }

            guard let provider = await makeProvider(api: api) else {
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

    private func fetchSettings() throws -> (MaruAnkiSettings, AnkiDeck, AnkiModel) {
        let context = persistence.container.viewContext

        let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
        request.fetchLimit = 1
        let settings = try context.fetch(request).first

        guard let settings,
              let deck = settings.defaultTermCardDeck,
              let model = settings.defaultTermCardModel
        else {
            throw AnkiConnectionManagerError.missingRequiredSettings
        }

        return (settings, deck, model)
    }

    private func makeProvider(api: AnkiAPI) async -> (any AnkiProvider)? {
        guard let host = api.connectHost, !host.isEmpty else {
            return nil
        }
        let port = Int(api.connectPort)
        let apiKey = api.connectAPIKey

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
}
