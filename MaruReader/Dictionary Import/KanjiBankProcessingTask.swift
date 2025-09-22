//
//  KanjiBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

actor KanjiBankProcessingTask {
    static let batchSize = 500

    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "KanjiBankProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() {
        let container = persistentContainer
        let jobID = self.jobID

        task = Task {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            // Fetch format and kanji bank URLs on the context queue
            let (format, kanjiBankURLs): (Int64, [URL]) = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                guard let dictionary = job.dictionary else {
                    throw DictionaryImportError.databaseError
                }
                let format = dictionary.format
                guard let kanjiBankURLs = job.kanjiBanks as? [URL] else {
                    throw DictionaryImportError.databaseError
                }
                return (format, kanjiBankURLs)
            }

            if !kanjiBankURLs.isEmpty {
                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                        throw DictionaryImportError.databaseError
                    }
                    job.displayProgressMessage = "Processing kanji..."
                    try context.save()
                }

                if format == 3 {
                    let kanjiIterator = StreamingBankIterator<KanjiBankV3Entry>(
                        bankURLs: kanjiBankURLs,
                        dataFormat: Int(format)
                    )

                    var kanjiBatch: [KanjiBankV3Entry] = []
                    var processedCount = 0

                    for try await entry in kanjiIterator {
                        try Task.checkCancellation()

                        kanjiBatch.append(entry)
                        processedCount += 1

                        if kanjiBatch.count >= Self.batchSize {
                            let currentBatch = kanjiBatch
                            kanjiBatch.removeAll(keepingCapacity: true)

                            try await context.perform {
                                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                      let dictionary = job.dictionary
                                else {
                                    throw DictionaryImportError.databaseError
                                }

                                for entry in currentBatch {
                                    // Find or create Kanji entity
                                    let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.character, context: context)

                                    // Create KanjiEntry
                                    let kanjiEntry = KanjiEntry(context: context)
                                    kanjiEntry.id = UUID()
                                    kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                                    kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                                    kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                                    kanjiEntry.setValue(entry.stats, forKey: "stats")
                                    kanjiEntry.setValue(entry.tags, forKey: "tags")

                                    context.insert(kanjiEntry)

                                    // Link relationships
                                    kanjiEntry.kanji = kanji
                                    kanjiEntry.dictionary = dictionary

                                    // Link tags
                                    try DictionaryImportUtilities.linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                                }

                                try context.save()
                            }
                            try Task.checkCancellation()
                        }
                    }

                    // Process any remaining kanji in the batch
                    if !kanjiBatch.isEmpty {
                        let currentBatch = kanjiBatch
                        kanjiBatch.removeAll()

                        try await context.perform {
                            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                  let dictionary = job.dictionary
                            else {
                                throw DictionaryImportError.databaseError
                            }

                            for entry in currentBatch {
                                // Find or create Kanji entity
                                let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.character, context: context)

                                // Create KanjiEntry
                                let kanjiEntry = KanjiEntry(context: context)
                                kanjiEntry.id = UUID()
                                kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                                kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                                kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                                kanjiEntry.setValue(entry.stats, forKey: "stats")
                                kanjiEntry.setValue(entry.tags, forKey: "tags")

                                context.insert(kanjiEntry)

                                // Link relationships
                                kanjiEntry.kanji = kanji
                                kanjiEntry.dictionary = dictionary

                                // Link tags
                                try DictionaryImportUtilities.linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                            }

                            try context.save()
                        }
                        try Task.checkCancellation()
                    }

                } else if format == 1 {
                    let kanjiIterator = StreamingBankIterator<KanjiBankV1Entry>(
                        bankURLs: kanjiBankURLs,
                        dataFormat: Int(format)
                    )

                    var kanjiBatch: [KanjiBankV1Entry] = []
                    var processedCount = 0

                    for try await entry in kanjiIterator {
                        try Task.checkCancellation()

                        kanjiBatch.append(entry)
                        processedCount += 1

                        if kanjiBatch.count >= Self.batchSize {
                            let currentBatch = kanjiBatch
                            kanjiBatch.removeAll(keepingCapacity: true)

                            try await context.perform {
                                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                      let dictionary = job.dictionary
                                else {
                                    throw DictionaryImportError.databaseError
                                }

                                for entry in currentBatch {
                                    // Find or create Kanji entity
                                    let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.character, context: context)

                                    // Create KanjiEntry
                                    let kanjiEntry = KanjiEntry(context: context)
                                    kanjiEntry.id = UUID()
                                    kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                                    kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                                    kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                                    kanjiEntry.setValue([:], forKey: "stats") // V1 doesn't have stats
                                    kanjiEntry.setValue(entry.tags, forKey: "tags")

                                    context.insert(kanjiEntry)

                                    // Link relationships
                                    kanjiEntry.kanji = kanji
                                    kanjiEntry.dictionary = dictionary

                                    // Link tags
                                    try DictionaryImportUtilities.linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                                }

                                try context.save()
                            }
                            try Task.checkCancellation()
                        }
                    }

                    // Process any remaining kanji in the batch
                    if !kanjiBatch.isEmpty {
                        let currentBatch = kanjiBatch
                        kanjiBatch.removeAll()

                        try await context.perform {
                            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                  let dictionary = job.dictionary
                            else {
                                throw DictionaryImportError.databaseError
                            }

                            for entry in currentBatch {
                                // Find or create Kanji entity
                                let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.character, context: context)

                                // Create KanjiEntry
                                let kanjiEntry = KanjiEntry(context: context)
                                kanjiEntry.id = UUID()
                                kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                                kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                                kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                                kanjiEntry.setValue([:], forKey: "stats") // V1 doesn't have stats
                                kanjiEntry.setValue(entry.tags, forKey: "tags")

                                context.insert(kanjiEntry)

                                // Link relationships
                                kanjiEntry.kanji = kanji
                                kanjiEntry.dictionary = dictionary

                                // Link tags
                                try DictionaryImportUtilities.linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                            }

                            try context.save()
                        }
                        try Task.checkCancellation()
                    }
                }
            }

            // Mark kanji banks as processed
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.setValue(kanjiBankURLs, forKey: "processedKanjiBanks")
                job.displayProgressMessage = "Processed kanji."
                try context.save()
            }

            try Task.checkCancellation()
        }
    }
}
