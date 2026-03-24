// TemplateConfigurationView.swift
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
import MaruDictionaryUICommon
import MaruReaderCore
import SwiftUI

struct TemplateConfigurationView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel
    @Environment(\.dictionaryFeatureAvailability) private var dictionaryAvailability
    @State private var availableDictionaries: [DictionaryPickerInfo] = []
    @State private var isLoadingDictionaries = true

    var body: some View {
        Form {
            if let template = viewModel.selectedTemplate {
                templateInfoSection(template)
                dictionarySection
                cardTypeSection
            }
        }
        .navigationTitle("Configure Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: String(localized: "Saving configuration..."))
            }
        }
        .task {
            if case .ready = dictionaryAvailability {
                await loadAvailableDictionaries()
            }
        }
        .onChange(of: dictionaryAvailability) { _, newValue in
            if case .ready = newValue, availableDictionaries.isEmpty {
                Task { await loadAvailableDictionaries() }
            }
        }
    }

    private func templateInfoSection(_ template: ConfigurableProfileTemplate) -> some View {
        Section {
            HStack {
                Text("Template")
                Spacer()
                Text(template.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dictionarySection: some View {
        Section {
            if case let .preparing(description) = dictionaryAvailability {
                HStack {
                    ProgressView()
                    Text(description)
                        .foregroundStyle(.secondary)
                }
            } else if case let .failed(message) = dictionaryAvailability {
                Text(message)
                    .foregroundStyle(.red)
            } else if isLoadingDictionaries {
                HStack {
                    ProgressView()
                    Text("Loading dictionaries...")
                        .foregroundStyle(.secondary)
                }
            } else if availableDictionaries.isEmpty {
                Text("No dictionaries available. Import dictionaries first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Dictionary", selection: $viewModel.templateDictionaryID) {
                    Text("Select a dictionary...").tag(nil as UUID?)
                    ForEach(availableDictionaries) { dict in
                        Text(dict.title).tag(dict.id as UUID?)
                    }
                }
            }
        } header: {
            Text("Main Definition Dictionary")
        } footer: {
            Text("Select the dictionary to use for the MainDefinition field. This is typically a bilingual dictionary like JMdict or Jitendex.")
        }
    }

    private var cardTypeSection: some View {
        Section {
            Picker("Card Type", selection: $viewModel.templateCardType) {
                ForEach(LapisCardType.allCases, id: \.self) { cardType in
                    Text(cardType.displayName).tag(cardType)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Card Type")
        } footer: {
            Text("Select the default card type for new notes. You can change this per-card in Anki by editing the corresponding Is...Card field.")
        }
    }

    private func loadAvailableDictionaries() async {
        let context = DictionaryPersistenceController.shared.newBackgroundContext()
        let termDicts = await context.perform {
            let request = NSFetchRequest<Dictionary>(entityName: "Dictionary")
            request.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO AND termCount > 0")
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

        await MainActor.run {
            availableDictionaries = termDicts
            isLoadingDictionaries = false

            // Auto-select first dictionary if none selected
            if viewModel.templateDictionaryID == nil, let first = termDicts.first {
                viewModel.templateDictionaryID = first.id
            }
        }
    }
}

#Preview {
    NavigationStack {
        TemplateConfigurationView(viewModel: {
            let vm = AnkiConfigurationViewModel()
            vm.selectTemplate("lapis")
            return vm
        }())
    }
}
