// AddURLPatternAudioSourceView.swift
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
import MaruReaderCore
import SwiftUI

struct AddURLPatternAudioSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var name: String = ""
    @State private var urlPattern: String = ""
    @State private var returnsJSONList: Bool = false

    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        Form {
            Section("Audio Source") {
                TextField("Name", text: $name)
            }

            Section("URL Pattern") {
                TextField("URL", text: $urlPattern, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Use {term}, {reading}, {language} as placeholders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Source Type") {
                Toggle("JSON", isOn: $returnsJSONList)
                Text("Enable if the URL returns a JSON object, disable if it returns audio data directly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Audio Source")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .alert("Couldn't Save", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPattern = urlPattern.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "Name is required.")
            showingError = true
            return
        }

        guard !trimmedPattern.isEmpty else {
            errorMessage = String(localized: "URL pattern is required.")
            showingError = true
            return
        }

        let source = AudioSource(context: viewContext)
        source.id = UUID()
        source.name = trimmedName
        source.dateAdded = Date()
        source.enabled = true
        source.indexedByHeadword = false
        source.urlPattern = trimmedPattern
        source.urlPatternReturnsJSON = returnsJSONList
        source.isLocal = false
        source.baseRemoteURL = nil
        source.audioFileExtensions = ""
        source.isComplete = true
        source.isFailed = false
        source.isCancelled = false
        source.isStarted = false
        source.pendingDeletion = false
        source.timeCompleted = Date()
        source.displayProgressMessage = nil

        do {
            source.priority = try nextPriority()
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func nextPriority() throws -> Int64 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioSource")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]
        fetchRequest.fetchLimit = 1

        if let results = try viewContext.fetch(fetchRequest) as? [NSManagedObject],
           let maxSource = results.first,
           let maxPriority = maxSource.value(forKey: "priority") as? Int64
        {
            return maxPriority + 1
        }
        return 0
    }
}
