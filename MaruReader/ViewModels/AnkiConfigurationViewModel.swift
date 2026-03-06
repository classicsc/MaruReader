// AnkiConfigurationViewModel.swift
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
import Observation

struct FieldMappingProfileInfo: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let isSystemProfile: Bool
    let isHidden: Bool
    let sourceTemplateID: String?
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
        case duplicateSettings = 7
        case templateConfiguration = 8
    }

    enum ConnectionType: String, CaseIterable, Identifiable, Sendable {
        case ankiMobile = "AnkiMobile"
        case ankiConnect = "Anki-Connect"

        var id: String {
            rawValue
        }
    }

    /// Current step
    var currentStep: ConfigurationStep = .connectionType

    /// Connection type
    var connectionType: ConnectionType = .ankiMobile

    // Connection settings (temporary, not saved until completion)
    var host: String = ""
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

    // Template configuration
    var selectedTemplateID: String?
    var templateDictionaryID: UUID?
    var templateCardType: LapisCardType = .vocabularyCard
    var templateConfiguredProfiles: [String: Bool] = [:] // templateID -> isConfigured

    // Duplicate detection settings
    var duplicateScope: DuplicateNoteScope = .deck
    var duplicateDeckName: String? // nil = use target deck
    var duplicateIncludeChildDecks: Bool = false
    var duplicateCheckAllModels: Bool = false

    // Loading/Error state
    var isLoading: Bool = false
    var error: Error?
    var showError: Bool = false

    /// Completion callback
    var onComplete: (() -> Void)?

    /// Dependencies
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

    var selectedTemplate: ConfigurableProfileTemplate? {
        guard let id = selectedTemplateID else { return nil }
        return ConfigurableProfileTemplates.template(for: id)
    }

    var portInt: Int? {
        Int(port)
    }

    var apiKeyOrNil: String? {
        apiKey.isEmpty ? nil : apiKey
    }

    var canGoBack: Bool {
        currentStep != .connectionType
    }

    var selectedCompatibleFieldMappingProfile: FieldMappingProfileInfo? {
        guard let profile = selectedFieldMappingProfile else { return nil }
        return isFieldMappingProfileCompatibleWithSelectedModel(profile) ? profile : nil
    }

    var compatibleVisibleFieldMappingProfiles: [FieldMappingProfileInfo] {
        fieldMappingProfiles.filter { !$0.isHidden && isFieldMappingProfileCompatibleWithSelectedModel($0) }
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
            selectedTemplateID != nil || selectedCompatibleFieldMappingProfile != nil
        case .duplicateSettings:
            true // Duplicate settings always has valid defaults
        case .templateConfiguration:
            templateDictionaryID != nil
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
            currentStep = .duplicateSettings

        case .duplicateSettings:
            if selectedTemplateID != nil {
                // User selected a template, go to configuration step
                await loadTemplateConfiguration()
                currentStep = .templateConfiguration
            } else {
                await saveConfiguration()
            }

        case .templateConfiguration:
            await saveTemplateConfiguration()
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
            if connectionType == .ankiMobile, profiles.isEmpty {
                currentStep = .mobileDetails
            } else {
                currentStep = .profileSelection
            }
        case .modelSelection:
            currentStep = .deckSelection
        case .fieldMappingSelection:
            currentStep = .modelSelection
        case .duplicateSettings:
            currentStep = .fieldMappingSelection
        case .templateConfiguration:
            // Clear template configuration and go back to duplicate settings
            templateDictionaryID = nil
            templateCardType = .vocabularyCard
            currentStep = .duplicateSettings
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

    // MARK: - Field Mapping Compatibility

    func isFieldMappingProfileCompatibleWithSelectedModel(_ profile: FieldMappingProfileInfo) -> Bool {
        guard let selectedModel else { return true }
        return Self.isFieldMap(profile.fieldMap, compatibleWithNoteTypeFields: selectedModel.fields)
    }

    func prefilledSetupFieldMappingsForSelectedModel() -> [(fieldName: String, values: [TemplateValue])] {
        guard let selectedModel else { return [] }
        return Self.prefilledSetupFieldMappings(forNoteTypeFields: selectedModel.fields)
    }

    nonisolated static func isFieldMap(_ fieldMap: AnkiFieldMap?, compatibleWithNoteTypeFields noteTypeFields: [String]) -> Bool {
        guard let fieldMap else { return false }

        let normalizedNoteTypeFields = Set(noteTypeFields.map(normalizedFieldIdentifier))
        guard !normalizedNoteTypeFields.isEmpty else { return false }

        return fieldMap.map.keys.allSatisfy { fieldName in
            normalizedNoteTypeFields.contains(normalizedFieldIdentifier(fieldName))
        }
    }

    nonisolated static func prefilledSetupFieldMappings(forNoteTypeFields noteTypeFields: [String])
        -> [(fieldName: String, values: [TemplateValue])]
    {
        noteTypeFields.map { fieldName in
            let values: [TemplateValue] = if let matchedValue = matchedTemplateValue(forFieldName: fieldName) {
                [matchedValue]
            } else {
                []
            }
            return (fieldName: fieldName, values: values)
        }
    }

    nonisolated static func matchedTemplateValue(forFieldName fieldName: String) -> TemplateValue? {
        let normalized = normalizedFieldIdentifier(fieldName)
        guard !normalized.isEmpty else { return nil }
        return templateValueAutoFillByNormalizedFieldName[normalized]
    }

    private nonisolated static func normalizedFieldIdentifier(_ fieldName: String) -> String {
        let filtered = fieldName.unicodeScalars.filter(CharacterSet.alphanumerics.contains)
        return String(String.UnicodeScalarView(filtered)).lowercased()
    }

    private nonisolated static let templateValueAutoFillByNormalizedFieldName: [String: TemplateValue] = {
        let aliases: [(TemplateValue, [String])] = [
            (.expression, ["expression"]),
            (.furigana, ["furigana"]),
            (.reading, ["reading"]),
            (.sentence, ["sentence"]),
            (.sentenceFurigana, ["sentenceFurigana"]),
            (.clozePrefix, ["clozePrefix"]),
            (.clozeBody, ["clozeBody"]),
            (.clozeSuffix, ["clozeSuffix"]),
            (.clozeFuriganaPrefix, ["clozeFuriganaPrefix"]),
            (.clozeFuriganaBody, ["clozeFuriganaBody"]),
            (.clozeFuriganaSuffix, ["clozeFuriganaSuffix"]),
            (.tags, ["tags"]),
            (.contextImage, ["contextImage"]),
            (.contextInfo, ["contextInfo"]),
            (.singleGlossary, ["singleGlossary", "glossary"]),
            (.multiDictionaryGlossary, ["multiDictionaryGlossary"]),
            (.glossaryNoDictionary, ["glossaryNoDictionary"]),
            (.pronunciationAudio, ["pronunciationAudio", "audio"]),
            (.singlePitchAccent, ["singlePitchAccent", "pitchAccent"]),
            (.pitchAccentList, ["pitchAccentList"]),
            (.pitchAccentDisambiguation, ["pitchAccentDisambiguation"]),
            (.pitchAccentCategories, ["pitchAccentCategories"]),
            (.conjugation, ["conjugation"]),
            (.frequencyList, ["frequencyList"]),
            (.singleFrequency, ["singleFrequency", "frequency"]),
            (.frequencyRankHarmonicMeanSortField, ["frequencyRankHarmonicMeanSortField"]),
            (.frequencyOccurrenceHarmonicMeanSortField, ["frequencyOccurrenceHarmonicMeanSortField"]),
            (.partOfSpeech, ["partOfSpeech", "pos"]),
        ]

        var mapping: [String: TemplateValue] = [:]
        for (value, names) in aliases {
            for name in names {
                mapping[normalizedFieldIdentifier(name)] = value
            }
        }
        return mapping
    }()

    private func fetchFieldMappingProfiles() async {
        let context = persistence.newBackgroundContext()

        // Fetch and extract data within the context to avoid cross-context access
        let (profileInfos, configuredTemplates): ([FieldMappingProfileInfo], [String: Bool]) = await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isSystemProfile", ascending: false),
                NSSortDescriptor(key: "displayName", ascending: true),
            ]

            guard let profiles = try? context.fetch(request) else {
                return ([], [:])
            }

            let decoder = JSONDecoder()
            var configured: [String: Bool] = [:]

            let infos = profiles.compactMap { profile -> FieldMappingProfileInfo? in
                guard let id = profile.id else { return nil }

                // Track configured templates
                if let templateID = profile.sourceTemplateID {
                    configured[templateID] = true
                }

                var fieldMap: AnkiFieldMap?
                if let fieldMapString = profile.fieldMap,
                   let data = fieldMapString.data(using: .utf8)
                {
                    fieldMap = try? decoder.decode(AnkiFieldMap.self, from: data)
                }
                return FieldMappingProfileInfo(
                    id: id,
                    displayName: profile.displayName ?? AppLocalization.unnamed,
                    isSystemProfile: profile.isSystemProfile,
                    isHidden: profile.isHidden,
                    sourceTemplateID: profile.sourceTemplateID,
                    fieldMap: fieldMap
                )
            }

            return (infos, configured)
        }

        fieldMappingProfiles = profileInfos
        templateConfiguredProfiles = configuredTemplates

        // Auto-select Basic if it exists
        if let basicProfile = fieldMappingProfiles.first(where: {
            $0.id == SystemProfileManager.basicProfileUUID && !$0.isHidden &&
                isFieldMappingProfileCompatibleWithSelectedModel($0)
        }) {
            selectedFieldMappingProfileID = basicProfile.id
        } else if let firstProfile = compatibleVisibleFieldMappingProfiles.first {
            selectedFieldMappingProfileID = firstProfile.id
        } else {
            selectedFieldMappingProfileID = nil
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
        let duplicateScopeValue = duplicateScope
        let duplicateDeckNameValue = duplicateDeckName
        let duplicateIncludeChildDecksValue = duplicateIncludeChildDecks
        let duplicateCheckAllModelsValue = duplicateCheckAllModels

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

                // Set duplicate detection options from user configuration
                let duplicateOptions = DuplicateDetectionOptions(
                    scope: duplicateScopeValue,
                    deckName: duplicateDeckNameValue,
                    includeChildDecks: duplicateIncludeChildDecksValue,
                    checkAllModels: duplicateCheckAllModelsValue
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

    // MARK: - Template Configuration

    private func loadTemplateConfiguration() async {
        guard let templateID = selectedTemplateID else { return }

        let context = persistence.newBackgroundContext()

        // Load existing configuration if any
        if let existingConfig = await SystemProfileManager.getConfiguredProfileData(for: templateID, in: context) {
            templateDictionaryID = existingConfig.mainDefinitionDictionaryID
            templateCardType = existingConfig.lapisCardType ?? .vocabularyCard
        } else {
            // Reset to defaults
            templateDictionaryID = nil
            templateCardType = .vocabularyCard
        }
    }

    private func saveTemplateConfiguration() async {
        guard let templateID = selectedTemplateID,
              let template = selectedTemplate,
              let dictionaryID = templateDictionaryID
        else { return }

        isLoading = true
        defer { isLoading = false }

        let context = persistence.newBackgroundContext()

        do {
            // Build the field map from template + configuration
            let fieldMap = template.buildFieldMap(
                mainDefinitionDictionaryID: dictionaryID,
                cardType: templateCardType
            )

            // Create configuration data
            let configuration = ConfiguredProfileData(
                templateID: templateID,
                mainDefinitionDictionaryID: dictionaryID,
                cardType: templateCardType
            )

            // Save the configured profile
            let profileID = try await SystemProfileManager.saveConfiguredProfile(
                templateID: templateID,
                fieldMap: fieldMap,
                configuration: configuration,
                in: context
            )

            // Select the configured profile and save
            selectedFieldMappingProfileID = profileID
            selectedTemplateID = nil // Clear template selection

            await saveConfiguration()
        } catch {
            self.error = error
            showError = true
        }
    }

    /// Selects a template for configuration.
    func selectTemplate(_ templateID: String) {
        selectedTemplateID = templateID
        selectedFieldMappingProfileID = nil // Clear regular profile selection
    }

    /// Clears template selection and allows selecting a regular profile.
    func clearTemplateSelection() {
        selectedTemplateID = nil
        templateDictionaryID = nil
        templateCardType = .vocabularyCard
    }

    // MARK: - Field Mapping Management

    func refreshFieldMappingProfiles() async {
        let context = persistence.newBackgroundContext()

        let (profileInfos, configuredTemplates): ([FieldMappingProfileInfo], [String: Bool]) = await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isSystemProfile", ascending: false),
                NSSortDescriptor(key: "displayName", ascending: true),
            ]

            guard let profiles = try? context.fetch(request) else {
                return ([], [:])
            }

            let decoder = JSONDecoder()
            var configured: [String: Bool] = [:]

            let infos = profiles.compactMap { profile -> FieldMappingProfileInfo? in
                guard let id = profile.id else { return nil }

                if let templateID = profile.sourceTemplateID {
                    configured[templateID] = true
                }

                var fieldMap: AnkiFieldMap?
                if let fieldMapString = profile.fieldMap,
                   let data = fieldMapString.data(using: .utf8)
                {
                    fieldMap = try? decoder.decode(AnkiFieldMap.self, from: data)
                }
                return FieldMappingProfileInfo(
                    id: id,
                    displayName: profile.displayName ?? AppLocalization.unnamed,
                    isSystemProfile: profile.isSystemProfile,
                    isHidden: profile.isHidden,
                    sourceTemplateID: profile.sourceTemplateID,
                    fieldMap: fieldMap
                )
            }

            return (infos, configured)
        }

        fieldMappingProfiles = profileInfos
        templateConfiguredProfiles = configuredTemplates

        if let selectedFieldMappingProfile,
           !isFieldMappingProfileCompatibleWithSelectedModel(selectedFieldMappingProfile)
        {
            selectedFieldMappingProfileID = nil
        }
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
            String(localized: "Field mapping profile not found.")
        case .cannotModifySystemProfile:
            String(localized: "System profiles cannot be modified.")
        case .cannotDeleteSystemProfile:
            String(localized: "System profiles cannot be deleted.")
        }
    }
}

enum AnkiConfigurationError: LocalizedError, Sendable {
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            String(localized: "Missing required configuration values.")
        }
    }
}
