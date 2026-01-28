// DuplicateSettingsEditorView.swift
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

import CoreData
import MaruAnki
import SwiftUI

struct DuplicateSettingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let persistence = AnkiPersistenceController.shared

    let isAnkiConnect: Bool
    let decks: [AnkiDeckMeta]
    let selectedDeckName: String?

    @State private var duplicateScope: DuplicateNoteScope = .deck
    @State private var duplicateDeckName: String?
    @State private var duplicateIncludeChildDecks: Bool = false
    @State private var duplicateCheckAllModels: Bool = false
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else if isAnkiConnect {
                ankiConnectContent
            } else {
                ankiMobileContent
            }
        }
        .navigationTitle("Duplicate Detection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving)
            }
        }
        .task {
            await loadSettings()
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
            Picker("Duplicate Check Scope", selection: $duplicateScope) {
                Text("Allow Duplicates").tag(DuplicateNoteScope.none)
                Text("Check in Deck").tag(DuplicateNoteScope.deck)
                Text("Check Entire Collection").tag(DuplicateNoteScope.collection)
            }
        } footer: {
            switch duplicateScope {
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

        if duplicateScope == .deck {
            Section {
                Picker("Deck", selection: $duplicateDeckName) {
                    Text("Target Deck (\(selectedDeckName ?? ""))").tag(nil as String?)
                    ForEach(decks, id: \.name) { deck in
                        Text(deck.name).tag(deck.name as String?)
                    }
                }

                Toggle("Include Child Decks", isOn: $duplicateIncludeChildDecks)
            } header: {
                Text("Deck to Check")
            } footer: {
                Text("When enabled, child decks of the selected deck will also be checked for duplicates.")
            }
        }

        Section {
            Toggle("Check All Note Types", isOn: $duplicateCheckAllModels)
        } footer: {
            if duplicateCheckAllModels {
                Text("Duplicates will be detected across all note types in your collection.")
            } else {
                Text("Only notes of the same type will be checked for duplicates.")
            }
        }
    }

    private var allowDuplicatesBinding: Binding<Bool> {
        Binding(
            get: { duplicateScope == .none },
            set: { allowDuplicates in
                duplicateScope = allowDuplicates ? .none : .deck
            }
        )
    }

    private func loadSettings() async {
        let context = persistence.container.viewContext
        let loadedOptions: DuplicateDetectionOptions? = await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            guard let settings = try? context.fetch(request).first,
                  let duplicateJSON = settings.duplicateNoteSettings,
                  let data = duplicateJSON.data(using: .utf8)
            else {
                return nil
            }
            return try? JSONDecoder().decode(DuplicateDetectionOptions.self, from: data)
        }

        if let options = loadedOptions {
            self.duplicateScope = options.scope
            self.duplicateDeckName = options.deckName
            self.duplicateIncludeChildDecks = options.includeChildDecks
            self.duplicateCheckAllModels = options.checkAllModels
        }

        isLoading = false
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let scopeValue = duplicateScope
        let deckNameValue = duplicateDeckName
        let includeChildDecksValue = duplicateIncludeChildDecks
        let checkAllModelsValue = duplicateCheckAllModels

        let context = persistence.newBackgroundContext()
        do {
            try await context.perform {
                let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
                request.fetchLimit = 1
                guard let settings = try context.fetch(request).first else {
                    return
                }

                let options = DuplicateDetectionOptions(
                    scope: scopeValue,
                    deckName: deckNameValue,
                    includeChildDecks: includeChildDecksValue,
                    checkAllModels: checkAllModelsValue
                )

                let encoder = JSONEncoder()
                let data = try encoder.encode(options)
                settings.duplicateNoteSettings = String(data: data, encoding: .utf8)

                try context.save()
            }
            dismiss()
        } catch {
            // Error handling - for now just log
            print("Failed to save duplicate settings: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        DuplicateSettingsEditorView(
            isAnkiConnect: true,
            decks: [],
            selectedDeckName: "Default"
        )
    }
}
