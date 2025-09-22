//
//  TermBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

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
                    let termIterator = StreamingBankIterator<TermBankV3Entry>(
                        bankURLs: termBankURLs,
                        dataFormat: Int(format)
                    )

                    var termBatch: [TermBankV3Entry] = []
                    var processedCount = 0

                    for try await entry in termIterator {
                        try Task.checkCancellation()

                        termBatch.append(entry)
                        processedCount += 1

                        if termBatch.count >= Self.batchSize {
                            let currentBatch = termBatch
                            termBatch.removeAll(keepingCapacity: true)

                            try await context.perform {
                                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                      let dictionary = job.dictionary
                                else {
                                    throw DictionaryImportError.databaseError
                                }

                                for entry in currentBatch {
                                    // Find or create Term entity
                                    let term = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

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

                                    // Link tags
                                    try DictionaryImportUtilities.linkTagsToTermEntry(termEntry, termTags: entry.termTags, definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                                }

                                try context.save()
                            }
                            try Task.checkCancellation()
                        }
                    }

                    // Process any remaining terms in the batch
                    if !termBatch.isEmpty {
                        let currentBatch = termBatch
                        termBatch.removeAll()

                        try await context.perform {
                            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                  let dictionary = job.dictionary
                            else {
                                throw DictionaryImportError.databaseError
                            }

                            for entry in currentBatch {
                                // Find or create Term entity
                                let term = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

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

                                // Link tags
                                try DictionaryImportUtilities.linkTagsToTermEntry(termEntry, termTags: entry.termTags, definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                            }

                            try context.save()
                        }
                        try Task.checkCancellation()
                    }

                } else if format == 1 {
                    let termIterator = StreamingBankIterator<TermBankV1Entry>(
                        bankURLs: termBankURLs,
                        dataFormat: Int(format)
                    )

                    var termBatch: [TermBankV1Entry] = []
                    var processedCount = 0

                    for try await entry in termIterator {
                        try Task.checkCancellation()

                        termBatch.append(entry)
                        processedCount += 1

                        if termBatch.count >= Self.batchSize {
                            let currentBatch = termBatch
                            termBatch.removeAll(keepingCapacity: true)

                            try await context.perform {
                                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                      let dictionary = job.dictionary
                                else {
                                    throw DictionaryImportError.databaseError
                                }

                                for entry in currentBatch {
                                    // Find or create Term entity
                                    let term = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

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

                                    // Link tags (V1 only has definition tags)
                                    try DictionaryImportUtilities.linkTagsToTermEntry(termEntry, termTags: [], definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                                }

                                try context.save()
                            }
                            try Task.checkCancellation()
                        }
                    }

                    // Process any remaining terms in the batch
                    if !termBatch.isEmpty {
                        let currentBatch = termBatch
                        termBatch.removeAll()

                        try await context.perform {
                            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                                  let dictionary = job.dictionary
                            else {
                                throw DictionaryImportError.databaseError
                            }

                            for entry in currentBatch {
                                // Find or create Term entity
                                let term = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

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

                                // Link tags (V1 only has definition tags)
                                try DictionaryImportUtilities.linkTagsToTermEntry(termEntry, termTags: [], definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                            }

                            try context.save()
                        }
                        try Task.checkCancellation()
                    }
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
}
