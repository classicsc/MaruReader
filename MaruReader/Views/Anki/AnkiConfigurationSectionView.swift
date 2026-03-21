// AnkiConfigurationSectionView.swift
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

import MaruAnki
import SwiftUI

struct AnkiConfigurationSectionView: View {
    let snapshot: AnkiSettingsSnapshot
    @Binding var allowDuplicates: Bool
    let isSavingDuplicateOptions: Bool

    var body: some View {
        Section("Current Configuration") {
            switch snapshot.connection {
            case let .ankiConnect(server):
                LabeledContent("Connection", value: "Anki-Connect")
                if let server {
                    LabeledContent("Server", value: server)
                }
            case .ankiMobile:
                LabeledContent("Connection", value: "AnkiMobile")
            }

            if let profile = snapshot.profileName {
                LabeledContent("Profile", value: profile)
            }

            if let deck = snapshot.deckName {
                LabeledContent("Deck", value: deck)
            }

            if let model = snapshot.modelName {
                LabeledContent("Note Type", value: model)
            }

            if let fieldMapping = snapshot.fieldMappingName {
                LabeledContent("Field Mapping", value: fieldMapping)
            }
        }

        Section("Duplicate Detection") {
            switch snapshot.connection {
            case .ankiConnect:
                NavigationLink {
                    DuplicateSettingsEditorView(
                        decks: [],
                        selectedDeckName: snapshot.deckName
                    )
                } label: {
                    LabeledContent("Scope", value: snapshot.duplicateScopeDisplayName)
                }
            case .ankiMobile:
                Toggle("Allow Duplicate Notes", isOn: $allowDuplicates)
                    .disabled(isSavingDuplicateOptions)
            }
        }
    }
}
