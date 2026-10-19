// AnkiNoteEditorView.swift
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

/// Screens pushed from a field's value list. The editor is reached through a bool-presented
/// destination, so pushes stay view-based: a value push would reset that presentation.
enum AnkiEditorRoute: Hashable {
    /// A nil value adds a new text value to the field.
    case text(field: String, value: UUID?)
    case audio(field: String, value: UUID)
    case glossary(field: String, value: UUID)
    case pitch(field: String, value: UUID)
}

/// Overview of the note: one row per field, pushed onto the dictionary navigation stack.
@MainActor
struct AnkiNoteEditorView: View {
    let model: AnkiNoteEditorModel
    @Environment(\.dictionaryPresentationTheme) private var presentationTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(model.editableFields) { field in
                    NavigationLink {
                        AnkiNoteFieldDetailView(model: model, fieldName: field.name)
                    } label: {
                        AnkiNoteFieldRow(model: model, field: field)
                    }
                }
            } footer: {
                if model.isDuplicate {
                    Text("Anki already has a note for this term. Adding it again creates a duplicate.")
                }
            }

            if !model.automaticFields.isEmpty {
                Section("Filled automatically") {
                    ForEach(model.automaticFields) { field in
                        NavigationLink {
                            AnkiNoteFieldDetailView(model: model, fieldName: field.name)
                        } label: {
                            AnkiNoteFieldRow(model: model, field: field)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Note")
        .navigationSubtitle(model.termGroup.displayTerm)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.isSubmitting {
                    ProgressView()
                } else {
                    Button(model.isDuplicate ? "Add Duplicate" : "Add") {
                        // Pops itself: when this view is nested in another pushed destination,
                        // its presentation binding going false no longer pops it.
                        Task {
                            if await model.submit() {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .alert("Couldn't Add Note", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: {
                if !$0 {
                    model.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .ankiEditorSheetBackground()
        .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
        .onDisappear { model.audioPlayer.stop() }
        .accessibilityIdentifier("anki.noteEditor")
    }
}

/// The screen for a value route.
@MainActor
struct AnkiEditorRouteView: View {
    let model: AnkiNoteEditorModel
    let route: AnkiEditorRoute

    var body: some View {
        switch route {
        case let .text(field, value):
            AnkiValueTextEditorView(model: model, fieldName: field, valueID: value)
        case let .audio(field, value):
            AnkiAudioPickerView(model: model, fieldName: field, valueID: value)
        case let .glossary(field, value):
            AnkiGlossaryPickerView(model: model, fieldName: field, valueID: value)
        case let .pitch(field, value):
            AnkiPitchPickerView(model: model, fieldName: field, valueID: value)
        }
    }
}

/// Field name over a plain text summary; audio fields name the clip and can play it inline.
@MainActor
struct AnkiNoteFieldRow: View {
    let model: AnkiNoteEditorModel
    let field: AnkiNoteDraftField

    private var audioValue: AnkiNoteDraftValue? {
        field.values.first { $0.template.editorKind == .audio && !$0.resolved.mediaFiles.isEmpty }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if field.isEdited {
                        Circle().fill(.tint).frame(width: 7, height: 7)
                    }
                    Text(field.name)
                        .font(.caption)
                        .foregroundStyle(field.isEdited ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                if let audioValue, let source = model.audioSource(for: audioValue) {
                    Label(source.displayName, systemImage: "speaker.wave.2")
                } else if field.previewText.isEmpty {
                    Text("Empty")
                        .foregroundStyle(.tertiary)
                } else {
                    Text(field.previewText)
                        .lineLimit(2)
                }
            }

            if let audioURL = audioValue?.resolved.mediaFiles.values.first {
                Spacer()
                AudioPlayButton(player: model.audioPlayer, url: audioURL)
            }
        }
        .task(id: audioValue?.id) {
            if audioValue != nil {
                model.loadAudioSources()
            }
        }
    }
}

@MainActor
struct AudioPlayButton: View {
    let player: AudioPreviewPlayer
    let url: URL

    var body: some View {
        Button {
            player.toggle(url)
        } label: {
            Image(systemName: player.playingURL == url ? "stop.circle.fill" : "play.circle.fill")
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(player.playingURL == url ? Text("Stop") : Text("Play"))
    }
}

extension View {
    /// At a partial detent the sheet is glass, and a List inside it drops its background and tints
    /// its rows to let the glass through. An opaque sheet keeps the grouped look at every detent.
    func ankiEditorSheetBackground() -> some View {
        presentationBackground(Color(.systemGroupedBackground))
    }
}

extension AudioLookupSource {
    var displayName: String {
        var parts = [providerName]
        if let itemName, !itemName.isEmpty {
            parts.append(itemName)
        }
        return parts.joined(separator: " · ")
    }
}
