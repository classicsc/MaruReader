// AudioSourceSettingsView.swift
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

import CoreData
import MaruReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct AudioSourceSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingAddURLPatternSheet = false
    @State private var showingZipImporter = false

    @State private var importError: Error?
    @State private var showingError = false

    @State private var sourceToDelete: AudioSource?
    @State private var showingDeleteConfirmation = false

    @FetchRequest(
        entity: AudioSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioSource.priority, ascending: true)],
        animation: .default
    )
    private var audioSources: FetchedResults<AudioSource>

    @FetchRequest(
        entity: AudioSourceImport.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioSourceImport.timeQueued, ascending: false)],
        animation: .default
    )
    private var importJobs: FetchedResults<AudioSourceImport>

    var body: some View {
        List {
            if !importJobs.isEmpty {
                Section("Import Progress") {
                    ForEach(importJobs, id: \.objectID) { job in
                        AudioSourceImportJobRow(
                            job: job,
                            onCancel: { cancelImport(job) },
                            onDismiss: { dismissImport(job) }
                        )
                    }
                }
            }

            Section(importJobs.isEmpty ? "Audio Sources" : "Sources") {
                if audioSources.isEmpty {
                    ContentUnavailableView(
                        "No Audio Sources",
                        systemImage: "speaker.wave.2",
                        description: Text("Add an audio source to enable pronunciation audio")
                    )
                } else {
                    ForEach(audioSources, id: \.objectID) { source in
                        AudioSourceRow(source: source) {
                            sourceToDelete = source
                            showingDeleteConfirmation = true
                        }
                    }
                    .onMove(perform: reorderSources)
                    .onDelete(perform: deleteSources)
                }
            }
        }
        .navigationTitle("Pronunciation Audio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import Indexed ZIP") {
                        showingZipImporter = true
                    }
                    Button("Add URL Pattern") {
                        showingAddURLPatternSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddURLPatternSheet) {
            NavigationStack {
                AddURLPatternAudioSourceView()
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .fileImporter(
            isPresented: $showingZipImporter,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handleZipImport(result: result)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                importError = nil
            }
        } message: {
            if let error = importError {
                Text(error.localizedDescription)
            }
        }
        .confirmationDialog(
            "Delete Audio Source",
            isPresented: $showingDeleteConfirmation,
            presenting: sourceToDelete
        ) { source in
            Button("Delete", role: .destructive) {
                deleteSource(source)
            }
            Button("Cancel", role: .cancel) {}
        } message: { source in
            let name = source.name ?? "Unknown Source"
            Text(verbatim: "Are you sure you want to delete \"\(name)\"? This action cannot be undone.")
        }
    }

    private func handleZipImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    _ = try await AudioSourceImportManager.shared.enqueueImport(from: url)
                } catch {
                    await MainActor.run {
                        importError = error
                        showingError = true
                    }
                }
            }

        case let .failure(error):
            importError = error
            showingError = true
        }
    }

    private func cancelImport(_ job: AudioSourceImport) {
        Task {
            await AudioSourceImportManager.shared.cancelImport(jobID: job.objectID)
        }
    }

    private func dismissImport(_ job: AudioSourceImport) {
        viewContext.delete(job)
        do {
            try viewContext.save()
        } catch {
            importError = error
            showingError = true
        }
    }

    private func deleteSource(_ source: AudioSource) {
        Task {
            await AudioSourceImportManager.shared.deleteAudioSource(sourceID: source.objectID)
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        for index in offsets {
            guard index < audioSources.count else { continue }
            deleteSource(audioSources[index])
        }
    }

    private func reorderSources(from source: IndexSet, to destination: Int) {
        var updated = Array(audioSources)
        updated.move(fromOffsets: source, toOffset: destination)

        for (index, item) in updated.enumerated() {
            item.priority = Int64(index)
        }

        do {
            try viewContext.save()
        } catch {
            importError = error
            showingError = true
        }
    }
}

private struct AudioSourceRow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let source: AudioSource
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: source.name ?? "Unknown Source")
                    .font(.headline)

                Spacer()

                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { source.enabled },
                        set: { newValue in
                            source.enabled = newValue
                            try? viewContext.save()
                        }
                    )
                )
                .labelsHidden()
            }

            Text(typeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail = detailLine {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var typeDescription: String {
        if source.indexedByHeadword {
            if source.isLocal {
                return "Indexed (Local ZIP)"
            }
            return "Indexed (Online)"
        }
        if source.urlPatternReturnsJSON {
            return "URL Pattern (JSON)"
        }
        return "URL Pattern"
    }

    private var detailLine: String? {
        if source.indexedByHeadword {
            if let base = source.baseRemoteURL, !base.isEmpty {
                return base
            }
            let ext = source.value(forKey: "audioFileExtensions") as? String ?? ""
            if !ext.isEmpty {
                return "Extensions: \(ext)"
            }
            return nil
        }

        if let pattern = source.urlPattern, !pattern.isEmpty {
            return pattern
        }
        return nil
    }
}

private struct AudioSourceImportJobRow: View {
    let job: AudioSourceImport
    let onCancel: () -> Void
    let onDismiss: () -> Void

    private var fileName: String {
        job.file?.lastPathComponent ?? "Unknown File"
    }

    private var statusIcon: String {
        if job.isCancelled {
            "xmark.circle.fill"
        } else if job.isFailed {
            "exclamationmark.triangle.fill"
        } else if job.isComplete {
            "checkmark.circle.fill"
        } else if job.isStarted {
            "gear"
        } else {
            "clock"
        }
    }

    private var statusColor: Color {
        if job.isCancelled {
            .secondary
        } else if job.isFailed {
            .red
        } else if job.isComplete {
            .green
        } else if job.isStarted {
            .blue
        } else {
            .orange
        }
    }

    private var canCancel: Bool {
        !job.isComplete && !job.isFailed && !job.isCancelled
    }

    private var canDismiss: Bool {
        job.isComplete || job.isFailed || job.isCancelled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)

                    if let message = job.displayProgressMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if canCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if canDismiss {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AddURLPatternAudioSourceView: View {
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
        .alert("Couldn’t Save", isPresented: $showingError) {
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
            errorMessage = "Name is required."
            showingError = true
            return
        }

        guard !trimmedPattern.isEmpty else {
            errorMessage = "URL pattern is required."
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

#Preview {
    NavigationStack {
        AudioSourceSettingsView()
    }
    .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
}
