// FieldMappingEditorView.swift
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
import SwiftUI

/// Lightweight dictionary info for picker selection
struct DictionaryPickerInfo: Identifiable, Hashable {
    let id: UUID
    let title: String
    let priority: Int
    let frequencyMode: String?
}

struct FieldMappingEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AnkiConfigurationViewModel
    let editingProfile: FieldMappingProfileInfo?
    let setupFieldNames: [String]?
    var onSave: ((UUID) -> Void)?

    @State private var profileName: String = ""
    @State private var fieldMappings: [(fieldName: String, values: [TemplateValue])] = []
    @State private var didInitialize = false
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showError = false
    @State private var showCustomHTMLInput = false
    @State private var customHTMLText = ""
    @State private var customHTMLTargetIndex: Int?
    @State private var dictionaryPickerContext: DictionaryPickerContext?
    @State private var availableTermDictionaries: [DictionaryPickerInfo] = []
    @State private var availableFrequencyDictionaries: [DictionaryPickerInfo] = []

    init(
        viewModel: AnkiConfigurationViewModel,
        editingProfile: FieldMappingProfileInfo?,
        setupFieldNames: [String]? = nil,
        onSave: ((UUID) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.editingProfile = editingProfile
        self.setupFieldNames = setupFieldNames
        self.onSave = onSave
    }

    private struct DictionaryPickerContext: Identifiable {
        let id = UUID()
        let targetIndex: Int
        let purpose: DictionaryPickerPurpose
    }

    private enum DictionaryPickerPurpose {
        case glossary
        case frequency
        case frequencyRankSort
        case frequencyOccurrenceSort
    }

    private var isEditing: Bool {
        editingProfile != nil
    }

    private var isConstrainedToSetupFields: Bool {
        !isEditing && setupFieldNames != nil
    }

    var body: some View {
        Form {
            Section("Profile Name") {
                TextField("Name", text: $profileName)
            }

            Section("Field Mappings") {
                ForEach(fieldMappings.indices, id: \.self) { index in
                    fieldMappingRow(at: index)
                }
                .onDelete(perform: isConstrainedToSetupFields ? nil : { indexSet in
                    fieldMappings.remove(atOffsets: indexSet)
                })

                if !isConstrainedToSetupFields {
                    // Manual mode allows arbitrary fields.
                    Button {
                        fieldMappings.append((fieldName: "", values: []))
                    } label: {
                        Label("Add Field", systemImage: "plus")
                    }
                }
            }

            Section {
                Text(infoFooterText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(isEditing ? "Edit Field Mapping" : "New Field Mapping")
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
                .disabled(!canSave || isSaving)
            }
        }
        .onAppear {
            initializeIfNeeded()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
        .alert("Custom HTML", isPresented: $showCustomHTMLInput) {
            TextField("HTML content", text: $customHTMLText)
            Button("Cancel", role: .cancel) {
                customHTMLText = ""
                customHTMLTargetIndex = nil
            }
            Button("Add") {
                if let index = customHTMLTargetIndex, !customHTMLText.isEmpty {
                    fieldMappings[index].values.append(.customHTMLValue(value: customHTMLText))
                }
                customHTMLText = ""
                customHTMLTargetIndex = nil
            }
        } message: {
            Text("Enter the HTML content to insert into this field.")
        }
        .sheet(item: $dictionaryPickerContext) { context in
            DictionaryPickerSheet(
                dictionaries: dictionariesForPurpose(context.purpose),
                onSelect: { dictionary in
                    let templateValue: TemplateValue = switch context.purpose {
                    case .glossary:
                        .singleDictionaryGlossary(dictionaryID: dictionary.id)
                    case .frequency:
                        .singleFrequencyDictionary(dictionaryID: dictionary.id)
                    case .frequencyRankSort:
                        .frequencyRankSortField(dictionaryID: dictionary.id)
                    case .frequencyOccurrenceSort:
                        .frequencyOccurrenceSortField(dictionaryID: dictionary.id)
                    }
                    fieldMappings[context.targetIndex].values.append(templateValue)
                    dictionaryPickerContext = nil
                },
                onCancel: {
                    dictionaryPickerContext = nil
                }
            )
        }
        .task {
            await loadAvailableDictionaries()
        }
        .overlay {
            if isSaving {
                LoadingOverlay(message: String(localized: "Saving..."))
            }
        }
    }

    private func loadAvailableDictionaries() async {
        let context = DictionaryPersistenceController.shared.newBackgroundContext()
        let (termDicts, freqDicts) = await context.perform {
            let request = NSFetchRequest<Dictionary>(entityName: "Dictionary")
            request.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO")
            request.sortDescriptors = [
                NSSortDescriptor(key: "termDisplayPriority", ascending: true),
                NSSortDescriptor(key: "title", ascending: true),
            ]

            guard let results = try? context.fetch(request) else {
                return ([DictionaryPickerInfo](), [DictionaryPickerInfo]())
            }

            var termDictionaries = [DictionaryPickerInfo]()
            var frequencyDictionaries = [DictionaryPickerInfo]()

            for dict in results {
                guard let id = dict.id, let title = dict.title else { continue }

                if dict.termCount > 0 {
                    termDictionaries.append(DictionaryPickerInfo(
                        id: id,
                        title: title,
                        priority: Int(dict.termDisplayPriority),
                        frequencyMode: nil
                    ))
                }

                if dict.termFrequencyCount > 0 {
                    frequencyDictionaries.append(DictionaryPickerInfo(
                        id: id,
                        title: title,
                        priority: Int(dict.termFrequencyDisplayPriority),
                        frequencyMode: dict.frequencyMode
                    ))
                }
            }

            return (termDictionaries, frequencyDictionaries)
        }

        await MainActor.run {
            availableTermDictionaries = termDicts
            availableFrequencyDictionaries = freqDicts
        }
    }

    private func dictionariesForPurpose(_ purpose: DictionaryPickerPurpose) -> [DictionaryPickerInfo] {
        switch purpose {
        case .glossary:
            availableTermDictionaries
        case .frequency:
            availableFrequencyDictionaries
        case .frequencyRankSort:
            availableFrequencyDictionaries.filter { FrequencyModeSupport.isRankBased($0.frequencyMode) }
        case .frequencyOccurrenceSort:
            availableFrequencyDictionaries.filter { FrequencyModeSupport.isOccurrenceBased($0.frequencyMode) }
        }
    }

    private var canSave: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !fieldMappings.isEmpty &&
            fieldMappings.allSatisfy { !$0.fieldName.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var infoFooterText: String {
        if isConstrainedToSetupFields {
            String(localized: "Fields are based on the selected note type. Matching values are prefilled automatically.")
        } else {
            String(localized: "Field names should match the fields in your Anki note type. Values will be populated from the dictionary entry.")
        }
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true

        if let profile = editingProfile {
            profileName = profile.displayName
            if let fieldMap = profile.fieldMap {
                fieldMappings = fieldMap.map.map { (fieldName: $0.key, values: $0.value) }
                    .sorted { $0.fieldName < $1.fieldName }
            }
            return
        }

        if let setupFieldNames {
            fieldMappings = AnkiConfigurationViewModel.prefilledSetupFieldMappings(forNoteTypeFields: setupFieldNames)
        }
    }

    private func fieldMappingRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isConstrainedToSetupFields {
                Text(fieldMappings[index].fieldName)
                    .font(.body)
            } else {
                TextField("Field Name", text: Binding(
                    get: { fieldMappings[index].fieldName },
                    set: { fieldMappings[index].fieldName = $0 }
                ))
                .textInputAutocapitalization(.never)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(fieldMappings[index].values, id: \.self) { value in
                        templateValueTag(value, at: index)
                    }

                    Menu {
                        templateValueMenu(at: index)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func templateValueTag(_ value: TemplateValue, at index: Int) -> some View {
        HStack(spacing: 4) {
            Text(displayNameForValue(value))
                .font(.caption)
            Button {
                fieldMappings[index].values.removeAll { $0 == value }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.fill.tertiary)
        .cornerRadius(12)
    }

    private func displayNameForValue(_ value: TemplateValue) -> String {
        switch value {
        case let .singleDictionaryGlossary(dictionaryID):
            if let dictionary = availableTermDictionaries.first(where: { $0.id == dictionaryID }) {
                return AppLocalization.glossaryDictionary(dictionary.title)
            }
        case let .singleFrequencyDictionary(dictionaryID):
            if let dictionary = availableFrequencyDictionaries.first(where: { $0.id == dictionaryID }) {
                return AppLocalization.frequencyDictionary(dictionary.title)
            }
        case let .frequencyRankSortField(dictionaryID):
            if let dictionary = availableFrequencyDictionaries.first(where: { $0.id == dictionaryID }) {
                return AppLocalization.frequencyRankDictionary(dictionary.title)
            }
        case let .frequencyOccurrenceSortField(dictionaryID):
            if let dictionary = availableFrequencyDictionaries.first(where: { $0.id == dictionaryID }) {
                return AppLocalization.frequencyOccurrenceDictionary(dictionary.title)
            }
        default:
            break
        }
        return value.displayName
    }

    @ViewBuilder
    private func templateValueMenu(at index: Int) -> some View {
        ForEach(TemplateValueCategory.allCases, id: \.self) { category in
            Menu(category.displayName) {
                ForEach(category.values, id: \.self) { value in
                    Button(value.displayName) {
                        fieldMappings[index].values.append(value)
                    }
                }

                if category == .glossary {
                    Divider()
                    Button("Single Dictionary Glossary...") {
                        dictionaryPickerContext = DictionaryPickerContext(targetIndex: index, purpose: .glossary)
                    }
                    .disabled(availableTermDictionaries.isEmpty)
                }

                if category == .frequency {
                    Divider()
                    Button("Frequency (Dictionary)...") {
                        dictionaryPickerContext = DictionaryPickerContext(targetIndex: index, purpose: .frequency)
                    }
                    .disabled(availableFrequencyDictionaries.isEmpty)
                    Button("Frequency Sort (Rank)...") {
                        dictionaryPickerContext = DictionaryPickerContext(targetIndex: index, purpose: .frequencyRankSort)
                    }
                    .disabled(dictionariesForPurpose(.frequencyRankSort).isEmpty)
                    Button("Frequency Sort (Occurrence)...") {
                        dictionaryPickerContext = DictionaryPickerContext(targetIndex: index, purpose: .frequencyOccurrenceSort)
                    }
                    .disabled(dictionariesForPurpose(.frequencyOccurrenceSort).isEmpty)
                }
            }
        }

        Divider()

        Button("Custom HTML...") {
            customHTMLTargetIndex = index
            showCustomHTMLInput = true
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedName = profileName.trimmingCharacters(in: .whitespaces)
        var mapDict: [String: [TemplateValue]] = [:]
        for mapping in fieldMappings {
            let fieldName = mapping.fieldName.trimmingCharacters(in: .whitespaces)
            if !fieldName.isEmpty {
                mapDict[fieldName] = mapping.values
            }
        }
        let fieldMap = AnkiFieldMap(map: mapDict)

        do {
            if let profile = editingProfile {
                try await viewModel.updateFieldMappingProfile(id: profile.id, name: trimmedName, fieldMap: fieldMap)
                dismiss()
            } else {
                let newID = try await viewModel.createFieldMappingProfile(name: trimmedName, fieldMap: fieldMap)
                onSave?(newID)
                dismiss()
            }
        } catch {
            self.error = error
            self.showError = true
        }
    }
}

// MARK: - Template Value Helpers

enum TemplateValueCategory: CaseIterable {
    case text
    case reading
    case glossary
    case context
    case frequency
    case pitch

    var displayName: String {
        switch self {
        case .text: String(localized: "Text")
        case .reading: String(localized: "Reading")
        case .glossary: String(localized: "Glossary")
        case .context: String(localized: "Context")
        case .frequency: String(localized: "Frequency")
        case .pitch: String(localized: "Pitch Accent")
        }
    }

    var values: [TemplateValue] {
        switch self {
        case .text:
            [.expression, .furigana, .partOfSpeech, .tags]
        case .reading:
            [.reading]
        case .glossary:
            [.singleGlossary, .multiDictionaryGlossary, .glossaryNoDictionary]
        case .context:
            [
                .sentence,
                .sentenceFurigana,
                .clozePrefix,
                .clozeBody,
                .clozeSuffix,
                .clozeFuriganaPrefix,
                .clozeFuriganaBody,
                .clozeFuriganaSuffix,
                .contextInfo,
                .contextImage,
            ]
        case .frequency:
            [.frequencyList, .singleFrequency, .frequencyRankHarmonicMeanSortField, .frequencyOccurrenceHarmonicMeanSortField]
        case .pitch:
            [.pitchAccentList, .singlePitchAccent, .pitchAccentDisambiguation, .pitchAccentCategories, .pronunciationAudio]
        }
    }
}

extension TemplateValue {
    var displayName: String {
        switch self {
        case let .singleDictionaryGlossary(dictionaryID):
            let shortID = String(dictionaryID.uuidString.prefix(8))
            return AppLocalization.glossaryIdentifier(shortID)
        case .singleGlossary: return String(localized: "Single Glossary (First Dictionary)")
        case .multiDictionaryGlossary: return String(localized: "Multi-Dictionary Glossary")
        case .pronunciationAudio: return String(localized: "Pronunciation Audio")
        case .expression: return String(localized: "Expression")
        case let .customHTMLValue(value):
            let truncated = value.count > 20 ? String(value.prefix(20)) + "..." : value
            return AppLocalization.htmlPreview(truncated)
        case .furigana: return String(localized: "Furigana")
        case .glossaryNoDictionary: return String(localized: "Glossary (No Dictionary)")
        case .reading: return String(localized: "Reading")
        case .sentence: return String(localized: "Sentence")
        case .clozePrefix: return String(localized: "Cloze Prefix")
        case .clozeBody: return String(localized: "Cloze Body")
        case .clozeSuffix: return String(localized: "Cloze Suffix")
        case .clozeFuriganaPrefix: return String(localized: "Cloze Furigana Prefix")
        case .clozeFuriganaBody: return String(localized: "Cloze Furigana Body")
        case .clozeFuriganaSuffix: return String(localized: "Cloze Furigana Suffix")
        case .tags: return String(localized: "Tags")
        case .contextImage: return String(localized: "Context Image")
        case .contextInfo: return String(localized: "Context Info")
        case .singlePitchAccent: return String(localized: "Single Pitch Accent")
        case .singlePitchAccentDictionary: return String(localized: "Pitch Accent (Dictionary)")
        case .pitchAccentList: return String(localized: "Pitch Accent List")
        case .pitchAccentDisambiguation: return String(localized: "Pitch Disambiguation")
        case .pitchAccentCategories: return String(localized: "Pitch Accent Categories")
        case .conjugation: return String(localized: "Conjugation")
        case .frequencyList: return String(localized: "Frequency List")
        case .singleFrequency: return String(localized: "Single Frequency")
        case .singleFrequencyDictionary: return String(localized: "Frequency (Dictionary)")
        case .frequencyRankSortField: return String(localized: "Frequency Sort (Rank)")
        case .frequencyOccurrenceSortField: return String(localized: "Frequency Sort (Occurrence)")
        case .frequencyRankHarmonicMeanSortField: return String(localized: "Frequency Sort (Rank HM)")
        case .frequencyOccurrenceHarmonicMeanSortField: return String(localized: "Frequency Sort (Occ HM)")
        case .partOfSpeech: return String(localized: "Part of Speech")
        case .sentenceFurigana: return String(localized: "Sentence (Furigana)")
        @unknown default: return String(localized: "Unknown")
        }
    }
}

// MARK: - Dictionary Picker Sheet

private struct DictionaryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let dictionaries: [DictionaryPickerInfo]
    let onSelect: (DictionaryPickerInfo) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if dictionaries.isEmpty {
                    ContentUnavailableView(
                        "No Dictionaries",
                        systemImage: "book.closed",
                        description: Text("Import term dictionaries to use single dictionary glossary")
                    )
                } else {
                    Section {
                        ForEach(dictionaries) { dictionary in
                            Button {
                                onSelect(dictionary)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(dictionary.title)
                                            .foregroundStyle(.primary)
                                        Text(AppLocalization.priority(dictionary.priority))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    } footer: {
                        Text("Select a dictionary for the glossary. If this dictionary has no result for a term, the highest priority dictionary will be used as a fallback.")
                    }
                }
            }
            .navigationTitle("Select Dictionary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingEditorView(viewModel: AnkiConfigurationViewModel(), editingProfile: nil)
    }
}
