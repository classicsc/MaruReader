// ContextImageSettingsView.swift
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

import CoreData
import MaruAnki
import SwiftUI

/// Settings view for configuring the contextImage template value behavior.
struct ContextImageSettingsView: View {
    private let persistence = AnkiPersistenceController.shared

    @State private var currentSettings: MaruAnkiSettings?
    @State private var configuration: ContextImageConfiguration = .default
    @State private var isLoading = true

    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else {
                Section {
                    Picker("Book Reader", selection: $configuration.bookPreference) {
                        Text("Cover Image").tag(ContextImagePreference.cover)
                        Text("Screenshot").tag(ContextImagePreference.screenshot)
                    }

                    Picker("Manga Reader", selection: $configuration.mangaPreference) {
                        Text("Cover Image").tag(ContextImagePreference.cover)
                        Text("Page Screenshot").tag(ContextImagePreference.screenshot)
                    }
                } header: {
                    Text("Image Selection")
                } footer: {
                    Text("Choose which image to use for the Context Image template value based on where the lookup originated.")
                }
            }
        }
        .navigationTitle("Context Image")
        .task {
            await loadSettings()
        }
        .onChange(of: configuration) {
            saveConfiguration()
        }
    }

    private func loadSettings() async {
        let context = persistence.container.viewContext
        let fetchedSettings: MaruAnkiSettings? = await context.perform {
            let request = NSFetchRequest<MaruAnkiSettings>(entityName: "MaruAnkiSettings")
            request.fetchLimit = 1
            return try? context.fetch(request).first
        }

        currentSettings = fetchedSettings
        if let settings = fetchedSettings {
            configuration = settings.decodedContextImageConfiguration
        }
        isLoading = false
    }

    private func saveConfiguration() {
        guard let settings = currentSettings else { return }

        settings.decodedContextImageConfiguration = configuration
        try? persistence.container.viewContext.save()
    }
}

#Preview {
    NavigationStack {
        ContextImageSettingsView()
    }
}
