//
//  TemplateConfigurationSheetView.swift
//  MaruReader
//
//  Sheet view for configuring a template profile from the management view.
//

import CoreData
import MaruAnki
import MaruReaderCore
import SwiftUI

struct TemplateConfigurationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let template: ConfigurableProfileTemplate
    let onSave: () -> Void

    @State private var selectedDictionaryID: UUID?
    @State private var selectedCardType: LapisCardType = .vocabularyCard
    @State private var availableDictionaries: [DictionaryPickerInfo] = []
    @State private var isLoadingDictionaries = true
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        Form {
            templateInfoSection
            dictionarySection
            cardTypeSection
        }
        .navigationTitle("Configure \(template.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(selectedDictionaryID == nil || isSaving)
            }
        }
        .overlay {
            if isSaving {
                LoadingOverlay(message: "Saving...")
            }
        }
        .task {
            await loadConfiguration()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var templateInfoSection: some View {
        Section {
            HStack {
                Text("Template")
                Spacer()
                Text(template.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dictionarySection: some View {
        Section {
            if isLoadingDictionaries {
                HStack {
                    ProgressView()
                    Text("Loading dictionaries...")
                        .foregroundStyle(.secondary)
                }
            } else if availableDictionaries.isEmpty {
                Text("No dictionaries available. Import dictionaries first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Dictionary", selection: $selectedDictionaryID) {
                    Text("Select a dictionary...").tag(nil as UUID?)
                    ForEach(availableDictionaries) { dict in
                        Text(dict.title).tag(dict.id as UUID?)
                    }
                }
            }
        } header: {
            Text("Main Definition Dictionary")
        } footer: {
            Text("Select the dictionary to use for the MainDefinition field.")
        }
    }

    @ViewBuilder
    private var cardTypeSection: some View {
        Section {
            Picker("Card Type", selection: $selectedCardType) {
                ForEach(LapisCardType.allCases, id: \.self) { cardType in
                    Text(cardType.displayName).tag(cardType)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Card Type")
        } footer: {
            Text("Select the default card type for new notes.")
        }
    }

    private func loadConfiguration() async {
        // Load dictionaries
        let context = DictionaryPersistenceController.shared.newBackgroundContext()
        let termDicts = await context.perform {
            let request = NSFetchRequest<Dictionary>(entityName: "Dictionary")
            request.predicate = NSPredicate(format: "isComplete == YES AND termCount > 0")
            request.sortDescriptors = [
                NSSortDescriptor(key: "termDisplayPriority", ascending: true),
                NSSortDescriptor(key: "title", ascending: true),
            ]

            guard let results = try? context.fetch(request) else {
                return [DictionaryPickerInfo]()
            }

            return results.compactMap { dict -> DictionaryPickerInfo? in
                guard let id = dict.id, let title = dict.title else { return nil }
                return DictionaryPickerInfo(
                    id: id,
                    title: title,
                    priority: Int(dict.termDisplayPriority),
                    frequencyMode: nil
                )
            }
        }

        // Load existing configuration
        let ankiContext = AnkiPersistenceController.shared.newBackgroundContext()
        let existingConfig = await SystemProfileManager.getConfiguredProfileData(for: template.id, in: ankiContext)

        await MainActor.run {
            availableDictionaries = termDicts
            isLoadingDictionaries = false

            if let config = existingConfig {
                selectedDictionaryID = config.mainDefinitionDictionaryID
                selectedCardType = config.lapisCardType ?? .vocabularyCard
            } else if let first = termDicts.first {
                selectedDictionaryID = first.id
            }
        }
    }

    private func save() async {
        guard let dictionaryID = selectedDictionaryID else { return }

        isSaving = true

        let context = AnkiPersistenceController.shared.newBackgroundContext()

        do {
            // Build the field map from template + configuration
            let fieldMap = template.buildFieldMap(
                mainDefinitionDictionaryID: dictionaryID,
                cardType: selectedCardType
            )

            // Create configuration data
            let configuration = ConfiguredProfileData(
                templateID: template.id,
                mainDefinitionDictionaryID: dictionaryID,
                cardType: selectedCardType
            )

            // Save the configured profile
            _ = try await SystemProfileManager.saveConfiguredProfile(
                templateID: template.id,
                fieldMap: fieldMap,
                configuration: configuration,
                in: context
            )

            await MainActor.run {
                isSaving = false
                onSave()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                self.error = error
                showError = true
            }
        }
    }
}

extension ConfigurableProfileTemplate: Identifiable {}

#Preview {
    NavigationStack {
        TemplateConfigurationSheetView(
            template: ConfigurableProfileTemplates.lapis,
            onSave: {}
        )
    }
}
