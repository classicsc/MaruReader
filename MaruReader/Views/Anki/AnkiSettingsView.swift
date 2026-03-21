// AnkiSettingsView.swift
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

struct AnkiSettingsView: View {
    private static let logger = Logger.maru(category: "AnkiSettingsView")
    private let persistence = AnkiPersistenceController.shared
    private let noteService = AnkiNoteService()

    @State private var currentSettings: MaruAnkiSettings?
    @State private var isAnkiEnabled = false
    @State private var showingConfigurationFlow = false
    @State private var showingFieldMappingManagement = false
    @State private var isLoading = true
    @State private var pendingCount = 0
    @State private var duplicateOptions: DuplicateDetectionOptions?
    @State private var isSavingDuplicateOptions = false
    @State private var allowDuplicates = false

    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else {
                Section {
                    Toggle("Enable Anki Integration", isOn: $isAnkiEnabled)
                }

                if let settings = currentSettings {
                    if isAnkiEnabled {
                        AnkiConfigurationSectionView(
                            settings: settings,
                            duplicateScopeDisplayName: duplicateScopeDisplayName,
                            allowDuplicates: $allowDuplicates,
                            isSavingDuplicateOptions: isSavingDuplicateOptions
                        )

                        Section {
                            Button("Edit Configuration") {
                                showingConfigurationFlow = true
                            }
                            Button("Manage Field Mappings") {
                                showingFieldMappingManagement = true
                            }
                            NavigationLink("Context Image Settings") {
                                ContextImageSettingsView()
                            }
                        }
                    }

                    Section("Pending Notes") {
                        NavigationLink {
                            PendingNotesView()
                        } label: {
                            Label("Pending Notes", systemImage: "tray")
                        }
                        .badge(pendingCount)
                    }
                }
            }
        }
        .navigationTitle("Anki")
        .task {
            await loadSettings()
        }
        .onChange(of: isAnkiEnabled) { _, newValue in
            guard currentSettings?.ankiEnabled != newValue else { return }
            if let settings = currentSettings {
                settings.ankiEnabled = newValue
                try? persistence.container.viewContext.save()
                Task {
                    await loadSettings()
                }
            } else if newValue {
                showingConfigurationFlow = true
            }
        }
        .onChange(of: allowDuplicates) { _, newValue in
            let currentScope = duplicateOptions?.scope ?? .deck
            let newScope: DuplicateNoteScope = newValue ? .none : .deck
            guard currentScope != newScope else { return }
            let currentOptions = duplicateOptions ?? DuplicateDetectionOptions(
                scope: .deck,
                deckName: nil,
                includeChildDecks: false,
                checkAllModels: false
            )
            let updatedOptions = DuplicateDetectionOptions(
                scope: newValue ? .none : .deck,
                deckName: currentOptions.deckName,
                includeChildDecks: currentOptions.includeChildDecks,
                checkAllModels: currentOptions.checkAllModels
            )

            duplicateOptions = updatedOptions
            Task {
                await saveDuplicateOptions(updatedOptions)
            }
        }
        .refreshable {
            await loadSettings()
        }
        .sheet(isPresented: $showingConfigurationFlow, onDismiss: {
            Task {
                await loadSettings()
            }
        }) {
            NavigationStack {
                AnkiConfigurationFlowView()
            }
        }
        .sheet(isPresented: $showingFieldMappingManagement, onDismiss: {
            Task {
                await loadSettings()
            }
        }) {
            NavigationStack {
                FieldMappingManagementView()
            }
        }
    }

    private func loadSettings() async {
        let context = persistence.container.viewContext
        let (fetchedSettings, parsedDuplicateOptions): (MaruAnkiSettings?, DuplicateDetectionOptions?) = await context.perform {
            guard let settings = try? AnkiSettingsStore.fetchOrCreateSettings(in: context) else {
                return (nil, nil)
            }
            if context.hasChanges {
                try? context.save()
            }

            var options: DuplicateDetectionOptions?
            if let duplicateJSON = settings.duplicateNoteSettings,
               let data = duplicateJSON.data(using: .utf8)
            {
                options = try? JSONDecoder().decode(DuplicateDetectionOptions.self, from: data)
            }

            return (settings, options)
        }
        currentSettings = fetchedSettings
        isAnkiEnabled = fetchedSettings?.ankiEnabled ?? false
        duplicateOptions = parsedDuplicateOptions
        allowDuplicates = parsedDuplicateOptions?.scope == DuplicateNoteScope.none
        pendingCount = await noteService.pendingNoteCount()
        isLoading = false
    }

    private func saveDuplicateOptions(_ options: DuplicateDetectionOptions) async {
        isSavingDuplicateOptions = true
        defer { isSavingDuplicateOptions = false }

        let context = persistence.newBackgroundContext()

        do {
            try await context.perform {
                let settings = try AnkiSettingsStore.fetchOrCreateSettings(in: context)

                let data = try JSONEncoder().encode(options)
                settings.duplicateNoteSettings = String(data: data, encoding: .utf8)
                try context.save()
            }
            await loadSettings()
        } catch {
            await loadSettings()
            Self.logger.error("Failed to save duplicate settings: \(String(describing: error), privacy: .public)")
        }
    }

    private var duplicateScopeDisplayName: String {
        guard let options = duplicateOptions else {
            return String(localized: "Not Configured")
        }
        switch options.scope {
        case .none:
            return String(localized: "Allow Duplicates")
        case .deck:
            if let deckName = options.deckName {
                return AppLocalization.checkInDeck(deckName)
            }
            return String(localized: "Check in Target Deck")
        case .collection:
            return String(localized: "Check Entire Collection")
        @unknown default:
            return String(localized: "Unknown")
        }
    }
}

#Preview {
    NavigationStack {
        AnkiSettingsView()
    }
}
