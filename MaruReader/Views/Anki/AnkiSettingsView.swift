//
//  AnkiSettingsView.swift
//  MaruReader
//
//  Main Anki settings view with enable/disable toggle and configuration display.
//

import CoreData
import MaruAnki
import SwiftUI

struct AnkiSettingsView: View {
    private let persistence = AnkiPersistenceController.shared

    @State private var currentSettings: MaruAnkiSettings?
    @State private var showingConfigurationFlow = false
    @State private var showingFieldMappingManagement = false
    @State private var isLoading = true

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
                    }
                } else if currentSettings == nil {
                    Section {
                        Button("Configure Anki Integration") {
                            showingConfigurationFlow = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Anki")
        .task {
            await loadSettings()
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
        await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            self.currentSettings = try? context.fetch(request).first
            self.isLoading = false
        }
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
