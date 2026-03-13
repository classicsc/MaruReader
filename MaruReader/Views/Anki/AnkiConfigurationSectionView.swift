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
    let settings: MaruAnkiSettings
    let duplicateScopeDisplayName: String
    @Binding var allowDuplicates: Bool
    let isSavingDuplicateOptions: Bool

    var body: some View {
        Section("Current Configuration") {
            if settings.isAnkiConnect {
                LabeledContent("Connection", value: "Anki-Connect")
                if let config = settings.connectConfiguration,
                   let host = config["hostname"] as? String,
                   let port = config["port"] as? Int
                {
                    LabeledContent("Server", value: "\(host):\(port)")
                }
            } else {
                LabeledContent("Connection", value: "AnkiMobile")
            }

            if let profile = settings.defaultProfileName, !profile.isEmpty {
                LabeledContent("Profile", value: profile)
            }

            if let deck = settings.defaultDeckName, !deck.isEmpty {
                LabeledContent("Deck", value: deck)
            }

            if let model = settings.defaultModelName, !model.isEmpty {
                LabeledContent("Note Type", value: model)
            }

            if let fieldMapping = settings.modelConfiguration?.displayName, !fieldMapping.isEmpty {
                LabeledContent("Field Mapping", value: fieldMapping)
            }
        }

        Section("Duplicate Detection") {
            if settings.isAnkiConnect {
                NavigationLink {
                    DuplicateSettingsEditorView(
                        decks: [],
                        selectedDeckName: settings.defaultDeckName
                    )
                } label: {
                    LabeledContent("Scope", value: duplicateScopeDisplayName)
                }
            } else {
                Toggle("Allow Duplicate Notes", isOn: $allowDuplicates)
                    .disabled(isSavingDuplicateOptions)
            }
        }
    }
}
