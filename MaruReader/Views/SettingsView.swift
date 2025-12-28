//  SettingsView.swift
//  MaruReader
//
//  Stub settings screen.
//
import SwiftUI

struct SettingsView: View {
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
                    NavigationLink(destination: AnkiSettingsView()) {
                        Label("Anki", systemImage: "rectangle.stack.badge.plus")
                    }
                }
                Section("About") {
                    LabeledContent("App Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var appBuild: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }
}

#Preview {
    SettingsView()
}
