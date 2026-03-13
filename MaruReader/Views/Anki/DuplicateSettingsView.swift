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
    @State private var allowDuplicates: Bool = false

    var body: some View {
        Form {
            if viewModel.connectionType == .ankiMobile {
                ankiMobileContent
            } else {
                DuplicateDetectionFormSections(
                    duplicateScope: $viewModel.duplicateScope,
                    duplicateDeckName: $viewModel.duplicateDeckName,
                    duplicateIncludeChildDecks: $viewModel.duplicateIncludeChildDecks,
                    duplicateCheckAllModels: $viewModel.duplicateCheckAllModels,
                    decks: viewModel.decks,
                    selectedDeckName: viewModel.selectedDeckName
                )
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
        .onAppear {
            allowDuplicates = viewModel.duplicateScope == .none
        }
        .onChange(of: allowDuplicates) { _, newValue in
            viewModel.duplicateScope = newValue ? .none : .deck
        }
        .onChange(of: viewModel.duplicateScope) { _, newValue in
            allowDuplicates = newValue == .none
        }
    }

    private var ankiMobileContent: some View {
        Section {
            Toggle("Allow Duplicate Notes", isOn: $allowDuplicates)
        } footer: {
            Text("AnkiMobile only supports allowing or blocking all duplicates. More advanced options available with Anki-Connect.")
        }
    }
}

#Preview {
    NavigationStack {
        DuplicateSettingsView(viewModel: AnkiConfigurationViewModel())
    }
}
