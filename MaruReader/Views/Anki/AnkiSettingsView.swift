// AnkiSettingsView.swift
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

struct AnkiSettingsView: View {
    private let persistence = AnkiPersistenceController.shared
    private let noteService = AnkiNoteService()

    @State private var currentSettings: MaruAnkiSettings?
    @State private var showingConfigurationFlow = false
    @State private var showingFieldMappingManagement = false
    @State private var isLoading = true
    @State private var pendingCount = 0

    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else {
                Section {
                    Toggle("Enable Anki Integration", isOn: ankiEnabledBinding)
                }

                if let settings = currentSettings, settings.ankiEnabled {
                    configurationSection(settings: settings)

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
                } else if currentSettings == nil {
                    Section {
                        Button("Configure Anki Integration") {
                            showingConfigurationFlow = true
                        }
                    }
                }

                Section("Pending Notes") {
                    if pendingCount > 0 {
                        NavigationLink(destination: PendingNotesView()) {
                            Label("Pending Notes", systemImage: "tray")
                        }
                        .badge(pendingCount)
                    } else {
                        NavigationLink(destination: PendingNotesView()) {
                            Label("Pending Notes", systemImage: "tray")
                        }
                    }
                }
            }
        }
        .navigationTitle("Anki")
        .task {
            await loadSettings()
        }
        .onAppear {
            Task {
                await loadSettings()
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
        let fetchedSettings: MaruAnkiSettings? = await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            return try? context.fetch(request).first
        }
        currentSettings = fetchedSettings
        pendingCount = await noteService.pendingNoteCount()
        isLoading = false
    }

    @ViewBuilder
    private func configurationSection(settings: MaruAnkiSettings) -> some View {
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
    }

    private var ankiEnabledBinding: Binding<Bool> {
        Binding(
            get: { currentSettings?.ankiEnabled ?? false },
            set: { newValue in
                if let settings = currentSettings {
                    settings.ankiEnabled = newValue
                    try? persistence.container.viewContext.save()
                } else if newValue {
                    // No settings exist, show config flow to create them
                    showingConfigurationFlow = true
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        AnkiSettingsView()
    }
}
