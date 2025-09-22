//
//  KanjiMetaBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

actor KanjiMetaBankProcessingTask {
    static let batchSize = 500

    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "KanjiMetaBankProcessingTask")

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

            // Fetch format and kanji meta bank URLs on the context queue
            let (format, kanjiMetaBankURLs): (Int64, [URL]) = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                guard let dictionary = job.dictionary else {
                    throw DictionaryImportError.databaseError
                }
                let format = dictionary.format
                guard let kanjiMetaBankURLs = job.kanjiMetaBanks as? [URL] else {
                    throw DictionaryImportError.databaseError
                }
                return (format, kanjiMetaBankURLs)
            }

            if !kanjiMetaBankURLs.isEmpty {
                // Process kanji meta banks only for format 3
                guard format == 3 else {
                    throw DictionaryImportError.invalidData
                }

                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                        throw DictionaryImportError.databaseError
                    }
                    job.displayProgressMessage = "Processing kanji metadata..."
                    try context.save()
                }

                let kanjiMetaIterator = StreamingBankIterator<KanjiMetaBankV3Entry>(
                    bankURLs: kanjiMetaBankURLs,
                    dataFormat: Int(format)
                )

                var kanjiMetaBatch: [KanjiMetaBankV3Entry] = []
                var processedCount = 0

                for try await entry in kanjiMetaIterator {
                    try Task.checkCancellation()

                    kanjiMetaBatch.append(entry)
                    processedCount += 1

                    if kanjiMetaBatch.count >= Self.batchSize {
                        let currentBatch = kanjiMetaBatch
                        kanjiMetaBatch.removeAll(keepingCapacity: true)

                        try await context.perform {
                            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                  let dictionary = job.dictionary
                            else {
                                throw DictionaryImportError.databaseError
                            }

                            for entry in currentBatch {
                                // Find or create Kanji entity
                                let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.kanji, context: context)

                                // Create KanjiFrequencyEntry
                                let frequencyEntry = KanjiFrequencyEntry(context: context)
                                frequencyEntry.id = UUID()

                                // Handle different frequency formats
                                switch entry.frequency {
                                case let .number(value):
                                    frequencyEntry.frequencyValue = value
                                    frequencyEntry.displayFrequency = String(value)
                                case let .string(displayValue):
                                    // Try to parse as number, default to 0 if can't parse
                                    frequencyEntry.frequencyValue = Double(displayValue) ?? 0.0
                                    frequencyEntry.displayFrequency = displayValue
                                case let .object(value, displayValue):
                                    frequencyEntry.frequencyValue = value
                                    frequencyEntry.displayFrequency = displayValue ?? String(value)
                                }

                                context.insert(frequencyEntry)

                                // Link relationships
                                frequencyEntry.kanji = kanji
                                frequencyEntry.dictionary = dictionary
                            }

                            try context.save()
                            context.reset()
                        }
                        try Task.checkCancellation()
                    }
                }

                // Process any remaining kanji meta entries in the batch
                if !kanjiMetaBatch.isEmpty {
                    let currentBatch = kanjiMetaBatch
                    kanjiMetaBatch.removeAll()

                    try await context.perform {
                        guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                              let dictionary = job.dictionary
                        else {
                            throw DictionaryImportError.databaseError
                        }

                        for entry in currentBatch {
                            // Find or create Kanji entity
                            let kanji = try DictionaryImportUtilities.findOrCreateKanji(character: entry.kanji, context: context)

                            // Create KanjiFrequencyEntry
                            let frequencyEntry = KanjiFrequencyEntry(context: context)
                            frequencyEntry.id = UUID()

                            // Handle different frequency formats
                            switch entry.frequency {
                            case let .number(value):
                                frequencyEntry.frequencyValue = value
                                frequencyEntry.displayFrequency = String(value)
                            case let .string(displayValue):
                                // Try to parse as number, default to 0 if can't parse
                                frequencyEntry.frequencyValue = Double(displayValue) ?? 0.0
                                frequencyEntry.displayFrequency = displayValue
                            case let .object(value, displayValue):
                                frequencyEntry.frequencyValue = value
                                frequencyEntry.displayFrequency = displayValue ?? String(value)
                            }

                            context.insert(frequencyEntry)

                            // Link relationships
                            frequencyEntry.kanji = kanji
                            frequencyEntry.dictionary = dictionary
                        }

                        try context.save()
                    }
                    try Task.checkCancellation()
                }
            }

            // Mark kanji meta banks as processed
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.setValue(kanjiMetaBankURLs, forKey: "processedKanjiMetaBanks")
                job.displayProgressMessage = "Processed kanji metadata."
                try context.save()
            }

            try Task.checkCancellation()
        }
    }
}
