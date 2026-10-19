// AnkiNoteValuePickers.swift
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

import MaruAnki
import MaruReaderCore
import SwiftUI

/// Chooses the clip for a pronunciation audio value, with previews.
@MainActor
struct AnkiAudioPickerView: View {
    let model: AnkiNoteEditorModel
    let fieldName: String
    let valueID: UUID

    @Environment(\.dismiss) private var dismiss

    private var selectedURL: String? {
        model.value(valueID, in: fieldName)?.resolved.mediaFiles.values.first?.absoluteString
    }

    var body: some View {
        List {
            Section {
                if model.isLoadingAudioSources {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if model.audioSources.isEmpty {
                    Text(String(localized: "No audio found for this term.", bundle: .dictionaryUICommon))
                        .foregroundStyle(.secondary)
                }
                ForEach(model.audioSources, id: \.self) { source in
                    Button {
                        select(URL(string: source.url))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.providerName)
                                    .foregroundStyle(.primary)
                                if let detail = source.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let url = URL(string: source.url) {
                                AudioPlayButton(player: model.audioPlayer, url: url)
                            }
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .opacity(source.url == selectedURL ? 1 : 0)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Clips for \(model.termGroup.displayTerm)", bundle: .dictionaryUICommon))
            } footer: {
                Text(String(localized: "Play to preview. Tap a row to use that clip in the note.", bundle: .dictionaryUICommon))
            }

            Section {
                Button {
                    select(nil)
                } label: {
                    Label(String(localized: "Leave the field empty", bundle: .dictionaryUICommon), systemImage: "speaker.slash")
                        .foregroundStyle(.primary)
                }
            }
        }
        .ankiEditorSheetBackground()
        .navigationTitle(fieldName)
        .navigationBarTitleDisplayMode(.inline)
        .task { model.loadAudioSources() }
        .onDisappear { model.audioPlayer.stop() }
    }

    private func select(_ url: URL?) {
        model.setAudio(url, in: fieldName, value: valueID)
        dismiss()
    }
}

extension AudioLookupSource {
    var detail: String? {
        var parts: [String] = []
        if let itemName, !itemName.isEmpty {
            parts.append(itemName)
        }
        if let pitch, !pitch.isEmpty {
            parts.append("[\(pitch)]")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

/// Chooses the dictionary and format of a glossary value; changes apply as they are made.
@MainActor
struct AnkiGlossaryPickerView: View {
    let model: AnkiNoteEditorModel
    let fieldName: String
    let valueID: UUID

    /// nil selects every dictionary with results.
    @State private var dictionaryID: UUID?
    @State private var includeTitle: Bool
    @State private var plain: Bool

    init(model: AnkiNoteEditorModel, fieldName: String, valueID: UUID) {
        self.model = model
        self.fieldName = fieldName
        self.valueID = valueID
        let template = model.value(valueID, in: fieldName)?.template
        let options = template?.glossaryOptions ?? (includeTitle: true, plain: false)
        _includeTitle = State(initialValue: options.includeTitle)
        _plain = State(initialValue: options.plain)
        _dictionaryID = State(initialValue: Self.initialDictionaryID(for: template, in: model.termGroup))
    }

    private static func initialDictionaryID(for template: TemplateValue?, in termGroup: GroupedSearchResults) -> UUID? {
        switch template {
        case .multiDictionaryGlossary, .multiDictionaryGlossaryNoDictionary,
             .multiDictionaryGlossaryPlain, .multiDictionaryGlossaryPlainNoDictionary:
            return nil
        case let template?:
            // Single dictionary values fall back to the first dictionary when theirs has no result.
            let requested = template.dictionaryID
            let available = termGroup.dictionariesResults.map(\.dictionaryUUID)
            return requested.flatMap { available.contains($0) ? $0 : nil } ?? available.first
        case nil:
            return nil
        }
    }

    private var template: TemplateValue {
        if let dictionaryID {
            return .singleDictionaryGlossary(dictionaryID: dictionaryID, includeTitle: includeTitle, plain: plain)
        }
        return .multiDictionaryGlossary(includeTitle: includeTitle, plain: plain)
    }

    var body: some View {
        List {
            Section("Dictionary") {
                ForEach(model.termGroup.dictionariesResults) { results in
                    dictionaryRow(title: results.dictionaryTitle, preview: results.combinedHTML, id: results.dictionaryUUID)
                }
                dictionaryRow(title: String(localized: "All dictionaries", bundle: .dictionaryUICommon), preview: nil, id: nil)
            }

            Section {
                Toggle(String(localized: "Dictionary title", bundle: .dictionaryUICommon), isOn: $includeTitle)
                Toggle(String(localized: "Plain text", bundle: .dictionaryUICommon), isOn: $plain)
            } header: {
                Text("Format")
            } footer: {
                Text(String(localized: "Changes apply to this note only.", bundle: .dictionaryUICommon))
            }

            Section(String(localized: "Preview", bundle: .dictionaryUICommon)) {
                let resolved = model.value(valueID, in: fieldName)?.resolved ?? .empty
                AnkiNotePreview(html: resolved.previewHTML, text: resolved.previewText)
            }
        }
        .ankiEditorSheetBackground()
        .navigationTitle(fieldName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: template) {
            await model.setTemplate(template, in: fieldName, value: valueID)
        }
    }

    private func dictionaryRow(title: String, preview: String?, id: UUID?) -> some View {
        Button {
            dictionaryID = id
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let preview {
                        Text(TemplateResolvedValue.text(preview).previewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .opacity(dictionaryID == id ? 1 : 0)
            }
        }
    }
}

/// Chooses which pitch accent dictionary a single pitch accent value comes from.
@MainActor
struct AnkiPitchPickerView: View {
    let model: AnkiNoteEditorModel
    let fieldName: String
    let valueID: UUID

    @Environment(\.dismiss) private var dismiss

    private var selectedDictionaryID: UUID? {
        let template = model.value(valueID, in: fieldName)?.template
        return template?.dictionaryID ?? model.termGroup.pitchAccentResults.first?.dictionaryID
    }

    var body: some View {
        List {
            Section("Dictionary") {
                if model.termGroup.pitchAccentResults.isEmpty {
                    Text(String(localized: "No pitch accent found for this term.", bundle: .dictionaryUICommon))
                        .foregroundStyle(.secondary)
                }
                ForEach(model.termGroup.pitchAccentResults) { results in
                    Button {
                        Task {
                            await model.setTemplate(.singlePitchAccentDictionary(dictionaryID: results.dictionaryID), in: fieldName, value: valueID)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(results.dictionaryTitle)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(results.pitches.map(Self.format).joined(separator: ", "))
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .opacity(results.dictionaryID == selectedDictionaryID ? 1 : 0)
                        }
                    }
                }
            }
        }
        .ankiEditorSheetBackground()
        .navigationTitle(fieldName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func format(_ pitch: PitchAccent) -> String {
        switch pitch.position {
        case let .mora(position): String(position)
        case let .pattern(pattern): pattern
        @unknown default: ""
        }
    }
}
