// SettingsView.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

//  SettingsView.swift
//  MaruReader
//
//  Stub settings screen.
//
import MaruAnki
import MaruManga
import SwiftUI

struct SettingsView: View {
    @State private var pendingCount = 0
    @AppStorage(MangaMetadataExtractionSettings.smartExtractionEnabledKey)
    private var smartMetadataExtractionEnabled = MangaMetadataExtractionSettings.smartExtractionEnabledDefault
    private let noteService = AnkiNoteService()
    private var isMetadataExtractorAvailable: Bool {
        MangaImportManager.isMetadataExtractorAvailable
    }

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
                if isMetadataExtractorAvailable {
                    Section(
                        header: Text("Manga"),
                        footer: Text("Uses the on-device language model to infer titles and authors from filenames.")
                    ) {
                        Toggle("Smart Metadata Extraction", isOn: $smartMetadataExtractionEnabled)
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
