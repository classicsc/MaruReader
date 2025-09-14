//
//  DictionaryManagementView.swift
//  MaruReader
//
//  Dictionary management interface for viewing imported dictionaries
//
import CoreData
import SwiftUI

struct DictionaryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext

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
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.large)
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

#Preview {
    NavigationStack {
        DictionaryManagementView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
