// AnkiConfigurationViewModelTests.swift
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
}
