// AnkiNoteFieldDetailView.swift
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

/// One field: its preview and the values that compose it, in order.
@MainActor
struct AnkiNoteFieldDetailView: View {
    let model: AnkiNoteEditorModel
    let fieldName: String

    var body: some View {
        List {
            if let field = model.field(fieldName) {
                Section("Preview") {
                    if field.previewText.isEmpty {
                        Text("Empty").foregroundStyle(.tertiary)
                    } else {
                        Text(field.previewText)
                    }
                }

                Section {
                    ForEach(field.values) { value in
                        valueRow(value)
                    }
                    .onMove { model.moveValues(in: fieldName, from: $0, to: $1) }
                    .onDelete { model.removeValues(in: fieldName, at: $0) }

                    NavigationLink {
                        AnkiValueTextEditorView(model: model, fieldName: fieldName, valueID: nil)
                    } label: {
                        Label("Add Custom HTML", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Values")
                } footer: {
                    Text("Tap a value to change it. Swipe left to remove it, or use Edit to reorder.")
                }
            }
        }
        .navigationTitle(fieldName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button("Restore") { model.restore(field: fieldName) }
                    .disabled(model.field(fieldName)?.isEdited != true)
            }
        }
    }

    @ViewBuilder
    private func valueRow(_ value: AnkiNoteDraftValue) -> some View {
        if let route = route(for: value) {
            NavigationLink {
                AnkiEditorRouteView(model: model, route: route)
            } label: {
                AnkiNoteValueRow(value: value, termGroup: model.termGroup, audioSource: model.audioSource(for: value))
            }
        } else {
            AnkiNoteValueRow(value: value, termGroup: model.termGroup, audioSource: nil)
        }
    }

    private func route(for value: AnkiNoteDraftValue) -> AnkiEditorRoute? {
        switch value.template.editorKind {
        case .text, .html: .text(field: fieldName, value: value.id)
        case .audio: .audio(field: fieldName, value: value.id)
        case .glossary: .glossary(field: fieldName, value: value.id)
        case .pitch: .pitch(field: fieldName, value: value.id)
        case .readOnly: nil
        }
    }
}

@MainActor
struct AnkiNoteValueRow: View {
    let value: AnkiNoteDraftValue
    let termGroup: GroupedSearchResults
    let audioSource: AudioLookupSource?

    private var isReadOnly: Bool {
        value.template.editorKind == .readOnly
    }

    private var isHTML: Bool {
        value.template.editorKind == .html
    }

    /// Custom HTML is shown verbatim; stripping its markup would leave nothing to see.
    private var preview: String {
        isHTML ? value.resolved.text ?? "" : value.resolved.previewText
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: value.template.editorIcon)
                .foregroundStyle(isReadOnly ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(isHTML ? String(localized: "Custom HTML") : value.template.displayName(in: termGroup))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let audioSource {
                    Text(audioSource.displayName)
                } else if preview.isEmpty {
                    Text("Empty").foregroundStyle(.tertiary)
                } else {
                    Text(preview)
                        .font(isHTML ? .body.monospaced() : .body)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Edits the text of one value, or adds a custom HTML value when `valueID` is nil.
@MainActor
struct AnkiValueTextEditorView: View {
    let model: AnkiNoteEditorModel
    let fieldName: String
    let valueID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(model: AnkiNoteEditorModel, fieldName: String, valueID: UUID?) {
        self.model = model
        self.fieldName = fieldName
        self.valueID = valueID
        let value = valueID.flatMap { model.value($0, in: fieldName) }
        _text = State(initialValue: value?.resolved.text ?? "")
    }

    private var value: AnkiNoteDraftValue? {
        valueID.flatMap { model.value($0, in: fieldName) }
    }

    private var isHTML: Bool {
        value.map { $0.template.editorKind == .html } ?? true
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(isHTML ? .body.monospaced() : .body)
                    .frame(minHeight: 160)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(isHTML)
            } footer: {
                if value?.template == .reading {
                    Text("Changing the reading clears pitch accent values in this note.")
                }
            }
        }
        .navigationTitle(value?.template.displayName(in: model.termGroup) ?? String(localized: "Custom HTML"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let valueID {
                        model.setText(text, in: fieldName, value: valueID)
                    } else if !text.isEmpty {
                        model.addCustomHTML(text, to: fieldName)
                    }
                    dismiss()
                }
            }
        }
        .onAppear { isFocused = true }
    }
}
