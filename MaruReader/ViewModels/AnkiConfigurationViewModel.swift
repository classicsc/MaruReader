//
//  AnkiConfigurationViewModel.swift
//  MaruReader
//
//  Manages state for the Anki configuration flow.
//

import CoreData
import Foundation
import MaruAnki
import Observation

struct FieldMappingProfileInfo: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let isSystemProfile: Bool
    let fieldMap: AnkiFieldMap?
}

private struct AnkiMobileInfoForAdding: Decodable {
    struct NamedItem: Decodable {
        let name: String
    }

    struct NoteType: Decodable {
        struct Field: Decodable {
            let name: String
        }

        let fields: [Field]
        let name: String
        let kind: String?
    }

    let decks: [NamedItem]
    let notetypes: [NoteType]
    let profiles: [NamedItem]?
}

@MainActor
@Observable
final class AnkiConfigurationViewModel {
    enum ConfigurationStep: Int, CaseIterable, Sendable {
        case connectionType = 0
        case connectionDetails = 1
        case mobileDetails = 2
        case profileSelection = 3
        case deckSelection = 4
        case modelSelection = 5
        case fieldMappingSelection = 6
    }

    enum ConnectionType: String, CaseIterable, Identifiable, Sendable {
        case ankiConnect = "Anki-Connect"
        case ankiMobile = "AnkiMobile"

        var id: String { rawValue }
    }

    // Current step
    var currentStep: ConfigurationStep = .connectionType

    // Connection type
    var connectionType: ConnectionType = .ankiConnect

    // Connection settings (temporary, not saved until completion)
    var host: String = "localhost"
    var port: String = "8765"
    var apiKey: String = ""

    // Fetched data
    var profiles: [AnkiProfileMeta] = []
    var decks: [AnkiDeckMeta] = []
    var models: [AnkiModelMeta] = []
    var fieldMappingProfiles: [FieldMappingProfileInfo] = []
    var isAnkiMobileInfoLoaded: Bool = false

    // Selections
    var selectedProfileID: String?
    var selectedDeckName: String?
    var selectedModelName: String?
    var selectedFieldMappingProfileID: UUID?

    // Loading/Error state
    var isLoading: Bool = false
    var error: Error?
    var showError: Bool = false

    // Completion callback
    var onComplete: (() -> Void)?

    // Dependencies
    private let persistence: AnkiPersistenceController

    init(persistence: AnkiPersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Computed Properties

    var selectedProfile: AnkiProfileMeta? {
        profiles.first { $0.id == selectedProfileID }
    }

    var selectedDeck: AnkiDeckMeta? {
        decks.first { $0.name == selectedDeckName }
    }

    var selectedModel: AnkiModelMeta? {
        models.first { $0.name == selectedModelName }
    }

    var selectedFieldMappingProfile: FieldMappingProfileInfo? {
        fieldMappingProfiles.first { $0.id == selectedFieldMappingProfileID }
    }

    var portInt: Int? {
        Int(port)
    }

    var apiKeyOrNil: String? {
        apiKey.isEmpty ? nil : apiKey
    }

    var canProceed: Bool {
        switch currentStep {
        case .connectionType:
            true
        case .connectionDetails:
            !host.isEmpty && portInt != nil && portInt! > 0
        case .mobileDetails:
            isAnkiMobileInfoLoaded
        case .profileSelection:
            selectedProfileID != nil
        case .deckSelection:
            selectedDeckName != nil
        case .modelSelection:
            selectedModelName != nil
        case .fieldMappingSelection:
            selectedFieldMappingProfileID != nil
        }
    }

    // MARK: - Step Navigation

    func proceed() async {
        guard canProceed else { return }

        switch currentStep {
        case .connectionType:
            switch connectionType {
            case .ankiConnect:
                currentStep = .connectionDetails
            case .ankiMobile:
                currentStep = .mobileDetails
            }

        case .connectionDetails:
            await testConnectionAndProceed()

        case .mobileDetails:
            if isAnkiMobileInfoLoaded {
                currentStep = .profileSelection
            }

        case .profileSelection:
            switch connectionType {
            case .ankiConnect:
                await fetchDecksAndModels()
            case .ankiMobile:
                currentStep = .deckSelection
            }

        case .deckSelection:
            currentStep = .modelSelection

        case .modelSelection:
            await fetchFieldMappingProfiles()

        case .fieldMappingSelection:
            await saveConfiguration()
        }
    }

    func goBack() {
        switch currentStep {
        case .connectionType:
            break
        case .connectionDetails:
            currentStep = .connectionType
        case .mobileDetails:
            currentStep = .connectionType
        case .profileSelection:
            switch connectionType {
            case .ankiConnect:
                currentStep = .connectionDetails
            case .ankiMobile:
                currentStep = .mobileDetails
            }
        case .deckSelection:
            currentStep = .profileSelection
        case .modelSelection:
            currentStep = .deckSelection
        case .fieldMappingSelection:
            switch connectionType {
            case .ankiConnect:
                currentStep = .modelSelection
            case .ankiMobile:
                currentStep = .mobileDetails
            }
        }
    }

    // MARK: - Connection Testing

    private func testConnectionAndProceed() async {
        guard let portInt else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let manager = await AnkiConnectionManager(persistence: persistence)
            try await manager.testConnection(host: host, port: portInt, apiKey: apiKeyOrNil)

            // Connection successful, fetch profiles
            profiles = try await manager.getProfiles(host: host, port: portInt, apiKey: apiKeyOrNil)

            // Auto-select active profile if there is one
            if let activeProfile = profiles.first(where: { $0.isActiveProfile }) {
                selectedProfileID = activeProfile.id
            }

            currentStep = .profileSelection
        } catch {
            self.error = error
            showError = true
        }
    }

    // MARK: - Data Fetching

    private func fetchDecksAndModels() async {
        guard let profileID = selectedProfileID,
              let portInt
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let manager = await AnkiConnectionManager(persistence: persistence)

            decks = try await manager.getDecks(
                host: host,
                port: portInt,
                apiKey: apiKeyOrNil,
                forProfile: profileID
            )

            models = try await manager.getModels(
                host: host,
                port: portInt,
                apiKey: apiKeyOrNil,
                forProfile: profileID
            )

            currentStep = .deckSelection
        } catch {
            self.error = error
            showError = true
        }
    }

    func applyAnkiMobileInfoForAddingData(_ data: Data) {
        do {
            let info = try JSONDecoder().decode(AnkiMobileInfoForAdding.self, from: data)
            let profileNames = info.profiles?.map(\.name) ?? []
            let loadedProfiles = profileNames.map { AnkiProfileMeta(id: $0, isActiveProfile: false) }
            let defaultProfileID = loadedProfiles.first?.id ?? ""
            profiles = loadedProfiles
            decks = info.decks.map { deck in
                AnkiDeckMeta(id: deck.name, name: deck.name, profileName: defaultProfileID)
            }
            models = info.notetypes.map { noteType in
                AnkiModelMeta(
                    id: noteType.name,
                    name: noteType.name,
                    profileName: defaultProfileID,
                    fields: noteType.fields.map(\.name)
                )
            }
            selectedProfileID = loadedProfiles.first?.id
            selectedDeckName = nil
            selectedModelName = nil
            isAnkiMobileInfoLoaded = true
            currentStep = loadedProfiles.isEmpty ? .deckSelection : .profileSelection
        } catch {
            self.error = error
            showError = true
        }
    }

    private func fetchFieldMappingProfiles() async {
        let context = persistence.newBackgroundContext()

        // Fetch and extract data within the context to avoid cross-context access
        let profileInfos: [FieldMappingProfileInfo] = await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isSystemProfile", ascending: false),
                NSSortDescriptor(key: "displayName", ascending: true),
            ]

            guard let profiles = try? context.fetch(request) else {
                return []
            }

            let decoder = JSONDecoder()
            return profiles.compactMap { profile in
                guard let id = profile.id else { return nil }
                var fieldMap: AnkiFieldMap?
                if let fieldMapString = profile.fieldMap,
                   let data = fieldMapString.data(using: .utf8)
                {
                    fieldMap = try? decoder.decode(AnkiFieldMap.self, from: data)
                }
                return FieldMappingProfileInfo(
                    id: id,
                    displayName: profile.displayName ?? "Unnamed",
                    isSystemProfile: profile.isSystemProfile,
                    fieldMap: fieldMap
                )
            }
        }

        fieldMappingProfiles = profileInfos

        // Auto-select Basic if it exists
        if let basicProfile = fieldMappingProfiles.first(where: { $0.id == SystemProfileManager.basicProfileUUID }) {
            selectedFieldMappingProfileID = basicProfile.id
        } else if let firstProfile = fieldMappingProfiles.first {
            selectedFieldMappingProfileID = firstProfile.id
        }

        currentStep = .fieldMappingSelection
    }

    // MARK: - Save Configuration

    private func saveConfiguration() async {
        guard let fieldMappingID = selectedFieldMappingProfileID else { return }

        isLoading = true
        defer { isLoading = false }

        let context = persistence.newBackgroundContext()

        // Capture MainActor-isolated properties before entering background context
        let hostValue = host
        let apiKeyValue = apiKeyOrNil
        let connectionType = connectionType
        let selectedProfileID = selectedProfileID
        let selectedDeckName = selectedDeckName
        let selectedModelName = selectedModelName
        let portValue = portInt

        do {
            try await context.perform {
                // Fetch or create settings
                let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
                request.fetchLimit = 1

                let settings: MaruAnkiSettings
                if let existing = try context.fetch(request).first {
                    settings = existing
                } else {
                    settings = MaruAnkiSettings(context: context)
                    settings.id = UUID()
                }

                // Update settings
                settings.ankiEnabled = true

                switch connectionType {
                case .ankiConnect:
                    guard let profileID = selectedProfileID,
                          let deckName = selectedDeckName,
                          let modelName = selectedModelName,
                          let portInt = portValue
                    else {
                        throw AnkiConfigurationError.invalidConfiguration
                    }

                    settings.isAnkiConnect = true
                    settings.defaultProfileName = profileID
                    settings.defaultDeckName = deckName
                    settings.defaultModelName = modelName

                    // Set connect configuration
                    settings.connectConfiguration = [
                        "hostname": hostValue,
                        "port": portInt,
                        "apiKey": apiKeyValue as Any,
                    ]
                case .ankiMobile:
                    let trimmedDeck = selectedDeckName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedModel = selectedModelName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let trimmedDeck, !trimmedDeck.isEmpty,
                          let trimmedModel, !trimmedModel.isEmpty
                    else {
                        throw AnkiConfigurationError.invalidConfiguration
                    }

                    settings.isAnkiConnect = false
                    let trimmedProfile = selectedProfileID?.trimmingCharacters(in: .whitespacesAndNewlines)
                    settings.defaultProfileName = trimmedProfile?.isEmpty == false ? trimmedProfile! : ""
                    settings.defaultDeckName = trimmedDeck
                    settings.defaultModelName = trimmedModel
                    settings.connectConfiguration = nil
                }

                // Link to field mapping profile
                let profileRequest = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
                profileRequest.predicate = NSPredicate(format: "id == %@", fieldMappingID as CVarArg)
                profileRequest.fetchLimit = 1
                if let profile = try context.fetch(profileRequest).first {
                    settings.modelConfiguration = profile
                }

                // Set default duplicate detection options
                let duplicateOptions = DuplicateDetectionOptions(
                    scope: .deck,
                    deckName: nil,
                    includeChildDecks: false,
                    checkAllModels: false
                )
                let encoder = JSONEncoder()
                let duplicateData = try encoder.encode(duplicateOptions)
                settings.duplicateNoteSettings = String(data: duplicateData, encoding: .utf8)

                try context.save()
            }

            onComplete?()
        } catch {
            self.error = error
            showError = true
        }
    }

    // MARK: - Field Mapping Management

    func refreshFieldMappingProfiles() async {
        let context = persistence.newBackgroundContext()

        let profileInfos: [FieldMappingProfileInfo] = await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isSystemProfile", ascending: false),
                NSSortDescriptor(key: "displayName", ascending: true),
            ]

            guard let profiles = try? context.fetch(request) else {
                return []
            }

            let decoder = JSONDecoder()
            return profiles.compactMap { profile in
                guard let id = profile.id else { return nil }
                var fieldMap: AnkiFieldMap?
                if let fieldMapString = profile.fieldMap,
                   let data = fieldMapString.data(using: .utf8)
                {
                    fieldMap = try? decoder.decode(AnkiFieldMap.self, from: data)
                }
                return FieldMappingProfileInfo(
                    id: id,
                    displayName: profile.displayName ?? "Unnamed",
                    isSystemProfile: profile.isSystemProfile,
                    fieldMap: fieldMap
                )
            }
        }

        fieldMappingProfiles = profileInfos
    }

    func createFieldMappingProfile(name: String, fieldMap: AnkiFieldMap) async throws -> UUID {
        let context = persistence.newBackgroundContext()
        let newID = UUID()

        try await context.perform {
            let profile = MaruModelSettings(context: context)
            profile.id = newID
            profile.displayName = name
            profile.isSystemProfile = false

            let encoder = JSONEncoder()
            let data = try encoder.encode(fieldMap)
            profile.fieldMap = String(data: data, encoding: .utf8)

            try context.save()
        }

        await refreshFieldMappingProfiles()
        return newID
    }

    func updateFieldMappingProfile(id: UUID, name: String, fieldMap: AnkiFieldMap) async throws {
        let context = persistence.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let profile = try context.fetch(request).first else {
                throw FieldMappingError.profileNotFound
            }

            if profile.isSystemProfile {
                throw FieldMappingError.cannotModifySystemProfile
            }

            profile.displayName = name

            let encoder = JSONEncoder()
            let data = try encoder.encode(fieldMap)
            profile.fieldMap = String(data: data, encoding: .utf8)

            try context.save()
        }

        await refreshFieldMappingProfiles()
    }

    func deleteFieldMappingProfile(id: UUID) async throws {
        let context = persistence.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let profile = try context.fetch(request).first else {
                throw FieldMappingError.profileNotFound
            }

            if profile.isSystemProfile {
                throw FieldMappingError.cannotDeleteSystemProfile
            }

            context.delete(profile)
            try context.save()
        }

        await refreshFieldMappingProfiles()

        if selectedFieldMappingProfileID == id {
            selectedFieldMappingProfileID = fieldMappingProfiles.first?.id
        }
    }
}

enum FieldMappingError: LocalizedError, Sendable {
    case profileNotFound
    case cannotModifySystemProfile
    case cannotDeleteSystemProfile

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            "Field mapping profile not found."
        case .cannotModifySystemProfile:
            "System profiles cannot be modified."
        case .cannotDeleteSystemProfile:
            "System profiles cannot be deleted."
        }
    }
}

enum AnkiConfigurationError: LocalizedError, Sendable {
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Missing required configuration values."
        }
    }
}
