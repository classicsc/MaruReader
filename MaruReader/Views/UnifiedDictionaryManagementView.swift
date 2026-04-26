// UnifiedDictionaryManagementView.swift
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
import MaruDictionaryManagement
import MaruReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct UnifiedDictionaryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingFilePicker = false
    @State private var showingAddURLPatternSheet = false
    @State private var importError: Error?
    @State private var showingError = false
    @State private var deletionTarget: UnifiedDictionaryManagementDeletionTarget?
    @State private var showingDeleteConfirmation = false

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.termDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND termCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var termDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.termFrequencyDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND termFrequencyCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var frequencyDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.pitchDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND pitchesCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var pitchDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: AudioSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioSource.priority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO", NSNumber(value: true)),
        animation: .default
    )
    private var audioSources: FetchedResults<AudioSource>

    @FetchRequest(
        entity: TokenizerDictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \TokenizerDictionary.timeCompleted, ascending: false)],
        predicate: NSPredicate(format: "isComplete == YES AND pendingDeletion == NO AND isCurrent == YES", NSNumber(value: true)),
        animation: .default
    )
    private var tokenizerDictionaries: FetchedResults<TokenizerDictionary>

    @FetchRequest(
        entity: GrammarDictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GrammarDictionary.title, ascending: true)],
        predicate: NSPredicate(format: "isComplete == YES AND pendingDeletion == NO", NSNumber(value: true)),
        animation: .default
    )
    private var grammarDictionaries: FetchedResults<GrammarDictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.kanjiDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND kanjiCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var kanjiDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.kanjiFrequencyDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND kanjiFrequencyCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var kanjiFrequencyDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.ipaDisplayPriority, ascending: true)],
        predicate: NSPredicate(format: "isComplete == %@ AND pendingDeletion == NO AND ipaCount > 0", NSNumber(value: true)),
        animation: .default
    )
    private var ipaDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.timeQueued, ascending: true)],
        predicate: NSPredicate(format: "isComplete == NO AND pendingDeletion == NO"),
        animation: .default
    )
    private var incompleteDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: AudioSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioSource.timeQueued, ascending: true)],
        predicate: NSPredicate(format: "isComplete == NO AND pendingDeletion == NO"),
        animation: .default
    )
    private var incompleteAudioSources: FetchedResults<AudioSource>

    @FetchRequest(
        entity: TokenizerDictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \TokenizerDictionary.timeQueued, ascending: true)],
        predicate: NSPredicate(format: "isComplete == NO AND pendingDeletion == NO"),
        animation: .default
    )
    private var incompleteTokenizerDictionaries: FetchedResults<TokenizerDictionary>

    @FetchRequest(
        entity: GrammarDictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GrammarDictionary.timeQueued, ascending: true)],
        predicate: NSPredicate(format: "isComplete == NO AND pendingDeletion == NO"),
        animation: .default
    )
    private var incompleteGrammarDictionaries: FetchedResults<GrammarDictionary>

    @FetchRequest(
        entity: DictionaryUpdateTask.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DictionaryUpdateTask.timeQueued, ascending: true)],
        predicate: NSPredicate(
            format: "isStarted == YES AND downloadedFile == nil AND isComplete == NO AND isFailed == NO AND isCancelled == NO"
        ),
        animation: .default
    )
    private var dictionaryUpdateTasks: FetchedResults<DictionaryUpdateTask>

    @FetchRequest(
        entity: TokenizerDictionaryUpdateTask.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \TokenizerDictionaryUpdateTask.timeQueued, ascending: true)],
        predicate: NSPredicate(
            format: "isStarted == YES AND downloadedFile == nil AND isComplete == NO AND isFailed == NO AND isCancelled == NO"
        ),
        animation: .default
    )
    private var tokenizerUpdateTasks: FetchedResults<TokenizerDictionaryUpdateTask>

    @FetchRequest(
        entity: Dictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.title, ascending: true)],
        predicate: NSPredicate(
            format: "isComplete == %@ AND pendingDeletion == NO AND updateReady == %@",
            NSNumber(value: true),
            NSNumber(value: true)
        ),
        animation: .default
    )
    private var updatableDictionaries: FetchedResults<Dictionary>

    @FetchRequest(
        entity: TokenizerDictionary.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \TokenizerDictionary.name, ascending: true)],
        predicate: NSPredicate(
            format: "isComplete == %@ AND pendingDeletion == NO AND isCurrent == YES AND updateReady == %@",
            NSNumber(value: true),
            NSNumber(value: true)
        ),
        animation: .default
    )
    private var updatableTokenizerDictionaries: FetchedResults<TokenizerDictionary>

    private var hasImportActivity: Bool {
        !incompleteDictionaries.isEmpty
            || !incompleteAudioSources.isEmpty
            || !incompleteTokenizerDictionaries.isEmpty
            || !incompleteGrammarDictionaries.isEmpty
            || !updateTaskItems.isEmpty
    }

    private var updateTaskItems: [UnifiedDictionaryManagementUpdateTaskItem] {
        let dictionaryTasks = dictionaryUpdateTasks.map(UnifiedDictionaryManagementUpdateTaskItem.dictionary)
        let tokenizerTasks = tokenizerUpdateTasks.map(UnifiedDictionaryManagementUpdateTaskItem.tokenizerDictionary)
        return dictionaryTasks + tokenizerTasks
    }

    private var importItems: [UnifiedDictionaryManagementImportItem] {
        let dictionaries = incompleteDictionaries.map(UnifiedDictionaryManagementImportItem.dictionary)
        let audioSources = incompleteAudioSources.map(UnifiedDictionaryManagementImportItem.audioSource)
        let tokenizerDictionaries = incompleteTokenizerDictionaries.map(UnifiedDictionaryManagementImportItem.tokenizerDictionary)
        let grammarDictionaries = incompleteGrammarDictionaries.map(UnifiedDictionaryManagementImportItem.grammarDictionary)

        return (dictionaries + audioSources + tokenizerDictionaries + grammarDictionaries).sorted { lhs, rhs in
            if lhs.isStarted != rhs.isStarted {
                return lhs.isStarted
            }

            let lhsStopped = lhs.isFailed || lhs.isCancelled
            let rhsStopped = rhs.isFailed || rhs.isCancelled
            if lhsStopped != rhsStopped {
                return !lhsStopped
            }

            return (lhs.timeQueued ?? .distantPast) < (rhs.timeQueued ?? .distantPast)
        }
    }

    private var allSectionsEmpty: Bool {
        termDictionaries.isEmpty && frequencyDictionaries.isEmpty && pitchDictionaries.isEmpty
            && audioSources.isEmpty && kanjiDictionaries.isEmpty && kanjiFrequencyDictionaries.isEmpty
            && ipaDictionaries.isEmpty && tokenizerDictionaries.isEmpty && grammarDictionaries.isEmpty
            && !hasImportActivity && updatableDictionaries.isEmpty && updatableTokenizerDictionaries.isEmpty
    }

    var body: some View {
        List {
            if !updatableDictionaries.isEmpty || !updatableTokenizerDictionaries.isEmpty {
                Section {
                    Button("Update All", systemImage: "arrow.down.circle", action: updateAll)
                }
            }

            if hasImportActivity {
                UnifiedDictionaryManagementImportsSection(
                    updateTasks: updateTaskItems,
                    importItems: importItems,
                    onCancelImport: cancelImport,
                    onRemoveImport: removeImport
                )
            }

            UnifiedDictionaryManagementDictionarySection(
                title: "Term Dictionaries",
                dictionaries: Array(termDictionaries),
                footer: "Order determines display priority when multiple dictionaries have the same term.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(termDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.termDisplayPriority
                    )
                }
            )

            UnifiedDictionaryManagementDictionarySection(
                title: "Frequency Dictionaries",
                dictionaries: Array(frequencyDictionaries),
                footer: "The ranking dictionary is used to sort search results by frequency.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(frequencyDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.termFrequencyDisplayPriority
                    )
                }
            ) {
                if !frequencyDictionaries.isEmpty {
                    UnifiedDictionaryManagementRankingPicker(
                        title: "Ranking Dictionary",
                        dictionaries: Array(frequencyDictionaries),
                        enabledKey: \.termFrequencyEnabled,
                        onSelectionChange: setTermFrequencyRanking
                    )
                }
            }

            UnifiedDictionaryManagementDictionarySection(
                title: "Pitch Dictionaries",
                dictionaries: Array(pitchDictionaries),
                footer: "Order determines display priority for pitch accent data.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(pitchDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.pitchDisplayPriority
                    )
                }
            )

            UnifiedDictionaryManagementAudioSourcesSection(
                audioSources: Array(audioSources),
                onDelete: { source in
                    showDeletionConfirmation(for: .audioSource(source))
                },
                onMove: reorderAudioSources
            )

            if !grammarDictionaries.isEmpty {
                Section {
                    ForEach(grammarDictionaries, id: \.objectID) { grammarDictionary in
                        UnifiedGrammarDictionaryManagementRow(grammarDictionary: grammarDictionary)
                            .contextMenu {
                                Button(role: .destructive) {
                                    showDeletionConfirmation(for: .grammarDictionary(grammarDictionary))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Grammar Dictionaries")
                } footer: {
                    Text("Grammar dictionaries explain the structure of the language.")
                }
            }

            UnifiedDictionaryManagementDictionarySection(
                title: "Kanji Dictionaries",
                dictionaries: Array(kanjiDictionaries),
                footer: "Order determines display priority for kanji entries.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(kanjiDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.kanjiDisplayPriority
                    )
                }
            )

            UnifiedDictionaryManagementDictionarySection(
                title: "Kanji Frequency",
                dictionaries: Array(kanjiFrequencyDictionaries),
                footer: "The ranking dictionary is used to sort kanji search results by frequency.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(kanjiFrequencyDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.kanjiFrequencyDisplayPriority
                    )
                }
            ) {
                if !kanjiFrequencyDictionaries.isEmpty {
                    UnifiedDictionaryManagementRankingPicker(
                        title: "Ranking Dictionary",
                        dictionaries: Array(kanjiFrequencyDictionaries),
                        enabledKey: \.kanjiFrequencyEnabled,
                        onSelectionChange: setKanjiFrequencyRanking
                    )
                }
            }

            UnifiedDictionaryManagementDictionarySection(
                title: "IPA Dictionaries",
                dictionaries: Array(ipaDictionaries),
                footer: "Order determines display priority for IPA transcriptions.",
                onStartUpdate: startUpdate,
                onDelete: { dictionary in
                    showDeletionConfirmation(for: .dictionary(dictionary))
                },
                onMove: { from, to in
                    reorderDictionaries(
                        Array(ipaDictionaries),
                        from: from,
                        to: to,
                        priorityKey: \.ipaDisplayPriority
                    )
                }
            )

            Section {
                if let tokenizerDictionary = tokenizerDictionaries.first {
                    UnifiedTokenizerDictionaryManagementRow(
                        tokenizerDictionary: tokenizerDictionary,
                        onUpdate: {
                            startUpdate(tokenizerDictionary)
                        }
                    )
                } else {
                    Text("Import a tokenizer dictionary ZIP to enable furigana functionality.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Tokenizer Dictionary")
            } footer: {
                Text("The tokenizer dictionary is used for furigana generation. Importing a new tokenizer dictionary will replace the old one.")
            }

            if allSectionsEmpty {
                ContentUnavailableView(
                    "No Dictionaries",
                    systemImage: "book.closed",
                    description: Text("Import dictionaries and audio sources to get started")
                )
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Import ZIP Archive", systemImage: "doc.zipper") {
                        showingFilePicker = true
                    }
                    Button("Add Audio URL Pattern", systemImage: "link") {
                        showingAddURLPatternSheet = true
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Check for Updates", systemImage: "arrow.triangle.2.circlepath", action: checkForUpdates)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport(result:)
        )
        .sheet(isPresented: $showingAddURLPatternSheet) {
            NavigationStack {
                AddURLPatternAudioSourceView()
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                importError = nil
            }
        } message: {
            if let importError {
                Text(importError.localizedDescription)
            }
        }
        .alert(
            "Delete \(deletionTarget?.name ?? "")?",
            isPresented: $showingDeleteConfirmation,
            presenting: deletionTarget
        ) { target in
            Button("Delete", role: .destructive) {
                performDeletion(target)
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text(target.detailMessage)
        }
        .task {
            enableAllAudioSources()
        }
    }

    private func enableAllAudioSources() {
        let disabledAudioSources = audioSources.filter { !$0.enabled && !$0.pendingDeletion }
        guard !disabledAudioSources.isEmpty else { return }

        for audioSource in disabledAudioSources {
            audioSource.enabled = true
        }

        saveContext()
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    _ = try await ImportManager.shared.enqueueImport(from: url)
                } catch {
                    await MainActor.run {
                        present(error: error)
                    }
                }
            }

        case let .failure(error):
            present(error: error)
        }
    }

    private func checkForUpdates() {
        Task {
            _ = await DictionaryUpdateManager.shared.checkForUpdates()
        }
    }

    private func updateAll() {
        let dictionaryIDs = updatableDictionaries.map(\.objectID)
        let tokenizerDictionaryIDs = updatableTokenizerDictionaries.map(\.objectID)

        Task {
            await DictionaryUpdateManager.shared.enqueueUpdates(for: dictionaryIDs)
            await DictionaryUpdateManager.shared.enqueueTokenizerDictionaryUpdates(for: tokenizerDictionaryIDs)
        }
    }

    private func startUpdate(_ dictionary: Dictionary) {
        Task {
            do {
                _ = try await DictionaryUpdateManager.shared.enqueueUpdate(for: dictionary.objectID)
            } catch {
                await MainActor.run {
                    present(error: error)
                }
            }
        }
    }

    private func startUpdate(_ tokenizerDictionary: TokenizerDictionary) {
        Task {
            do {
                _ = try await DictionaryUpdateManager.shared.enqueueTokenizerDictionaryUpdate(for: tokenizerDictionary.objectID)
            } catch {
                await MainActor.run {
                    present(error: error)
                }
            }
        }
    }

    private func cancelImport(_ item: UnifiedDictionaryManagementImportItem) {
        Task {
            await ImportManager.shared.cancelImport(jobID: item.objectID)
        }
    }

    private func removeImport(_ item: UnifiedDictionaryManagementImportItem) {
        Task {
            switch item {
            case let .dictionary(dictionary):
                await ImportManager.shared.deleteDictionary(dictionaryID: dictionary.objectID)
            case let .audioSource(audioSource):
                await ImportManager.shared.deleteAudioSource(sourceID: audioSource.objectID)
            case let .tokenizerDictionary(tokenizerDictionary):
                await ImportManager.shared.deleteTokenizerDictionary(tokenizerDictionaryID: tokenizerDictionary.objectID)
            case let .grammarDictionary(grammarDictionary):
                await ImportManager.shared.deleteGrammarDictionary(grammarDictionaryID: grammarDictionary.objectID)
            }
        }
    }

    private func performDeletion(_ target: UnifiedDictionaryManagementDeletionTarget) {
        Task {
            switch target {
            case let .dictionary(dictionary):
                await ImportManager.shared.deleteDictionary(dictionaryID: dictionary.objectID)
            case let .audioSource(audioSource):
                await ImportManager.shared.deleteAudioSource(sourceID: audioSource.objectID)
            case let .grammarDictionary(grammarDictionary):
                await ImportManager.shared.deleteGrammarDictionary(grammarDictionaryID: grammarDictionary.objectID)
            }
        }
    }

    private func showDeletionConfirmation(for target: UnifiedDictionaryManagementDeletionTarget) {
        deletionTarget = target
        showingDeleteConfirmation = true
    }

    private func reorderDictionaries(
        _ dictionaries: [Dictionary],
        from source: IndexSet,
        to destination: Int,
        priorityKey: ReferenceWritableKeyPath<Dictionary, Int64>
    ) {
        var reorderedDictionaries = dictionaries
        reorderedDictionaries.move(fromOffsets: source, toOffset: destination)

        for (index, dictionary) in reorderedDictionaries.enumerated() {
            dictionary[keyPath: priorityKey] = Int64(index)
        }

        saveContext()
    }

    private func reorderAudioSources(from source: IndexSet, to destination: Int) {
        var reorderedAudioSources = Array(audioSources)
        reorderedAudioSources.move(fromOffsets: source, toOffset: destination)

        for (index, audioSource) in reorderedAudioSources.enumerated() {
            audioSource.priority = Int64(index)
        }

        saveContext()
    }

    private func setTermFrequencyRanking(_ selectedID: NSManagedObjectID?) {
        setFrequencyRanking(
            dictionaries: Array(frequencyDictionaries),
            selectedID: selectedID,
            enabledKey: \.termFrequencyEnabled
        )
    }

    private func setKanjiFrequencyRanking(_ selectedID: NSManagedObjectID?) {
        setFrequencyRanking(
            dictionaries: Array(kanjiFrequencyDictionaries),
            selectedID: selectedID,
            enabledKey: \.kanjiFrequencyEnabled
        )
    }

    private func setFrequencyRanking(
        dictionaries: [Dictionary],
        selectedID: NSManagedObjectID?,
        enabledKey: ReferenceWritableKeyPath<Dictionary, Bool>
    ) {
        for dictionary in dictionaries {
            dictionary[keyPath: enabledKey] = false
        }

        if let selectedID,
           let selectedDictionary = dictionaries.first(where: { $0.objectID == selectedID })
        {
            selectedDictionary[keyPath: enabledKey] = true
        }

        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            present(error: error)
        }
    }

    private func present(error: Error) {
        importError = error
        showingError = true
    }
}

#Preview {
    NavigationStack {
        UnifiedDictionaryManagementView()
    }
    .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
}
