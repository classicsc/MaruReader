// AnkiConfigurationViewModelTests.swift
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

struct AnkiConfigurationViewModelTests {
    @Test func matchedTemplateValueUsesNormalizedFieldName() {
        #expect(AnkiConfigurationViewModel.matchedTemplateValue(forFieldName: "Expression") == .expression)
        #expect(AnkiConfigurationViewModel.matchedTemplateValue(forFieldName: "expression") == .expression)
        #expect(AnkiConfigurationViewModel.matchedTemplateValue(forFieldName: "Part of Speech") == .partOfSpeech)
        #expect(AnkiConfigurationViewModel.matchedTemplateValue(forFieldName: "pitch_accent") == .singlePitchAccent)
        #expect(AnkiConfigurationViewModel.matchedTemplateValue(forFieldName: "UnknownField") == nil)
    }

    @Test func prefilledSetupFieldMappingsOnlyPrefillsMatchingFields() {
        let mappings = AnkiConfigurationViewModel.prefilledSetupFieldMappings(
            forNoteTypeFields: ["Expression", "Reading", "Front Custom"]
        )

        #expect(mappings.count == 3)
        #expect(mappings[0].fieldName == "Expression")
        #expect(mappings[0].values == [.expression])
        #expect(mappings[1].values == [.reading])
        #expect(mappings[2].values.isEmpty)
    }

    @Test @MainActor func compatibleVisibleFieldMappingProfilesFiltersBySelectedNoteTypeFields() {
        let viewModel = AnkiConfigurationViewModel()
        viewModel.models = [
            AnkiModelMeta(id: "1", name: "Basic", profileName: "Default", fields: ["Expression", "Reading"]),
        ]
        viewModel.selectedModelName = "Basic"

        let compatible = FieldMappingProfileInfo(
            id: UUID(),
            displayName: "Compatible",
            isSystemProfile: false,
            isHidden: false,
            sourceTemplateID: nil,
            fieldMap: AnkiFieldMap(map: ["expression": [.expression], "reading": [.reading]])
        )
        let incompatible = FieldMappingProfileInfo(
            id: UUID(),
            displayName: "Incompatible",
            isSystemProfile: false,
            isHidden: false,
            sourceTemplateID: nil,
            fieldMap: AnkiFieldMap(map: ["Glossary": [.singleGlossary]])
        )
        let hiddenButCompatible = FieldMappingProfileInfo(
            id: UUID(),
            displayName: "Hidden",
            isSystemProfile: false,
            isHidden: true,
            sourceTemplateID: nil,
            fieldMap: AnkiFieldMap(map: ["Expression": [.expression]])
        )
        viewModel.fieldMappingProfiles = [compatible, incompatible, hiddenButCompatible]

        let visible = viewModel.compatibleVisibleFieldMappingProfiles
        #expect(visible.count == 1)
        #expect(visible.first?.id == compatible.id)
    }

    @Test @MainActor func canProceedRequiresCompatibleFieldMappingProfileWhenTemplateNotSelected() {
        let viewModel = AnkiConfigurationViewModel()
        viewModel.currentStep = .fieldMappingSelection
        viewModel.models = [
            AnkiModelMeta(id: "1", name: "Basic", profileName: "Default", fields: ["Expression"]),
        ]
        viewModel.selectedModelName = "Basic"

        let compatible = FieldMappingProfileInfo(
            id: UUID(),
            displayName: "Compatible",
            isSystemProfile: false,
            isHidden: false,
            sourceTemplateID: nil,
            fieldMap: AnkiFieldMap(map: ["Expression": [.expression]])
        )
        let incompatible = FieldMappingProfileInfo(
            id: UUID(),
            displayName: "Incompatible",
            isSystemProfile: false,
            isHidden: false,
            sourceTemplateID: nil,
            fieldMap: AnkiFieldMap(map: ["Reading": [.reading]])
        )
        viewModel.fieldMappingProfiles = [compatible, incompatible]

        viewModel.selectedFieldMappingProfileID = incompatible.id
        #expect(!viewModel.canProceed)

        viewModel.selectedFieldMappingProfileID = compatible.id
        #expect(viewModel.canProceed)

        viewModel.selectedTemplateID = "lapis"
        viewModel.selectedFieldMappingProfileID = incompatible.id
        #expect(viewModel.canProceed)
    }

    @Test @MainActor func goBackFromFieldMappingSelectionReturnsToModelSelectionForAnkiMobile() {
        let viewModel = AnkiConfigurationViewModel()
        viewModel.connectionType = .ankiMobile
        viewModel.currentStep = .fieldMappingSelection

        viewModel.goBack()

        #expect(viewModel.currentStep == .modelSelection)
    }

    @Test @MainActor func goBackFromDeckSelectionWithoutProfilesReturnsToMobileDetails() {
        let viewModel = AnkiConfigurationViewModel()
        viewModel.connectionType = .ankiMobile
        viewModel.currentStep = .deckSelection
        viewModel.profiles = []

        viewModel.goBack()

        #expect(viewModel.currentStep == .mobileDetails)
    }

    @Test @MainActor func proceedFromConnectionDetailsLoadsProfilesAndSelectsActiveProfile() async {
        let probe = MockAnkiConnectionProbe(
            profilesResult: .success([
                AnkiProfileMeta(id: "User 1", isActiveProfile: false),
                AnkiProfileMeta(id: "User 2", isActiveProfile: true),
            ])
        )
        let viewModel = AnkiConfigurationViewModel(connectionProbeFactory: { probe })
        viewModel.connectionType = .ankiConnect
        viewModel.currentStep = .connectionDetails
        viewModel.host = "localhost"
        viewModel.port = "8765"

        await viewModel.proceed()

        #expect(viewModel.currentStep == .profileSelection)
        #expect(viewModel.profiles.map(\.id) == ["User 1", "User 2"])
        #expect(viewModel.selectedProfileID == "User 2")
        #expect(viewModel.showError == false)
    }

    @Test @MainActor func proceedFromConnectionDetailsShowsErrorOnProbeFailure() async {
        let probe = MockAnkiConnectionProbe(
            profilesResult: .failure(TestProbeError.failed)
        )
        let viewModel = AnkiConfigurationViewModel(connectionProbeFactory: { probe })
        viewModel.connectionType = AnkiConfigurationViewModel.ConnectionType.ankiConnect
        viewModel.currentStep = AnkiConfigurationViewModel.ConfigurationStep.connectionDetails
        viewModel.host = "localhost"
        viewModel.port = "8765"

        await viewModel.proceed()

        #expect(viewModel.currentStep == AnkiConfigurationViewModel.ConfigurationStep.connectionDetails)
        #expect(viewModel.showError)
        #expect(viewModel.error as? TestProbeError == .failed)
    }

    @Test @MainActor func proceedFromProfileSelectionLoadsDecksAndModelsForAnkiConnect() async {
        let probe = MockAnkiConnectionProbe(
            decksResult: .success([
                AnkiDeckMeta(id: "1", name: "Default", profileName: "User 1"),
            ]),
            modelsResult: .success([
                AnkiModelMeta(id: "1", name: "Basic", profileName: "User 1", fields: ["Front", "Back"]),
            ])
        )
        let viewModel = AnkiConfigurationViewModel(connectionProbeFactory: { probe })
        viewModel.connectionType = .ankiConnect
        viewModel.currentStep = .profileSelection
        viewModel.host = "localhost"
        viewModel.port = "8765"
        viewModel.selectedProfileID = "User 1"

        await viewModel.proceed()

        #expect(viewModel.currentStep == .deckSelection)
        #expect(viewModel.decks.map(\.name) == ["Default"])
        #expect(viewModel.models.map(\.name) == ["Basic"])
        #expect(viewModel.showError == false)
    }
}

private actor MockAnkiConnectionProbe: AnkiConnectionProbing {
    private let profilesResult: Result<[AnkiProfileMeta], Error>
    private let decksResult: Result<[AnkiDeckMeta], Error>
    private let modelsResult: Result<[AnkiModelMeta], Error>

    init(
        profilesResult: Result<[AnkiProfileMeta], Error> = .success([]),
        decksResult: Result<[AnkiDeckMeta], Error> = .success([]),
        modelsResult: Result<[AnkiModelMeta], Error> = .success([])
    ) {
        self.profilesResult = profilesResult
        self.decksResult = decksResult
        self.modelsResult = modelsResult
    }

    func fetchProfiles(connection _: AnkiConnectConnectionInfo) async throws -> [AnkiProfileMeta] {
        switch profilesResult {
        case let .success(profiles):
            return profiles
        case let .failure(error):
            throw error
        }
    }

    func fetchDecks(connection _: AnkiConnectConnectionInfo, profileName _: String) async throws -> [AnkiDeckMeta] {
        switch decksResult {
        case let .success(decks):
            return decks
        case let .failure(error):
            throw error
        }
    }

    func fetchModels(connection _: AnkiConnectConnectionInfo, profileName _: String) async throws -> [AnkiModelMeta] {
        switch modelsResult {
        case let .success(models):
            return models
        case let .failure(error):
            throw error
        }
    }
}

private enum TestProbeError: Error, Equatable {
    case failed
}
