// AudioSourceSettingsView.swift
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

    private var visibleSources: [AudioSource] {
        audioSources.filter { !$0.pendingDeletion }
    }

    private var unifiedSources: [AudioSource] {
        let incomplete = visibleSources
            .filter { !$0.isComplete }
            .sorted {
                let lhsDate = $0.timeQueued ?? .distantPast
                let rhsDate = $1.timeQueued ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        let complete = visibleSources
            .filter(\.isComplete)
            .sorted { $0.priority < $1.priority }
        return incomplete + complete
    }

    var body: some View {
        List {
            Section("Audio Sources") {
                if unifiedSources.isEmpty {
                    ContentUnavailableView(
                        "No Audio Sources",
                        systemImage: "speaker.wave.2",
                        description: Text("Add an audio source to enable pronunciation audio")
                    )
                } else {
                    ForEach(unifiedSources, id: \.objectID) { source in
                        AudioSourceListRow(
                            source: source,
                            onCancel: { cancelImport(source) },
                            onDelete: {
                                sourceToDelete = source
                                showingDeleteConfirmation = true
                            }
                        )
                        .moveDisabled(!source.isComplete)
                    }
                    .onMove(perform: reorderSources)
                    .onDelete(perform: deleteSources)
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
                let name = source.name ?? AppLocalization.unknownSource
                Text(AppLocalization.deleteConfirmationActionCannotBeUndone(name: name))
            }
        }
        .navigationTitle("Pronunciation Audio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("Add Source", systemImage: "plus") {
                    Button("Import Indexed ZIP") {
                        showingZipImporter = true
                    }
                    Button("Add URL Pattern") {
                        showingAddURLPatternSheet = true
                    }
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

    private func cancelImport(_ source: AudioSource) {
        Task {
            await AudioSourceImportManager.shared.cancelImport(jobID: source.objectID)
        }
    }

    private func deleteSource(_ source: AudioSource) {
        Task {
            await AudioSourceImportManager.shared.deleteAudioSource(sourceID: source.objectID)
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        let sources = unifiedSources
        for index in offsets {
            guard index < sources.count else { continue }
            let source = sources[index]
            if source.isComplete || source.isFailed || source.isCancelled {
                deleteSource(source)
            }
        }
    }

    private func reorderSources(from source: IndexSet, to destination: Int) {
        let completeSources = unifiedSources.filter(\.isComplete)
        let completeIndices = unifiedSources.enumerated().compactMap { index, item in
            item.isComplete ? index : nil
        }
        let sourceInComplete = IndexSet(source.compactMap { index in
            completeIndices.firstIndex(of: index)
        })
        let destinationInComplete = completeIndices.prefix(destination).count

        var updated = completeSources
        updated.move(fromOffsets: sourceInComplete, toOffset: destinationInComplete)

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

private struct AudioSourceListRow: View {
    let source: AudioSource
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if source.isComplete {
            CompletedAudioSourceRow(source: source, onDelete: onDelete)
        } else if source.isFailed || source.isCancelled {
            FailedAudioSourceRow(source: source, onRemove: onDelete)
        } else {
            InProgressAudioSourceRow(source: source, onCancel: onCancel)
        }
    }
}

private struct InProgressAudioSourceRow: View {
    let source: AudioSource
    let onCancel: () -> Void

    private var title: String {
        if let name = source.name, !name.isEmpty {
            return name
        }
        return source.file?.deletingPathExtension().lastPathComponent ?? AppLocalization.unknownSource
    }

    private var statusIcon: String {
        source.isStarted ? "gear" : "clock"
    }

    private var statusColor: Color {
        source.isStarted ? .blue : .orange
    }

    private var statusMessage: String {
        if let message = source.displayProgressMessage, !message.isEmpty {
            return message
        }
        return source.isStarted ? String(localized: "Importing...") : String(localized: "Queued for import.")
    }

    private var canCancel: Bool {
        !source.isComplete && !source.isFailed && !source.isCancelled && !source.pendingDeletion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(alignment: .center, spacing: 6) {
                        if source.isStarted {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(statusMessage)
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
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(source.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if source.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .disabled(source.pendingDeletion)
    }
}

private struct FailedAudioSourceRow: View {
    let source: AudioSource
    let onRemove: () -> Void

    private var title: String {
        if let name = source.name, !name.isEmpty {
            return name
        }
        return source.file?.deletingPathExtension().lastPathComponent ?? AppLocalization.unknownSource
    }

    private var statusIcon: String {
        source.isCancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        source.isCancelled ? .secondary : .red
    }

    private var statusMessage: String {
        if source.isCancelled {
            return String(localized: "Import cancelled.")
        }
        return source.displayProgressMessage ?? String(localized: "Import failed.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }

                Spacer()

                if !source.pendingDeletion {
                    Button("Remove", action: onRemove)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(source.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if source.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .disabled(source.pendingDeletion)
    }
}

private struct CompletedAudioSourceRow: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var source: AudioSource
    let onDelete: () -> Void
    @State private var showExpandedMetadata = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: source.name ?? AppLocalization.unknownSource)
                        .font(.headline)

                    Text(typeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .center, spacing: 12) {
                    Toggle("Enabled", isOn: $source.enabled)
                        .onChange(of: source.enabled) {
                            try? viewContext.save()
                        }
                        .labelsHidden()
                        .disabled(source.pendingDeletion)

                    Button(action: { showExpandedMetadata.toggle() }) {
                        Image(systemName: showExpandedMetadata ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            if showExpandedMetadata {
                VStack(alignment: .leading, spacing: 4) {
                    if let pattern = source.urlPattern, !pattern.isEmpty {
                        LabeledContent("URL Pattern", value: pattern)
                            .font(.caption)
                    }

                    if let baseRemoteURL = source.baseRemoteURL, !baseRemoteURL.isEmpty {
                        LabeledContent("Base URL", value: baseRemoteURL)
                            .font(.caption)
                    }

                    if let audioExtensions = source.audioFileExtensions, !audioExtensions.isEmpty {
                        LabeledContent("Audio Extensions", value: audioExtensions)
                            .font(.caption)
                    }

                    if let fileURL = source.file, source.isLocal {
                        LabeledContent("Archive", value: fileURL.lastPathComponent)
                            .font(.caption)
                    }

                    if source.version > 0 {
                        LabeledContent("Version", value: String(source.version))
                            .font(.caption)
                    }

                    if source.year > 0 {
                        LabeledContent("Year", value: String(source.year))
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
        .opacity(source.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if source.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !source.pendingDeletion {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .disabled(source.pendingDeletion)
    }

    private var typeDescription: String {
        if source.indexedByHeadword {
            if source.isLocal {
                return String(localized: "Indexed (Local ZIP)")
            }
            return String(localized: "Indexed (Online)")
        }
        if source.urlPatternReturnsJSON {
            return String(localized: "URL Pattern (JSON)")
        }
        return String(localized: "URL Pattern")
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

#Preview {
    NavigationStack {
        AudioSourceSettingsView()
    }
    .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
}
