// DuplicateSettingsEditorView.swift
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
import MaruAnki
import MaruReaderCore
import os
import SwiftUI

struct DuplicateSettingsEditorView: View {
    private static let logger = Logger.maru(category: "DuplicateSettingsEditorView")
    @Environment(\.dismiss) private var dismiss
    private let persistence = AnkiPersistenceController.shared

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
            } else {
                DuplicateDetectionFormSections(
                    duplicateScope: $duplicateScope,
                    duplicateDeckName: $duplicateDeckName,
                    duplicateIncludeChildDecks: $duplicateIncludeChildDecks,
                    duplicateCheckAllModels: $duplicateCheckAllModels,
                    decks: decks,
                    selectedDeckName: selectedDeckName
                )
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

    private func loadSettings() async {
        let context = persistence.container.viewContext
        let loadedOptions: DuplicateDetectionOptions? = await context.perform {
            guard let settings = try? AnkiSettingsStore.fetchOrCreateSettings(in: context),
                  let duplicateJSON = settings.duplicateNoteSettings,
                  let data = duplicateJSON.data(using: .utf8)
            else {
                return nil
            }
            if context.hasChanges {
                try? context.save()
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
                let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: context)

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
            Self.logger.error("Failed to save duplicate settings: \(String(describing: error), privacy: .public)")
        }
    }
}

#Preview {
    NavigationStack {
        DuplicateSettingsEditorView(
            decks: [],
            selectedDeckName: "Default"
        )
    }
}
