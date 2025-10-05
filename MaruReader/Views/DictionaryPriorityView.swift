//
//  DictionaryPriorityView.swift
//  MaruReader
//
//  Dictionary priority management interface for controlling display order and frequency ranking.
//
import CoreData
import SwiftUI

struct DictionaryPriorityView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.termDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND termCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var termDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.kanjiDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND kanjiCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var kanjiDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.ipaDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND ipaCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var ipaDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.pitchDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND pitchesCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var pitchDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.termFrequencyDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND termFrequencyCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var termFrequencyDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Dictionary.kanjiFrequencyDisplayPriority, ascending: true),
        ],
        predicate: NSPredicate(format: "isComplete == %@ AND kanjiFrequencyCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var kanjiFrequencyDictionaries: FetchedResults<Dictionary>

    @State private var showingError = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Terms Section
            if !termDictionaries.isEmpty {
                Section {
                    ForEach(termDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(termDictionaries, from: from, to: to, priorityKey: \.termDisplayPriority)
                    }
                } header: {
                    Text("Term Display Priority")
                } footer: {
                    Text("Dictionaries appear in this order when multiple dictionaries have the same term. Drag to reorder.")
                }
            }

            // Kanji Section
            if !kanjiDictionaries.isEmpty {
                Section {
                    ForEach(kanjiDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(kanjiDictionaries, from: from, to: to, priorityKey: \.kanjiDisplayPriority)
                    }
                } header: {
                    Text("Kanji Display Priority")
                } footer: {
                    Text("Dictionaries appear in this order when multiple dictionaries have the same kanji. Drag to reorder.")
                }
            }

            // IPA Section
            if !ipaDictionaries.isEmpty {
                Section {
                    ForEach(ipaDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(ipaDictionaries, from: from, to: to, priorityKey: \.ipaDisplayPriority)
                    }
                } header: {
                    Text("IPA Display Priority")
                } footer: {
                    Text("IPA entries appear in this order. Drag to reorder.")
                }
            }

            // Pitch Accent Section
            if !pitchDictionaries.isEmpty {
                Section {
                    ForEach(pitchDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(pitchDictionaries, from: from, to: to, priorityKey: \.pitchDisplayPriority)
                    }
                } header: {
                    Text("Pitch Accent Display Priority")
                } footer: {
                    Text("Pitch accent entries appear in this order. Drag to reorder.")
                }
            }

            // Term Frequency Section
            if !termFrequencyDictionaries.isEmpty {
                Section {
                    ForEach(termFrequencyDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(termFrequencyDictionaries, from: from, to: to, priorityKey: \.termFrequencyDisplayPriority)
                    }

                    // Picker for frequency ranking dictionary
                    Picker("Ranking Dictionary", selection: termFrequencyRankingBinding) {
                        ForEach(termFrequencyDictionaries, id: \.objectID) { dictionary in
                            Text(dictionary.title ?? "Unknown")
                                .tag(dictionary.objectID as NSManagedObjectID?)
                        }
                    }
                } header: {
                    Text("Term Frequency")
                } footer: {
                    Text("Drag to reorder display priority. The ranking dictionary is used to sort search results by frequency.")
                }
            }

            // Kanji Frequency Section
            if !kanjiFrequencyDictionaries.isEmpty {
                Section {
                    ForEach(kanjiFrequencyDictionaries, id: \.objectID) { dictionary in
                        DictionaryPriorityRow(dictionary: dictionary)
                    }
                    .onMove { from, to in
                        reorderDictionaries(kanjiFrequencyDictionaries, from: from, to: to, priorityKey: \.kanjiFrequencyDisplayPriority)
                    }

                    // Picker for frequency ranking dictionary
                    Picker("Ranking Dictionary", selection: kanjiFrequencyRankingBinding) {
                        ForEach(kanjiFrequencyDictionaries, id: \.objectID) { dictionary in
                            Text(dictionary.title ?? "Unknown")
                                .tag(dictionary.objectID as NSManagedObjectID?)
                        }
                    }
                } header: {
                    Text("Kanji Frequency")
                } footer: {
                    Text("Drag to reorder display priority. The ranking dictionary is used to sort search results by frequency.")
                }
            }

            // Empty state
            if termDictionaries.isEmpty, kanjiDictionaries.isEmpty, ipaDictionaries.isEmpty, pitchDictionaries.isEmpty, termFrequencyDictionaries.isEmpty, kanjiFrequencyDictionaries.isEmpty {
                ContentUnavailableView(
                    "No Dictionaries",
                    systemImage: "book.closed",
                    description: Text("Import dictionaries to configure their priorities")
                )
            }
        }
        .navigationTitle("Dictionary Priorities")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                errorMessage = nil
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Bindings

    private var termFrequencyRankingBinding: Binding<NSManagedObjectID?> {
        Binding(
            get: {
                termFrequencyDictionaries.first { $0.termFrequencyEnabled }?.objectID
            },
            set: { newValue in
                setFrequencyRanking(
                    dictionaries: Array(termFrequencyDictionaries),
                    selectedID: newValue,
                    enabledKey: \.termFrequencyEnabled
                )
            }
        )
    }

    private var kanjiFrequencyRankingBinding: Binding<NSManagedObjectID?> {
        Binding(
            get: {
                kanjiFrequencyDictionaries.first { $0.kanjiFrequencyEnabled }?.objectID
            },
            set: { newValue in
                setFrequencyRanking(
                    dictionaries: Array(kanjiFrequencyDictionaries),
                    selectedID: newValue,
                    enabledKey: \.kanjiFrequencyEnabled
                )
            }
        )
    }

    // MARK: - Helper Methods

    private func reorderDictionaries<T>(_ dictionaries: T, from source: IndexSet, to destination: Int, priorityKey: ReferenceWritableKeyPath<Dictionary, Int64>) where T: RandomAccessCollection, T.Element == Dictionary {
        var dictionariesArray = Array(dictionaries)

        // Perform the move
        dictionariesArray.move(fromOffsets: source, toOffset: destination)

        // Reassign priorities based on new order
        for (index, dictionary) in dictionariesArray.enumerated() {
            dictionary[keyPath: priorityKey] = Int64(index)
        }

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to reorder dictionaries: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func setFrequencyRanking(dictionaries: [Dictionary], selectedID: NSManagedObjectID?, enabledKey: ReferenceWritableKeyPath<Dictionary, Bool>) {
        // Disable all dictionaries
        for dictionary in dictionaries {
            dictionary[keyPath: enabledKey] = false
        }

        // Enable the selected dictionary
        if let selectedID,
           let selectedDict = dictionaries.first(where: { $0.objectID == selectedID })
        {
            selectedDict[keyPath: enabledKey] = true
        }

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to update frequency ranking: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Dictionary Priority Row

struct DictionaryPriorityRow: View {
    let dictionary: Dictionary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dictionary.title ?? "Unknown Dictionary")
                    .font(.headline)

                if let sourceLanguage = dictionary.sourceLanguage,
                   let targetLanguage = dictionary.targetLanguage
                {
                    Text("\(sourceLanguage) → \(targetLanguage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DictionaryPriorityView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
