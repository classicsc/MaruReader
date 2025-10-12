//
//  TagBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import AsyncAlgorithms
import CoreData
import Foundation
import os.log

/// A task to process and insert tag bank entries into Core Data.
actor TagBankProcessingTask {
    /// The number of tags to process in each batch before saving to Core Data.
    static let batchSize = 500

    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TagBankProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        // Fetch format and tag bank URLs on the context queue and return a typed tuple
        let (format, tagBankURLs): (Int64, [URL]) = try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.databaseError
            }
            guard let dictionary = job.dictionary else {
                throw DictionaryImportError.databaseError
            }
            let format = dictionary.format
            guard let tagBankURLs = job.tagBanks as? [URL] else {
                throw DictionaryImportError.databaseError
            }
            return (format, tagBankURLs)
        }

        if !tagBankURLs.isEmpty {
            // Tag banks should only be processed for format 3
            guard format == 3 else {
                throw DictionaryImportError.invalidData
            }

            try await processTagBankV3(tagBankURLs, jobID: jobID, context: context)
        }

        // Mark tag banks as processed
        try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.databaseError
            }
            job.setValue(tagBankURLs, forKey: "processedTagBanks")
            try context.save()
        }
    }

    private func processTagBankV3(_ tagBankURLs: [URL], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        let tagChannel = AsyncThrowingChannel<TagBankV3Entry, Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in tagBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TagBankV3Entry>(
                            bankURLs: [url],
                            dataFormat: 3
                        )

                        do {
                            for try await entry in iterator {
                                await tagChannel.send(entry)
                            }
                        } catch {
                            tagChannel.fail(error)
                        }
                    }
                }
            }
            tagChannel.finish()
        }

        var tagBatch: [TagBankV3Entry] = []

        for try await entry in tagChannel {
            try Task.checkCancellation()

            tagBatch.append(entry)

            if tagBatch.count >= Self.batchSize {
                let currentBatch = tagBatch
                tagBatch.removeAll(keepingCapacity: true)

                try await processBatch(currentBatch, jobID: jobID, context: context)
                try Task.checkCancellation()
            }
        }

        // Process any remaining tags in the batch
        if !tagBatch.isEmpty {
            let currentBatch = tagBatch
            tagBatch.removeAll()

            try await processBatch(currentBatch, jobID: jobID, context: context)
            try Task.checkCancellation()
        }
    }

    private func processBatch(_ batch: [TagBankV3Entry], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }

            for tagEntry in batch {
                let tag = DictionaryTagMeta(context: context)
                tag.id = UUID()
                tag.name = tagEntry.name
                tag.category = tagEntry.category
                tag.order = Double(tagEntry.order)
                tag.notes = tagEntry.notes
                tag.score = Double(tagEntry.score)

                context.insert(tag)
                tag.dictionary = dictionary
            }

            try context.save()
            context.reset()
        }
    }
}
