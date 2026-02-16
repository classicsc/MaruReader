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
import MaruWeb
import SwiftUI

struct SettingsView: View {
    @State private var pendingCount = 0
    @State private var showingResetToursConfirmation = false
    @AppStorage(MangaMetadataExtractionSettings.smartExtractionEnabledKey)
    private var smartMetadataExtractionEnabled = MangaMetadataExtractionSettings.smartExtractionEnabledDefault
    @AppStorage(WebContentBlockingSettings.contentBlockingEnabledKey)
    private var webContentBlockingEnabled = WebContentBlockingSettings.contentBlockingEnabledDefault
    @AppStorage(WebSearchEngineSettings.searchSuggestionsEnabledKey)
    private var searchSuggestionsEnabled = WebSearchEngineSettings.searchSuggestionsEnabledDefault
    @State private var selectedEngineKind: SearchEngineKind = WebSearchEngineSettings.searchEngine.kind
    @State private var customSearchURL: String = ""
    @State private var customSuggestionsURL: String = ""
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
                Section(
                    header: Text("Web"),
                    footer: Text("Blocks distracting ads and trackers in the web reader.")
                ) {
                    Picker("Search Engine", selection: $selectedEngineKind) {
                        ForEach(SearchEngineKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .onChange(of: selectedEngineKind) { _, newValue in
                        applySearchEngineKind(newValue)
                    }

                    if selectedEngineKind == .custom {
                        TextField("Search URL (use %s for query)", text: $customSearchURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { saveCustomEngine() }
                            .onChange(of: customSearchURL) { _, _ in saveCustomEngine() }

                        TextField("Suggestions URL (optional, use %s)", text: $customSuggestionsURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { saveCustomEngine() }
                            .onChange(of: customSuggestionsURL) { _, _ in saveCustomEngine() }
                    }

                    Toggle("Search Suggestions", isOn: $searchSuggestionsEnabled)
                    Toggle("Content Blocking", isOn: $webContentBlockingEnabled)
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
                Section("About") {
                    NavigationLink(destination: AboutView()) {
                        Label("About MaruReader", systemImage: "info.circle")
                    }
                    LabeledContent("App Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await loadPendingCount()
                }
                loadCustomEngineFields()
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

    private func loadCustomEngineFields() {
        let engine = WebSearchEngineSettings.searchEngine
        selectedEngineKind = engine.kind
        if case let .custom(searchURL, suggestionsURL) = engine {
            customSearchURL = searchURL
            customSuggestionsURL = suggestionsURL ?? ""
        }
    }

    private func applySearchEngineKind(_ kind: SearchEngineKind) {
        switch kind {
        case .google:
            WebSearchEngineSettings.searchEngine = .google
        case .bing:
            WebSearchEngineSettings.searchEngine = .bing
        case .custom:
            saveCustomEngine()
        @unknown default:
            WebSearchEngineSettings.searchEngine = .google
        }
    }

    private func saveCustomEngine() {
        guard selectedEngineKind == .custom else { return }
        let suggestionsURL = customSuggestionsURL.trimmingCharacters(in: .whitespacesAndNewlines)
        WebSearchEngineSettings.searchEngine = .custom(
            searchURL: customSearchURL.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestionsURL: suggestionsURL.isEmpty ? nil : suggestionsURL
        )
    }
}

#Preview {
    SettingsView()
}
