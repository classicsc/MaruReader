//
//  PendingNotesView.swift
//  MaruReader
//

import MaruAnki
import SwiftUI

struct PendingNotesView: View {
    @State private var pendingNotes: [AnkiNoteService.PendingAnkiNote] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingNoteIDs: Set<UUID> = []
    @State private var connectionManager: AnkiConnectionManager?

    private let noteService = AnkiNoteService()

    var body: some View {
        List {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else if pendingNotes.isEmpty {
                Section {
                    ContentUnavailableView("No Pending Notes", systemImage: "tray", description: Text("Pending notes from the share extension will appear here."))
                }
            } else {
                Section {
                    ForEach(pendingNotes) { note in
                        Button {
                            Task {
                                await addPending(note)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(noteTitle(note))
                                        .font(.headline)
                                    Text(noteSubtitle(note))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if processingNoteIDs.contains(note.id) {
                                    ProgressView()
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(processingNoteIDs.contains(note.id))
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await deletePending(note)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Pending Notes")
        .task {
            if connectionManager == nil {
                connectionManager = await AnkiConnectionManager()
            }
            await loadPendingNotes()
        }
        .refreshable {
            await loadPendingNotes()
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func loadPendingNotes() async {
        isLoading = true
        pendingNotes = await noteService.fetchPendingNotes()
        isLoading = false
    }

    private func addPending(_ note: AnkiNoteService.PendingAnkiNote) async {
        guard let connectionManager else { return }

        processingNoteIDs.insert(note.id)
        defer { processingNoteIDs.remove(note.id) }

        do {
            let profileName = note.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileValue = profileName.isEmpty ? nil : profileName

            let result = try await connectionManager.addNote(
                resolvedFields: note.fields,
                profileName: profileValue,
                deckName: note.deckName,
                modelName: note.modelName
            )
            if result.pendingSync {
                errorMessage = "Unable to add the note. It remains pending."
                return
            }

            try await noteService.markNoteSynced(id: note.id)
            await loadPendingNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePending(_ note: AnkiNoteService.PendingAnkiNote) async {
        do {
            try await noteService.deleteNote(id: note.id)
            await loadPendingNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func noteTitle(_ note: AnkiNoteService.PendingAnkiNote) -> String {
        if let reading = note.reading, !reading.isEmpty {
            return "\(note.expression) [\(reading)]"
        }
        return note.expression
    }

    private func noteSubtitle(_ note: AnkiNoteService.PendingAnkiNote) -> String {
        let profile = note.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileLabel = profile.isEmpty ? "Default Profile" : profile
        return "\(note.deckName) · \(note.modelName) · \(profileLabel)"
    }
}

#Preview {
    NavigationStack {
        PendingNotesView()
    }
}
