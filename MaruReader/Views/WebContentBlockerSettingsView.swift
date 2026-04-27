// WebContentBlockerSettingsView.swift
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

struct WebContentBlockerSettingsView: View {
    @AppStorage(WebContentBlocker.isEnabledKey)
    private var isEnabled = WebContentBlocker.isEnabledDefault

    @Bindable private var storage = WebFilterListStorage.shared
    @Bindable private var provider = WebContentBlockerProvider.shared

    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section {
                Toggle("Block Ads & Trackers", isOn: $isEnabled)
            } footer: {
                Text("Filter lists update automatically about once a week.")
            }

            if isEnabled {
                if let error = provider.lastCompileError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } header: {
                        Text("Compilation Error")
                    }
                }

                Section("Filter Lists") {
                    if storage.entries.isEmpty {
                        Text("No filter lists. Tap Add Filter List to get started.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(storage.entries) { entry in
                            FilterListRow(entry: entry, storage: storage)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                storage.remove(id: storage.entries[index].id)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Filter List…", systemImage: "plus")
                    }
                    Button {
                        WebFilterListUpdateScheduler.shared.refreshNow()
                    } label: {
                        Label("Update Now", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle("Content Blocker")
        .sheet(isPresented: $showingAddSheet) {
            AddFilterListSheet { seed in
                storage.add(seed: seed)
                WebFilterListUpdateScheduler.shared.refreshNow()
            }
        }
    }
}

private struct FilterListRow: View {
    let entry: WebFilterListEntry
    let storage: WebFilterListStorage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(isOn: Binding(
                    get: { entry.isEnabled },
                    set: { storage.setEnabled(id: entry.id, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.body)
                        Text(entry.sourceURL.host ?? entry.sourceURL.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            statusLine
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let error = entry.lastFetchError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        } else if let success = entry.lastFetchSuccessAt {
            Text("Updated \(success, style: .relative) ago · \(entry.ruleCount) rules")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("Not yet downloaded")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AddFilterListSheet: View {
    var onAdd: (WebFilterListSeed) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlText = ""
    @State private var format: FormatChoice = .standard

    private enum FormatChoice: String, CaseIterable, Identifiable {
        case standard
        case hosts

        var id: String {
            rawValue
        }

        var label: LocalizedStringKey {
            switch self {
            case .standard: "Standard (ABP)"
            case .hosts: "Hosts file"
            }
        }

        var format: WebFilterListFormat {
            switch self {
            case .standard: .standard
            case .hosts: .hosts
            }
        }
    }

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedURL: URL? {
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private var canSubmit: Bool {
        parsedURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("URL") {
                    TextField("https://example.com/list.txt", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Name (optional)") {
                    TextField("List name", text: $name)
                }
                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(FormatChoice.allCases) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Filter List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let url = parsedURL else { return }
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedName = trimmedName.isEmpty
                            ? (url.host ?? url.lastPathComponent)
                            : trimmedName
                        onAdd(WebFilterListSeed(
                            name: resolvedName,
                            sourceURL: url,
                            format: format.format
                        ))
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WebContentBlockerSettingsView()
    }
}
