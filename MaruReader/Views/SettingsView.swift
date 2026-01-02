//  SettingsView.swift
//  MaruReader
//
//  Stub settings screen.
//
import MaruAnki
import SwiftUI

struct SettingsView: View {
    @State private var pendingCount = 0
    private let noteService = AnkiNoteService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    NavigationLink(destination: DictionaryManagementView()) {
                        Label("Dictionaries", systemImage: "book.closed")
                    }
                    NavigationLink(destination: AudioSourceSettingsView()) {
                        Label("Pronunciation Audio", systemImage: "speaker.wave.2")
                    }
                }
                Section("Appearance") {
                    NavigationLink(destination: DictionaryDisplaySettingsView()) {
                        Label("Dictionary Display", systemImage: "textformat")
                    }
                }
                Section("Integrations") {
                    if pendingCount > 0 {
                        NavigationLink(destination: AnkiSettingsView()) {
                            Label("Anki", systemImage: "rectangle.stack.badge.plus")
                        }
                        .badge(pendingCount)
                    } else {
                        NavigationLink(destination: AnkiSettingsView()) {
                            Label("Anki", systemImage: "rectangle.stack.badge.plus")
                        }
                    }
                }
                Section("About") {
                    LabeledContent("App Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await loadPendingCount()
                }
            }
        }
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var appBuild: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }

    private func loadPendingCount() async {
        pendingCount = await noteService.pendingNoteCount()
    }
}

#Preview {
    SettingsView()
}
