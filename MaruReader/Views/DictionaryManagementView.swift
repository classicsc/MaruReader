//
//  DictionaryManagementView.swift
//  MaruReader
//
//  Dictionary management interface for viewing imported dictionaries
//
import CoreData
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

    @State private var activeImports: [DictionaryImportInfo] = []
    @State private var showingFilePicker = false
    @State private var importError: Error?
    @State private var showingError = false

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.title, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@", NSNumber(value: true)),
        animation: .default
    )
    private var completeDictionaries: FetchedResults<Dictionary>

    var body: some View {
        List {
            // Import Progress Section
            if !activeImports.isEmpty || hasRecentImports || hasRecentFailures {
                Section("Import Progress") {
                    ForEach(activeImports.filter { $0.completionTime == nil }, id: \.id) { importInfo in
                        ImportProgressRow(importInfo: importInfo)
                    }

                    ForEach(recentlyCompletedImports, id: \.id) { importInfo in
                        CompletedImportRow(importInfo: importInfo)
                    }

                    ForEach(recentlyFailedImports, id: \.id) { importInfo in
                        if let error = importInfo.error {
                            FailedImportRow(importInfo: importInfo, error: error)
                        }
                    }
                }
            }

            // Dictionaries Section
            Section("Dictionaries") {
                if completeDictionaries.isEmpty {
                    ContentUnavailableView(
                        "No Dictionaries",
                        systemImage: "book.closed",
                        description: Text("Import dictionaries to see them here")
                    )
                } else {
                    ForEach(completeDictionaries, id: \.objectID) { dictionary in
                        DictionaryRow(dictionary: dictionary)
                    }
                }
            }
        }
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
        .onAppear {
            Task {
                let importManager = DictionaryImportManager.shared
                let imports = importManager.activeImports
                await MainActor.run {
                    activeImports = imports
                }
            }
        }
        .task {
            // Auto-cleanup completed imports after the configured delay
            try? await Task.sleep(for: .seconds(ImportTiming.cleanupDelaySeconds))
            let cutoffDate = Date().addingTimeInterval(-ImportTiming.cleanupDelaySeconds)
            activeImports.removeAll { importInfo in
                if let completionTime = importInfo.completionTime {
                    return completionTime < cutoffDate
                }
                return false
            }
        }
    }

    private var hasRecentImports: Bool {
        !recentlyCompletedImports.isEmpty
    }

    private var hasRecentFailures: Bool {
        !recentlyFailedImports.isEmpty
    }

    private var recentlyCompletedImports: [DictionaryImportInfo] {
        let windowStart = Date().addingTimeInterval(-ImportTiming.recentWindowSeconds)
        return activeImports.filter { importInfo in
            if let completionTime = importInfo.completionTime {
                return completionTime > windowStart
            }
            return false
        }
    }

    private var recentlyFailedImports: [DictionaryImportInfo] {
        let windowStart = Date().addingTimeInterval(-ImportTiming.recentWindowSeconds)
        return activeImports.filter { importInfo in
            if let failureTime = importInfo.failureTime {
                return failureTime > windowStart
            }
            return false
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = DictionaryImportError.fileAccessDenied
                showingError = true
                return
            }

            Task {
                do {
                    let importManager = DictionaryImportManager.shared
                    let importID = importManager.runImport(fromZipFile: url)

                    // Update UI with new import
                    let importInfo = DictionaryImportInfo(displayName: url.deletingPathExtension().lastPathComponent, id: importID, zipFileURL: url)
                    await MainActor.run {
                        activeImports.append(importInfo)
                    }

                    // Keep the security-scoped resource active during import
                    try await importManager.waitForImport(id: importID)

                    // Update UI to mark import as complete
                    await MainActor.run {
                        if let index = activeImports.firstIndex(where: { $0.id == importID }) {
                            activeImports[index].completionTime = Date()
                        }
                    }
                } catch {
                    await MainActor.run {
                        importError = error
                        showingError = true
                    }
                }

                // Always stop accessing the security-scoped resource when done
                url.stopAccessingSecurityScopedResource()
            }

        case let .failure(error):
            importError = error
            showingError = true
        }
    }
}

struct DictionaryRow: View {
    let dictionary: Dictionary
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
                        let types: [(label: String, systemImage: String, isPresent: Bool)] = [
                            ("Terms", "textformat", dictionary.isTermDictionary),
                            ("Kanji", "character.zh", dictionary.isKanjiDictionary),
                            ("Frequency", "chart.line.uptrend.xyaxis", dictionary.isFreqDictionary),
                            ("Kanji Frequency", "chart.bar", dictionary.isKanjiFreqDictionary),
                            ("Pitch", "waveform", dictionary.isPitchDictionary),
                            ("IPA", "speaker.wave.2", dictionary.isIpaDictionary),
                        ]
                        ForEach(types.filter(\.isPresent), id: \.label) { type in
                            Label(type.label, systemImage: type.systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
    }
}

struct ImportProgressRow: View {
    let importInfo: DictionaryImportInfo

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: importInfo.completionTime == nil)

            VStack(alignment: .leading, spacing: 2) {
                Text(importInfo.displayName)
                    .font(.headline)
                Text("Importing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 2)
    }
}

struct CompletedImportRow: View {
    let importInfo: DictionaryImportInfo

    var body: some View {
        // Use a TimelineView so the relative time string updates automatically.
        TimelineView(.periodic(from: importInfo.completionTime ?? Date(), by: 1)) { context in
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(importInfo.displayName)
                        .font(.headline)
                    if let completionTime = importInfo.completionTime {
                        Text("Completed \(timeAgoText(from: completionTime, relativeTo: context.date))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    private func timeAgoText(from date: Date, relativeTo reference: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}

struct FailedImportRow: View {
    let importInfo: DictionaryImportInfo
    let error: Error

    var body: some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(importInfo.displayName)
                    .font(.headline)
                Text("Failed: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        DictionaryManagementView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
