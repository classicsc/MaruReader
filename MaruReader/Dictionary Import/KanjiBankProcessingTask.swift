//
//  KanjiBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import AsyncAlgorithms
import CoreData
import Foundation
import os.log

actor KanjiBankProcessingTask {
    static let batchSize = 5000

    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "KanjiBankProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID

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
                try await processKanjiBankV3(kanjiBankURLs, jobID: jobID, context: context)
            } else if format == 1 {
                try await processKanjiBankV1(kanjiBankURLs, jobID: jobID, context: context)
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

    private func processKanjiBankV3(_ kanjiBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        // Build initial caches once before processing batches
        let (kanjiCache, tagCache): ([String: NSManagedObjectID], [String: NSManagedObjectID]) = try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            let kanjiCache = try DictionaryImportUtilities.prefetchAllExistingKanji(context: context)
            let tagCache = try DictionaryImportUtilities.prefetchDictionaryTags(dictionary: dictionary, context: context)

            return (kanjiCache, tagCache)
        }

        var kanjiCacheMutable = kanjiCache

        let kanjiChannel = AsyncThrowingChannel<KanjiBankV3Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in kanjiBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
                            bankURLs: [url],
                            dataFormat: 3
                        )

                        do {
                            for try await entry in iterator {
                                await kanjiChannel.send(entry)
                            }
                        } catch {
                            kanjiChannel.fail(error)
                        }
                    }
                }
            }
            kanjiChannel.finish()
        }

        var kanjiBatch: [KanjiBankV3Entry] = []

        for try await entry in kanjiChannel {
            try Task.checkCancellation()

            kanjiBatch.append(entry)

            if kanjiBatch.count >= Self.batchSize {
                let currentBatch = kanjiBatch
                kanjiBatch.removeAll(keepingCapacity: true)

                try await processV3Batch(currentBatch, kanjiCache: &kanjiCacheMutable, tagCache: tagCache, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining kanji in the batch
        if !kanjiBatch.isEmpty {
            let currentBatch = kanjiBatch
            kanjiBatch.removeAll()

            try await processV3Batch(currentBatch, kanjiCache: &kanjiCacheMutable, tagCache: tagCache, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processKanjiBankV1(_ kanjiBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        // Build initial caches once before processing batches
        let (kanjiCache, tagCache): ([String: NSManagedObjectID], [String: NSManagedObjectID]) = try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            let kanjiCache = try DictionaryImportUtilities.prefetchAllExistingKanji(context: context)
            let tagCache = try DictionaryImportUtilities.prefetchDictionaryTags(dictionary: dictionary, context: context)

            return (kanjiCache, tagCache)
        }

        var kanjiCacheMutable = kanjiCache

        let kanjiChannel = AsyncThrowingChannel<KanjiBankV1Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in kanjiBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiBankV1Entry>(
                            bankURLs: [url],
                            dataFormat: 1
                        )

                        do {
                            for try await entry in iterator {
                                await kanjiChannel.send(entry)
                            }
                        } catch {
                            kanjiChannel.fail(error)
                        }
                    }
                }
            }
            kanjiChannel.finish()
        }

        var kanjiBatch: [KanjiBankV1Entry] = []

        for try await entry in kanjiChannel {
            try Task.checkCancellation()

            kanjiBatch.append(entry)

            if kanjiBatch.count >= Self.batchSize {
                let currentBatch = kanjiBatch
                kanjiBatch.removeAll(keepingCapacity: true)

                try await processV1Batch(currentBatch, kanjiCache: &kanjiCacheMutable, tagCache: tagCache, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining kanji in the batch
        if !kanjiBatch.isEmpty {
            let currentBatch = kanjiBatch
            kanjiBatch.removeAll()

            try await processV1Batch(currentBatch, kanjiCache: &kanjiCacheMutable, tagCache: tagCache, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processV3Batch(_ batch: [KanjiBankV3Entry], kanjiCache: inout [String: NSManagedObjectID], tagCache: [String: NSManagedObjectID], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
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
                    character: entry.character,
                    cache: &cache,
                    context: context
                )

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

                // Link tags using cache
                DictionaryImportUtilities.linkTagsToKanjiEntryWithCache(
                    kanjiEntry,
                    tags: entry.tags,
                    tagCache: tagCache,
                    context: context
                )
            }

            try context.save()

            // Update cache with newly created kanji before reset
            DictionaryImportUtilities.updateKanjiCacheWithNewObjects(cache: &cache, context: context)

            context.reset()
            return cache
        }
        kanjiCache = updatedCache
    }

    private func processV1Batch(_ batch: [KanjiBankV1Entry], kanjiCache: inout [String: NSManagedObjectID], tagCache: [String: NSManagedObjectID], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
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
                    character: entry.character,
                    cache: &cache,
                    context: context
                )

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

                // Link tags using cache
                DictionaryImportUtilities.linkTagsToKanjiEntryWithCache(
                    kanjiEntry,
                    tags: entry.tags,
                    tagCache: tagCache,
                    context: context
                )
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
