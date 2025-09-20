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
                // Perform import on background queue
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
                            ("Terms", "textformat", dictionary.termCount > 0),
                            ("Kanji", "character.zh", dictionary.kanjiCount > 0),
                            ("Frequency", "chart.line.uptrend.xyaxis", dictionary.termFrequencyCount > 0),
                            ("Kanji Frequency", "chart.bar", dictionary.kanjiFrequencyCount > 0),
                            ("Pitch", "waveform", dictionary.pitchesCount > 0),
                            ("IPA", "speaker.wave.2", dictionary.ipaCount > 0),
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

#Preview {
    NavigationStack {
        DictionaryManagementView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
