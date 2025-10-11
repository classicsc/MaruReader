//
//  TermBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import AsyncAlgorithms
import CoreData
import Foundation
import os.log

actor TermBankProcessingTask {
    static let batchSize = 500

    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermBankProcessingTask")

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

            // Fetch format and term bank URLs on the context queue
            let (format, termBankURLs): (Int64, [URL]) = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                guard let dictionary = job.dictionary else {
                    throw DictionaryImportError.databaseError
                }
                let format = dictionary.format
                guard let termBankURLs = job.termBanks as? [URL] else {
                    throw DictionaryImportError.databaseError
                }
                return (format, termBankURLs)
            }

            if !termBankURLs.isEmpty {
                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                        throw DictionaryImportError.databaseError
                    }
                    job.displayProgressMessage = "Processing terms..."
                    try context.save()
                }

                if format == 3 {
                    try await processTermBankV3(termBankURLs, jobID: jobID, context: context)
                } else if format == 1 {
                    try await processTermBankV1(termBankURLs, jobID: jobID, context: context)
                }
            }

            // Mark term banks as processed
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.setValue(termBankURLs, forKey: "processedTermBanks")
                job.displayProgressMessage = "Processed terms."
                try context.save()
            }

            try Task.checkCancellation()
        }
    }

    private func processTermBankV3(_ termBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        let termChannel = AsyncThrowingChannel<TermBankV3Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in termBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TermBankV3Entry>(
                            bankURLs: [url],
                            dataFormat: 3
                        )

                        do {
                            for try await entry in iterator {
                                await termChannel.send(entry)
                            }
                        } catch {
                            termChannel.fail(error)
                        }
                    }
                }
            }
            termChannel.finish()
        }

        var termBatch: [TermBankV3Entry] = []

        for try await entry in termChannel {
            try Task.checkCancellation()

            termBatch.append(entry)

            if termBatch.count >= Self.batchSize {
                let currentBatch = termBatch
                termBatch.removeAll(keepingCapacity: true)

                try await processV3Batch(currentBatch, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining terms in the batch
        if !termBatch.isEmpty {
            let currentBatch = termBatch
            termBatch.removeAll()

            try await processV3Batch(currentBatch, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processTermBankV1(_ termBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        let termChannel = AsyncThrowingChannel<TermBankV1Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in termBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TermBankV1Entry>(
                            bankURLs: [url],
                            dataFormat: 1
                        )

                        do {
                            for try await entry in iterator {
                                await termChannel.send(entry)
                            }
                        } catch {
                            termChannel.fail(error)
                        }
                    }
                }
            }
            termChannel.finish()
        }

        var termBatch: [TermBankV1Entry] = []

        for try await entry in termChannel {
            try Task.checkCancellation()

            termBatch.append(entry)

            if termBatch.count >= Self.batchSize {
                let currentBatch = termBatch
                termBatch.removeAll(keepingCapacity: true)

                try await processV1Batch(currentBatch, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining terms in the batch
        if !termBatch.isEmpty {
            let currentBatch = termBatch
            termBatch.removeAll()

            try await processV1Batch(currentBatch, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processV3Batch(_ batch: [TermBankV3Entry], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            // Prefetch existing terms for this batch
            let termKeys = batch.map { (expression: $0.expression, reading: $0.reading) }
            var termCache = try DictionaryImportUtilities.prefetchExistingTerms(batch: termKeys, context: context)

            // Prefetch dictionary tags
            let tagCache = try DictionaryImportUtilities.prefetchDictionaryTags(dictionary: dictionary, context: context)

            for entry in batch {
                // Find or create Term entity using cache
                let term = try DictionaryImportUtilities.findOrCreateTermWithCache(
                    expression: entry.expression,
                    reading: entry.reading,
                    cache: &termCache,
                    context: context
                )

                // Create TermEntry
                let termEntry = TermEntry(context: context)
                termEntry.id = UUID()
                termEntry.setValue(entry.definitionTags, forKey: "definitionTags")
                termEntry.setValue(entry.rules, forKey: "rules")
                termEntry.score = entry.score
                termEntry.setValue(entry.glossary, forKey: "glossary")
                termEntry.sequence = Int64(entry.sequence)
                termEntry.setValue(entry.termTags, forKey: "termTags")

                context.insert(termEntry)

                // Link relationships
                termEntry.term = term
                termEntry.dictionary = dictionary

                // Link tags using cache
                DictionaryImportUtilities.linkTagsToTermEntryWithCache(
                    termEntry,
                    termTags: entry.termTags,
                    definitionTags: entry.definitionTags,
                    tagCache: tagCache
                )
            }

            try context.save()
            context.reset()
        }
    }

    private func processV1Batch(_ batch: [TermBankV1Entry], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            // Prefetch existing terms for this batch
            let termKeys = batch.map { (expression: $0.expression, reading: $0.reading) }
            var termCache = try DictionaryImportUtilities.prefetchExistingTerms(batch: termKeys, context: context)

            // Prefetch dictionary tags
            let tagCache = try DictionaryImportUtilities.prefetchDictionaryTags(dictionary: dictionary, context: context)

            for entry in batch {
                // Find or create Term entity using cache
                let term = try DictionaryImportUtilities.findOrCreateTermWithCache(
                    expression: entry.expression,
                    reading: entry.reading,
                    cache: &termCache,
                    context: context
                )

                // Create TermEntry
                let termEntry = TermEntry(context: context)
                termEntry.id = UUID()
                termEntry.setValue(entry.definitionTags, forKey: "definitionTags")
                termEntry.setValue(entry.rules, forKey: "rules")
                termEntry.score = entry.score
                termEntry.setValue(entry.glossary, forKey: "glossary")
                termEntry.sequence = 0 // V1 doesn't have sequence
                termEntry.setValue([], forKey: "termTags") // V1 doesn't have termTags

                context.insert(termEntry)

                // Link relationships
                termEntry.term = term
                termEntry.dictionary = dictionary

                // Link tags using cache (V1 only has definition tags)
                DictionaryImportUtilities.linkTagsToTermEntryWithCache(
                    termEntry,
                    termTags: [],
                    definitionTags: entry.definitionTags,
                    tagCache: tagCache
                )
            }

            try context.save()
            context.reset()
        }
    }
}
