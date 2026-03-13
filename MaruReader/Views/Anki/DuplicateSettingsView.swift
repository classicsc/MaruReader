// DuplicateSettingsView.swift
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

struct DuplicateSettingsView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        Form {
            if viewModel.connectionType == .ankiMobile {
                ankiMobileContent
            } else {
                ankiConnectContent
            }
        }
        .navigationTitle("Duplicate Detection")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed)
            }
        }
    }

    private var ankiMobileContent: some View {
        Section {
            Toggle("Allow Duplicate Notes", isOn: allowDuplicatesBinding)
        } footer: {
            Text("AnkiMobile only supports allowing or blocking all duplicates. More advanced options available with Anki-Connect.")
        }
    }

    @ViewBuilder
    private var ankiConnectContent: some View {
        Section {
            Picker("Duplicate Check Scope", selection: $viewModel.duplicateScope) {
                Text("Allow Duplicates").tag(DuplicateNoteScope.none)
                Text("Check in Deck").tag(DuplicateNoteScope.deck)
                Text("Check Entire Collection").tag(DuplicateNoteScope.collection)
            }
        } footer: {
            switch viewModel.duplicateScope {
            case .none:
                Text("Duplicate notes will be created without warning.")
            case .deck:
                Text("Notes with matching content in the specified deck will be rejected.")
            case .collection:
                Text("Notes with matching content anywhere in your collection will be rejected.")
            @unknown default:
                EmptyView()
            }
        }

        if viewModel.duplicateScope == .deck {
            Section {
                Picker("Deck", selection: $viewModel.duplicateDeckName) {
                    Text("Target Deck (\(viewModel.selectedDeckName ?? ""))").tag(nil as String?)
                    ForEach(viewModel.decks, id: \.name) { deck in
                        Text(deck.name).tag(deck.name as String?)
                    }
                }

                Toggle("Include Child Decks", isOn: $viewModel.duplicateIncludeChildDecks)
            } header: {
                Text("Deck to Check")
            } footer: {
                Text("When enabled, child decks of the selected deck will also be checked for duplicates.")
            }
        }

        Section {
            Toggle("Check All Note Types", isOn: $viewModel.duplicateCheckAllModels)
        } footer: {
            if viewModel.duplicateCheckAllModels {
                Text("Duplicates will be detected across all note types in your collection.")
            } else {
                Text("Only notes of the same type will be checked for duplicates.")
            }
        }
    }

    private var allowDuplicatesBinding: Binding<Bool> {
        Binding(
            get: { viewModel.duplicateScope == .none },
            set: { allowDuplicates in
                viewModel.duplicateScope = allowDuplicates ? .none : .deck
            }
        )
    }
}

#Preview {
    NavigationStack {
        DuplicateSettingsView(viewModel: AnkiConfigurationViewModel())
    }
}
