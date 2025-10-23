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

private enum ImportTiming {
    // Time after which completed imports are auto-removed from the progress list (5 minutes)
    static let cleanupDelaySeconds: TimeInterval = 5 * 60
    // Window during which completed/failed imports are still shown as "recent" (24 hours)
    static let recentWindowSeconds: TimeInterval = 24 * 60 * 60
}

struct DictionaryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var dictionaryToDelete: Dictionary?
    @State private var showingDeleteConfirmation = false

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.title, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@", NSNumber(value: true)),
        animation: .default
    )
    private var completeDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: DictionaryZIPFileImport.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \DictionaryZIPFileImport.timeQueued, ascending: false),
        ],
        animation: .default
    )
    private var importJobs: FetchedResults<DictionaryZIPFileImport>

    var body: some View {
        List {
            // Import Progress Section
            if !importJobs.isEmpty {
                Section("Import Progress") {
                    ForEach(importJobs, id: \.objectID) { job in
                        ImportJobRow(
                            job: job,
                            onCancel: { cancelImport(job) },
                            onDismiss: { dismissImport(job) }
                        )
                    }
                }
            }

            // Dictionaries Section
            Section(importJobs.isEmpty ? "" : "Dictionaries") {
                if completeDictionaries.isEmpty {
                    ContentUnavailableView(
                        "No Dictionaries",
                        systemImage: "book.closed",
                        description: Text("Import dictionaries to see them here")
                    )
                } else {
                    ForEach(completeDictionaries, id: \.objectID) { dictionary in
                        DictionaryRow(dictionary: dictionary, onDelete: {
                            dictionaryToDelete = dictionary
                            showingDeleteConfirmation = true
                        })
                    }
                }
            }
        }
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink(destination: DictionaryPriorityView()) {
                    Label("Priorities", systemImage: "arrow.up.arrow.down")
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

    private func cancelImport(_ job: DictionaryZIPFileImport) {
        Task {
            await DictionaryImportManager.shared.cancelImport(jobID: job.objectID)
        }
    }

    private func dismissImport(_ job: DictionaryZIPFileImport) {
        viewContext.delete(job)
        do {
            try viewContext.save()
        } catch {
            importError = error
            showingError = true
        }
    }

    private func deleteDictionary(_ dictionary: Dictionary) {
        Task {
            await DictionaryImportManager.shared.deleteDictionary(dictionaryID: dictionary.objectID)
        }
    }
}

struct ImportJobRow: View {
    let job: DictionaryZIPFileImport
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

struct DictionaryRow: View {
    let dictionary: Dictionary
    let onDelete: () -> Void
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
