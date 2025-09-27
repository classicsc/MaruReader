//  SettingsView.swift
//  MaruReader
//
//  Stub settings screen.
//
import SwiftUI

struct SettingsView: View {
    @State private var darkMode: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    NavigationLink(destination: DictionaryManagementView()) {
                        Label("Dictionaries", systemImage: "book.closed")
                    }
                }
                Section("Appearance") {
                    Toggle("Dark Mode (stub)", isOn: $darkMode)
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
