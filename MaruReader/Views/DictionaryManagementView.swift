// DictionaryManagementView.swift
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

//
//  DictionaryManagementView.swift
//  MaruReader
//
//  Dictionary management interface for viewing imported dictionaries
//
import CoreData
import MaruReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct DictionaryManagementView: View {
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var updateError: Error?
    @State private var showingUpdateError = false
    @State private var dictionaryToDelete: Dictionary?
    @State private var showingDeleteConfirmation = false

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.title, ascending: true),
        ],
        predicate: NSPredicate(format: "pendingDeletion == NO"),
        animation: .default
    )
    private var dictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: DictionaryUpdateTask.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \DictionaryUpdateTask.timeQueued, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO"),
        animation: .default
    )
    private var updateTasks: FetchedResults<DictionaryUpdateTask>

    private var unifiedDictionaries: [Dictionary] {
        let incomplete = dictionaries
            .filter { !$0.isComplete }
            .sorted {
                let lhsDate = $0.timeQueued ?? .distantPast
                let rhsDate = $1.timeQueued ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return ($0.title ?? "") < ($1.title ?? "")
            }
        let complete = dictionaries
            .filter(\.isComplete)
            .sorted { ($0.title ?? "") < ($1.title ?? "") }
        return incomplete + complete
    }

    private var updateReadyDictionaries: [Dictionary] {
        unifiedDictionaries.filter { $0.isComplete && $0.updateReady }
    }

    private var hasUpdatesAvailable: Bool {
        !updateReadyDictionaries.isEmpty
    }

    var body: some View {
        List {
            if !updateTasks.isEmpty {
                Section("Updates") {
                    ForEach(updateTasks, id: \.objectID) { task in
                        DictionaryUpdateTaskRow(task: task)
                    }
                }
            }

            Section("Dictionaries") {
                if dictionaries.isEmpty {
                    ContentUnavailableView(
                        "No Dictionaries",
                        systemImage: "book.closed",
                        description: Text("Import dictionaries to see them here")
                    )
                } else {
                    ForEach(unifiedDictionaries, id: \.objectID) { dictionary in
                        DictionaryListRow(
                            dictionary: dictionary,
                            onCancel: { cancelImport(dictionary) },
                            onRemove: { removeDictionary(dictionary) },
                            onDelete: {
                                dictionaryToDelete = dictionary
                                showingDeleteConfirmation = true
                            },
                            onUpdate: { startUpdate(dictionary) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button(action: checkForUpdates) {
                    Label("Check Updates", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink(destination: DictionaryPriorityView()) {
                    Label("Priorities", systemImage: "arrow.up.arrow.down")
                }
            }
            if hasUpdatesAvailable {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: updateAll) {
                        Label("Update All", systemImage: "arrow.down.circle")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                importError = nil
            }
        } message: {
            if let error = importError {
                Text(error.localizedDescription)
            }
        }
        .alert("Update Error", isPresented: $showingUpdateError) {
            Button("OK") {
                showingUpdateError = false
                updateError = nil
            }
        } message: {
            if let error = updateError {
                Text(error.localizedDescription)
            }
        }
        .confirmationDialog("Delete Dictionary", isPresented: $showingDeleteConfirmation, presenting: dictionaryToDelete) { dictionary in
            Button("Delete", role: .destructive) {
                deleteDictionary(dictionary)
            }
            Button("Cancel", role: .cancel) {}
        } message: { dictionary in
            Text("Are you sure you want to delete \"\(dictionary.title ?? "Unknown Dictionary")\"? This action cannot be undone.")
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    _ = try await DictionaryImportManager.shared.enqueueImport(from: url)
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

    private func cancelImport(_ dictionary: Dictionary) {
        Task {
            await DictionaryImportManager.shared.cancelImport(jobID: dictionary.objectID)
        }
    }

    private func removeDictionary(_ dictionary: Dictionary) {
        Task {
            await DictionaryImportManager.shared.deleteDictionary(dictionaryID: dictionary.objectID)
        }
    }

    private func deleteDictionary(_ dictionary: Dictionary) {
        Task {
            await DictionaryImportManager.shared.deleteDictionary(dictionaryID: dictionary.objectID)
        }
    }

    private func checkForUpdates() {
        Task {
            _ = await DictionaryUpdateManager.shared.checkForUpdates()
        }
    }

    private func updateAll() {
        let dictionaryIDs = updateReadyDictionaries.map(\.objectID)
        Task {
            await DictionaryUpdateManager.shared.enqueueUpdates(for: dictionaryIDs)
        }
    }

    private func startUpdate(_ dictionary: Dictionary) {
        Task {
            do {
                _ = try await DictionaryUpdateManager.shared.enqueueUpdate(for: dictionary.objectID)
            } catch {
                await MainActor.run {
                    updateError = error
                    showingUpdateError = true
                }
            }
        }
    }
}

struct DictionaryListRow: View {
    let dictionary: Dictionary
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        if dictionary.isComplete {
            DictionaryRow(dictionary: dictionary, onDelete: onDelete, onUpdate: onUpdate)
        } else if dictionary.isFailed || dictionary.isCancelled {
            FailedDictionaryRow(dictionary: dictionary, onRemove: onRemove)
        } else {
            InProgressDictionaryRow(dictionary: dictionary, onCancel: onCancel)
        }
    }
}

struct InProgressDictionaryRow: View {
    let dictionary: Dictionary
    let onCancel: () -> Void

    private var title: String {
        if let title = dictionary.title, !title.isEmpty {
            return title
        }
        return dictionary.file?.deletingPathExtension().lastPathComponent ?? "Unknown Dictionary"
    }

    private var statusIcon: String {
        dictionary.isStarted ? "gear" : "clock"
    }

    private var statusColor: Color {
        dictionary.isStarted ? .blue : .orange
    }

    private var statusMessage: String {
        if let message = dictionary.displayProgressMessage, !message.isEmpty {
            return message
        }
        return dictionary.isStarted ? "Importing..." : "Queued for import."
    }

    private var canCancel: Bool {
        !dictionary.isComplete && !dictionary.isFailed && !dictionary.isCancelled && !dictionary.pendingDeletion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
        .opacity(dictionary.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if dictionary.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .disabled(dictionary.pendingDeletion)
    }
}

struct FailedDictionaryRow: View {
    let dictionary: Dictionary
    let onRemove: () -> Void

    private var title: String {
        if let title = dictionary.title, !title.isEmpty {
            return title
        }
        return dictionary.file?.deletingPathExtension().lastPathComponent ?? "Unknown Dictionary"
    }

    private var statusIcon: String {
        dictionary.isCancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        dictionary.isCancelled ? .secondary : .red
    }

    private var statusMessage: String {
        if dictionary.isCancelled {
            return "Import cancelled."
        }
        return dictionary.errorMessage ?? dictionary.displayProgressMessage ?? "Import failed."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }

                Spacer()

                if !dictionary.pendingDeletion {
                    Button("Remove", action: onRemove)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(dictionary.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if dictionary.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .disabled(dictionary.pendingDeletion)
    }
}

struct DictionaryRow: View {
    let dictionary: Dictionary
    let onDelete: () -> Void
    let onUpdate: () -> Void
    @State private var showExpandedMetadata = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.title ?? "Unknown Dictionary")
                        .font(.headline)

                    if let sourceLanguage = dictionary.sourceLanguage,
                       let targetLanguage = dictionary.targetLanguage
                    {
                        Text("\(sourceLanguage) → \(targetLanguage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let errorMessage = dictionary.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else {
                            let types: [(label: String, systemImage: String, isPresent: Bool)] = [
                                ("Terms: \(dictionary.termCount)", "textformat", dictionary.termCount > 0),
                                ("Kanji: \(dictionary.kanjiCount)", "character.zh", dictionary.kanjiCount > 0),
                                ("Frequency: \(dictionary.termFrequencyCount)", "chart.line.uptrend.xyaxis", dictionary.termFrequencyCount > 0),
                                ("Kanji Frequency: \(dictionary.kanjiFrequencyCount)", "chart.bar", dictionary.kanjiFrequencyCount > 0),
                                ("Pitch: \(dictionary.pitchesCount)", "waveform", dictionary.pitchesCount > 0),
                                ("IPA: \(dictionary.ipaCount)", "speaker.wave.2", dictionary.ipaCount > 0),
                            ]
                            ForEach(types.filter(\.isPresent), id: \.label) { type in
                                Label(type.label, systemImage: type.systemImage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                if dictionary.updateReady, !dictionary.pendingDeletion {
                    Button("Update", action: onUpdate)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button(action: { showExpandedMetadata.toggle() }) {
                    Image(systemName: showExpandedMetadata ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if showExpandedMetadata {
                VStack(alignment: .leading, spacing: 4) {
                    if let author = dictionary.author {
                        LabeledContent("Author", value: author)
                            .font(.caption)
                    }

                    if let attribution = dictionary.attribution {
                        LabeledContent("Attribution", value: attribution)
                            .font(.caption)
                    }

                    if let description = dictionary.displayDescription {
                        LabeledContent("Description", value: description)
                            .font(.caption)
                    }

                    if let revision = dictionary.revision {
                        LabeledContent("Revision", value: revision)
                            .font(.caption)
                    }

                    if let url = dictionary.url, let projectURL = URL(string: url) {
                        HStack {
                            Text("Project:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Link(url, destination: projectURL)
                                .font(.caption)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
        .opacity(dictionary.pendingDeletion ? 0.5 : 1.0)
        .overlay(alignment: .trailing) {
            if dictionary.pendingDeletion {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !dictionary.pendingDeletion {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .disabled(dictionary.pendingDeletion)
    }
}

struct DictionaryUpdateTaskRow: View {
    @ObservedObject var task: DictionaryUpdateTask

    private var progressValue: Double? {
        guard task.totalBytes > 0 else { return nil }
        return Double(task.bytesReceived) / Double(task.totalBytes)
    }

    private var progressText: String? {
        guard task.totalBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let received = formatter.string(fromByteCount: task.bytesReceived)
        let total = formatter.string(fromByteCount: task.totalBytes)
        return "\(received) of \(total)"
    }

    private var statusMessage: String {
        if let message = task.displayProgressMessage, !message.isEmpty {
            return message
        }
        return task.isStarted ? "Updating..." : "Queued for update."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.dictionaryTitle ?? "Dictionary Update")
                .font(.headline)
                .lineLimit(1)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progressValue {
                ProgressView(value: progressValue)
            } else {
                ProgressView()
            }

            if let progressText {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
