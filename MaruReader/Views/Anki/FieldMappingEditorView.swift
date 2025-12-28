//
//  FieldMappingEditorView.swift
//  MaruReader
//
//  Editor for creating and editing field mapping profiles.
//

import MaruAnki
import SwiftUI

struct FieldMappingEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AnkiConfigurationViewModel
    let editingProfile: FieldMappingProfileInfo?
    var onSave: ((UUID) -> Void)?

    @State private var profileName: String = ""
    @State private var fieldMappings: [(fieldName: String, values: [TemplateValue])] = []
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showError = false

    private var isEditing: Bool { editingProfile != nil }

    var body: some View {
        Form {
            Section("Profile Name") {
                TextField("Name", text: $profileName)
            }

            Section("Field Mappings") {
                ForEach(fieldMappings.indices, id: \.self) { index in
                    fieldMappingRow(at: index)
                }
                .onDelete { indexSet in
                    fieldMappings.remove(atOffsets: indexSet)
                }

                Button {
                    fieldMappings.append((fieldName: "", values: []))
                } label: {
                    Label("Add Field", systemImage: "plus")
                }
            }

            Section {
                Text("Field names should match the fields in your Anki note type. Values will be populated from the dictionary entry.")
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
            if let profile = editingProfile {
                profileName = profile.displayName
                if let fieldMap = profile.fieldMap {
                    fieldMappings = fieldMap.map.map { (fieldName: $0.key, values: $0.value) }
                        .sorted { $0.fieldName < $1.fieldName }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
        .overlay {
            if isSaving {
                LoadingOverlay(message: "Saving...")
            }
        }
    }

    private var canSave: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !fieldMappings.isEmpty &&
            fieldMappings.allSatisfy { !$0.fieldName.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @ViewBuilder
    private func fieldMappingRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Field Name", text: Binding(
                get: { fieldMappings[index].fieldName },
                set: { fieldMappings[index].fieldName = $0 }
            ))
            .textInputAutocapitalization(.never)

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

    @ViewBuilder
    private func templateValueTag(_ value: TemplateValue, at index: Int) -> some View {
        HStack(spacing: 4) {
            Text(value.displayName)
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

    @ViewBuilder
    private func templateValueMenu(at index: Int) -> some View {
        ForEach(TemplateValueCategory.allCases, id: \.self) { category in
            Menu(category.displayName) {
                ForEach(category.values, id: \.self) { value in
                    Button(value.displayName) {
                        fieldMappings[index].values.append(value)
                    }
                }
            }
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

private enum TemplateValueCategory: CaseIterable {
    case text
    case reading
    case glossary
    case context
    case frequency
    case pitch
    case kanji

    var displayName: String {
        switch self {
        case .text: "Text"
        case .reading: "Reading"
        case .glossary: "Glossary"
        case .context: "Context"
        case .frequency: "Frequency"
        case .pitch: "Pitch Accent"
        case .kanji: "Kanji"
        }
    }

    var values: [TemplateValue] {
        switch self {
        case .text:
            [.expression, .character, .furigana, .conjugation, .partOfSpeech, .tags]
        case .reading:
            [.reading, .kunyomi, .onyomi, .onyomiAsHiragana]
        case .glossary:
            [.multiDictionaryGlossary, .glossaryNoDictionary, .dictionaryTitle]
        case .context:
            [.sentence, .sentenceFurigana, .clozePrefix, .clozeBody, .clozeSuffix, .documentTitle, .documentURL, .documentCoverImage, .screenshot]
        case .frequency:
            [.frequencyList, .singleFrequency]
        case .pitch:
            [.pitchAccentList, .singlePitchAccent, .pitchAccentDisambiguation, .pronunciationAudio]
        case .kanji:
            [.strokeCount]
        }
    }
}

extension TemplateValue {
    var displayName: String {
        switch self {
        case .singleDictionaryGlossary: "Single Dictionary Glossary"
        case .multiDictionaryGlossary: "Multi-Dictionary Glossary"
        case .pronunciationAudio: "Pronunciation Audio"
        case .character: "Character"
        case .expression: "Expression"
        case .customHTMLValue: "Custom HTML"
        case .dictionaryTitle: "Dictionary Title"
        case .furigana: "Furigana"
        case .glossaryNoDictionary: "Glossary (No Dictionary)"
        case .kunyomi: "Kunyomi"
        case .onyomi: "Onyomi"
        case .onyomiAsHiragana: "Onyomi (Hiragana)"
        case .reading: "Reading"
        case .sentence: "Sentence"
        case .clozePrefix: "Cloze Prefix"
        case .clozeBody: "Cloze Body"
        case .clozeSuffix: "Cloze Suffix"
        case .tags: "Tags"
        case .documentURL: "Document URL"
        case .screenshot: "Screenshot"
        case .documentCoverImage: "Document Cover"
        case .documentTitle: "Document Title"
        case .singlePitchAccent: "Single Pitch Accent"
        case .singlePitchAccentDictionary: "Pitch Accent (Dictionary)"
        case .pitchAccentList: "Pitch Accent List"
        case .pitchAccentDisambiguation: "Pitch Disambiguation"
        case .conjugation: "Conjugation"
        case .frequencyList: "Frequency List"
        case .singleFrequency: "Single Frequency"
        case .singleFrequencyDictionary: "Frequency (Dictionary)"
        case .frequencySortField: "Frequency Sort Field"
        case .strokeCount: "Stroke Count"
        case .partOfSpeech: "Part of Speech"
        case .sentenceFurigana: "Sentence (Furigana)"
        @unknown default: "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingEditorView(viewModel: AnkiConfigurationViewModel(), editingProfile: nil)
    }
}
