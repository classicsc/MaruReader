//
//  KanjiMetaBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import AsyncAlgorithms
import CoreData
import Foundation
import os.log

actor KanjiMetaBankProcessingTask {
    static let batchSize = 5000

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

                try await processKanjiMetaBankV3(kanjiMetaBankURLs, jobID: jobID, context: context)
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

    private func processKanjiMetaBankV3(_ kanjiMetaBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        // Build initial kanji cache once before processing batches
        let kanjiCache: [String: NSManagedObjectID] = try await context.perform {
            guard let _ = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.databaseError
            }

            return try DictionaryImportUtilities.prefetchAllExistingKanji(context: context)
        }

        var kanjiCacheMutable = kanjiCache

        let kanjiMetaChannel = AsyncThrowingChannel<KanjiMetaBankV3Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in kanjiMetaBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(
                            bankURLs: [url],
                            dataFormat: 3
                        )

                        do {
                            for try await entry in iterator {
                                await kanjiMetaChannel.send(entry)
                            }
                        } catch {
                            kanjiMetaChannel.fail(error)
                        }
                    }
                }
            }
            kanjiMetaChannel.finish()
        }

        var kanjiMetaBatch: [KanjiMetaBankV3Entry] = []

        for try await entry in kanjiMetaChannel {
            try Task.checkCancellation()

            kanjiMetaBatch.append(entry)

            if kanjiMetaBatch.count >= Self.batchSize {
                let currentBatch = kanjiMetaBatch
                kanjiMetaBatch.removeAll(keepingCapacity: true)

                try await processKanjiMetaBatch(currentBatch, kanjiCache: &kanjiCacheMutable, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining kanji meta entries in the batch
        if !kanjiMetaBatch.isEmpty {
            let currentBatch = kanjiMetaBatch
            kanjiMetaBatch.removeAll()

            try await processKanjiMetaBatch(currentBatch, kanjiCache: &kanjiCacheMutable, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processKanjiMetaBatch(_ batch: [KanjiMetaBankV3Entry], kanjiCache: inout [String: NSManagedObjectID], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        let cacheSnapshot = kanjiCache
        let updatedCache = try await context.perform {
            var cache = cacheSnapshot
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            for entry in batch {
                // Find or create Kanji entity using cache
                let kanji = try DictionaryImportUtilities.findOrCreateKanjiWithCache(
                    character: entry.kanji,
                    cache: &cache,
                    context: context
                )

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

            // Update cache with newly created kanji before reset
            DictionaryImportUtilities.updateKanjiCacheWithNewObjects(cache: &cache, context: context)

            context.reset()
            return cache
        }
        kanjiCache = updatedCache
    }
}
