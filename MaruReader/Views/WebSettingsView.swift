// WebSettingsView.swift
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

import MaruWeb
import SwiftUI

struct WebSettingsView: View {
    @AppStorage(WebContentBlockingSettings.contentBlockingEnabledKey)
    private var webContentBlockingEnabled = WebContentBlockingSettings.contentBlockingEnabledDefault
    @AppStorage(WebSearchEngineSettings.searchSuggestionsEnabledKey)
    private var searchSuggestionsEnabled = WebSearchEngineSettings.searchSuggestionsEnabledDefault
    @State private var selectedEngineKind: SearchEngineKind = WebSearchEngineSettings.searchEngine.kind
    @State private var customSearchURL: String = ""
    @State private var customSuggestionsURL: String = ""

    var body: some View {
        Form {
            Section("Search") {
                Picker("Search Engine", selection: $selectedEngineKind) {
                    ForEach(SearchEngineKind.allCases) { kind in
                        Text(kind.localizedDisplayName).tag(kind)
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
            }
            Section(
                header: Text("Privacy"),
                footer: Text("Blocks distracting ads and trackers in the web reader.")
            ) {
                Toggle("Content Blocking", isOn: $webContentBlockingEnabled)
            }
            Section("Data") {
                NavigationLink {
                    WebDataManagementView()
                } label: {
                    Label("Website Data", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .navigationTitle("Web")
        .onAppear {
            loadCustomEngineFields()
        }
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
    NavigationStack {
        WebSettingsView()
    }
}
