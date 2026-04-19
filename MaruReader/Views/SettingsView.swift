// SettingsView.swift
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

//  SettingsView.swift
//  MaruReader
//
//  Stub settings screen.
//
import MaruAnki
import MaruDictionaryUICommon
import MaruManga
import SwiftUI

struct SettingsView: View {
    @Environment(\.dictionaryFeatureAvailability) private var dictionaryAvailability
    @State private var pendingCount = 0
    @State private var showingResetToursConfirmation = false
    @AppStorage(MangaMetadataExtractionSettings.smartExtractionEnabledKey)
    private var smartMetadataExtractionEnabled = MangaMetadataExtractionSettings.smartExtractionEnabledDefault
    private let noteService = AnkiNoteService()
    private var isMetadataExtractorAvailable: Bool {
        MangaImportManager.isMetadataExtractorAvailable
    }

    private let supportForumURL = URL(string: "https://github.com/classicsc/MaruReader/discussions")!

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    NavigationLink {
                        UnifiedDictionaryManagementRootView(availability: dictionaryAvailability)
                    } label: {
                        Label("Dictionaries & Audio", systemImage: "book.closed")
                    }
                }
                Section("Appearance") {
                    NavigationLink {
                        DictionaryDisplaySettingsView()
                    } label: {
                        Label("Dictionary Display", systemImage: "textformat")
                    }
                }
                if isMetadataExtractorAvailable {
                    Section(
                        header: Text("Manga"),
                        footer: Text("Uses the on-device language model to infer titles and authors from filenames.")
                    ) {
                        Toggle("Smart Metadata", isOn: $smartMetadataExtractionEnabled)
                    }
                }
                Section("Web") {
                    NavigationLink {
                        WebSettingsView()
                    } label: {
                        Label("Web", systemImage: "globe")
                    }
                }
                Section("Integrations") {
                    NavigationLink {
                        AnkiSettingsView()
                    } label: {
                        Label("Anki", systemImage: "rectangle.stack.badge.plus")
                    }
                    .badge(pendingCount)
                }
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About MaruReader", systemImage: "info.circle")
                    }

                    Link(destination: supportForumURL) {
                        Label("Support & Feedback", systemImage: "questionmark.circle")
                    }
                }
                Section(
                    header: Text("Help"),
                    footer: Text("Show the guided tours again the next time you open each reader.")
                ) {
                    Button("Reset Tours") {
                        showingResetToursConfirmation = true
                    }
                    .confirmationDialog("Reset Tours", isPresented: $showingResetToursConfirmation) {
                        Button("Reset Tours") {
                            TourManager.resetAllTours()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will show the guided tours again the next time you open each reader.")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadPendingCount()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func loadPendingCount() async {
        pendingCount = await noteService.pendingNoteCount()
    }
}

#Preview {
    SettingsView()
}
