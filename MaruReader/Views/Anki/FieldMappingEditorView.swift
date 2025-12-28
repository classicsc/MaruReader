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
    @State private var showCustomHTMLInput = false
    @State private var customHTMLText = ""
    @State private var customHTMLTargetIndex: Int?

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
        case .singleDictionaryGlossary: return "Single Dictionary Glossary"
        case .multiDictionaryGlossary: return "Multi-Dictionary Glossary"
        case .pronunciationAudio: return "Pronunciation Audio"
        case .character: return "Character"
        case .expression: return "Expression"
        case let .customHTMLValue(value):
            let truncated = value.count > 20 ? String(value.prefix(20)) + "..." : value
            return "HTML: \(truncated)"
        case .dictionaryTitle: return "Dictionary Title"
        case .furigana: return "Furigana"
        case .glossaryNoDictionary: return "Glossary (No Dictionary)"
        case .kunyomi: return "Kunyomi"
        case .onyomi: return "Onyomi"
        case .onyomiAsHiragana: return "Onyomi (Hiragana)"
        case .reading: return "Reading"
        case .sentence: return "Sentence"
        case .clozePrefix: return "Cloze Prefix"
        case .clozeBody: return "Cloze Body"
        case .clozeSuffix: return "Cloze Suffix"
        case .tags: return "Tags"
        case .documentURL: return "Document URL"
        case .screenshot: return "Screenshot"
        case .documentCoverImage: return "Document Cover"
        case .documentTitle: return "Document Title"
        case .singlePitchAccent: return "Single Pitch Accent"
        case .singlePitchAccentDictionary: return "Pitch Accent (Dictionary)"
        case .pitchAccentList: return "Pitch Accent List"
        case .pitchAccentDisambiguation: return "Pitch Disambiguation"
        case .conjugation: return "Conjugation"
        case .frequencyList: return "Frequency List"
        case .singleFrequency: return "Single Frequency"
        case .singleFrequencyDictionary: return "Frequency (Dictionary)"
        case .frequencySortField: return "Frequency Sort Field"
        case .strokeCount: return "Stroke Count"
        case .partOfSpeech: return "Part of Speech"
        case .sentenceFurigana: return "Sentence (Furigana)"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingEditorView(viewModel: AnkiConfigurationViewModel(), editingProfile: nil)
    }
}
