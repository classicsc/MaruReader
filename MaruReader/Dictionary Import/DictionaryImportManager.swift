//
//  DictionaryImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/20/25.
//

import CoreData
import Foundation
import os.log
import Zip

actor DictionaryImportManager {
    static let shared = DictionaryImportManager()

    // Constants
    /// The supported dictionary format versions
    static let supportedFormats: Set<Int> = [1, 3]

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var container: NSPersistentContainer
    private var logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryImport")

    private init() {
        container = PersistenceController.shared.container
    }

    // Initializer for testing with custom container
    init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Enqueue a new dictionary import from the given ZIP file URL.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        // Create DictionaryZIPFileImport in Core Data (on MainActor)
        let context = container.newBackgroundContext()
        let job = DictionaryZIPFileImport(context: context)
        let jobID = UUID()
        job.id = jobID
        job.file = zipURL
        // Use application support directory with job ID as working directory for resume capability
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let workingDir = appSupport.appendingPathComponent("DictionaryImports").appendingPathComponent(jobID.uuidString)
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        job.workingDirectory = workingDir
        job.timeQueued = Date()
        try context.save()
        let importJob = job.objectID

        queue.append(importJob)
        processNextIfIdle()
        return importJob
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the DictionaryZIPFileImport to cancel.
    func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            await MainActor.run {
                let context = PersistenceController.shared.container.viewContext
                if let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport {
                    job.isCancelled = true
                    job.timeCancelled = Date()
                    try? context.save()
                }
            }
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the DictionaryZIPFileImport to wait for.
    func waitForCompletion(jobID: NSManagedObjectID) async {
        while true {
            if currentJobID == jobID {
                // Wait for current task to finish
                await currentTask?.value
                return
            } else if !queue.contains(jobID) {
                // Job is no longer in queue, must be done
                return
            } else {
                // Sleep briefly and check again
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    private func processNextIfIdle() {
        guard currentTask == nil, let nextJob = queue.first else { return }

        currentTask = Task {
            await runImport(for: nextJob)
            queue.removeFirst()
            currentTask = nil
            currentJobID = nil
            processNextIfIdle() // Move on to next
        }
        currentJobID = nextJob
    }

    private func runImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting import job \(jobID)")
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
            logger.error("Import job \(jobID) not found in context")
            return
        }
        do {
            job.isStarted = true
            job.timeStarted = Date()
            job.displayProgressMessage = "Starting import..."
            logger.debug("Import job \(jobID) started")
            try context.save()
            try Task.checkCancellation()
            try await unzip(job, context: context)
            logger.debug("Import job \(jobID) unzipped")
            try Task.checkCancellation()
            try await processIndex(job, context: context)
            logger.debug("Import job \(jobID) index processed")
            try Task.checkCancellation()
            try await processTagBanks(job, context: context)
            logger.debug("Import job \(jobID) tag banks processed")
            try Task.checkCancellation()
            try await processTermBanks(job, context: context)
            logger.debug("Import job \(jobID) term banks processed")
            try Task.checkCancellation()
            try await copyMedia(job)
            logger.debug("Import job \(jobID) media copied")
            try Task.checkCancellation()

            job.isComplete = true
            job.dictionary?.isComplete = true
            job.timeCompleted = Date()
            job.displayProgressMessage = "Import complete."
            try context.save()
        } catch is CancellationError {
            job.isCancelled = true
            job.timeCancelled = Date()
            if let dict = job.dictionary {
                context.delete(dict)
            }
            try? context.save()
        } catch {
            job.isFailed = true
            job.displayProgressMessage = error.localizedDescription
            job.timeFailed = Date()
            if let dict = job.dictionary {
                context.delete(dict)
            }
            try? context.save()
        }

        await cleanup(job)
    }
}

extension DictionaryImportManager {
    private func unzip(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        guard let jobURL = job.file else {
            throw DictionaryImportError.missingFile
        }
        guard let jobDirectory = job.workingDirectory else {
            throw DictionaryImportError.noWorkingDirectory
        }

        // Update progress message
        job.displayProgressMessage = "Extracting dictionary archive..."

        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw DictionaryImportError.missingFile
        }

        guard jobURL.startAccessingSecurityScopedResource() else {
            throw DictionaryImportError.fileAccessDenied
        }

        defer {
            jobURL.stopAccessingSecurityScopedResource()
        }

        do {
            // Use Zip.unzipFile to extract the archive
            // This preserves directory structure automatically
            try Zip.unzipFile(jobURL, destination: jobDirectory, overwrite: true, password: nil)

            _ = try FileManager.default.contentsOfDirectory(at: jobDirectory, includingPropertiesForKeys: nil)

            // Update job status
            job.archiveExtracted = true
            job.displayProgressMessage = "Extracted dictionary archive."
            try context.save()

        } catch let error as NSError {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
    }

    private func processIndex(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Load index.json
        // Create Dictionary entity
        // Populate job.termBanks, job.kanjiBanks, etc.
        // Index can contain tag metadata that needs to be processed

        guard let workingDir = job.workingDirectory else {
            throw DictionaryImportError.noWorkingDirectory
        }
        let indexURL = workingDir.appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw DictionaryImportError.notADictionary
        }

        // Decode index.json to type DictionaryIndex
        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()
        let index = try decoder.decode(DictionaryIndex.self, from: data)

        // Ensure format is supported
        guard let format = index.format, DictionaryImportManager.supportedFormats.contains(format) else {
            throw DictionaryImportError.unsupportedFormat
        }

        // Find the bank files in working directory
        let contents = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: nil)
        let termBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_bank_") && $0.pathExtension == "json" }
        let kanjiBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_bank_") && $0.pathExtension == "json" }
        let termMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_meta_bank_") && $0.pathExtension == "json" }
        let kanjiMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_meta_bank_") && $0.pathExtension == "json" }
        let tagBanks = contents.filter { $0.lastPathComponent.hasPrefix("tag_bank_") && $0.pathExtension == "json" }

        // Dictionary must have at least one of termBanks, kanjiBanks, termMetaBanks, kanjiMetaBanks
        if termBanks.isEmpty, kanjiBanks.isEmpty, termMetaBanks.isEmpty, kanjiMetaBanks.isEmpty {
            throw DictionaryImportError.notADictionary
        }

        // Create the Dictionary entity and link to job
        let dictionary = Dictionary(context: context)
        dictionary.id = UUID()
        dictionary.title = index.title
        dictionary.attribution = index.attribution
        dictionary.downloadURL = index.downloadUrl
        dictionary.displayDescription = index.description
        dictionary.frequencyMode = index.frequencyMode?.rawValue
        dictionary.sequenced = index.sequenced ?? false
        dictionary.author = index.author
        dictionary.indexURL = index.indexUrl
        dictionary.isUpdatable = index.isUpdatable ?? false
        dictionary.minimumYomitanVersion = index.minimumYomitanVersion
        dictionary.sourceLanguage = index.sourceLanguage
        dictionary.targetLanguage = index.targetLanguage
        dictionary.revision = index.revision
        dictionary.format = Int64(format)

        context.insert(dictionary)

        // If the index has embedded tags, create DictionaryTagMeta entities
        if let embeddedTags = index.tagMeta {
            for (name, entry) in embeddedTags {
                let tag = DictionaryTagMeta(context: context)
                tag.id = UUID()
                tag.name = name
                tag.category = entry.category
                tag.order = Double(entry.order ?? 0)
                tag.notes = entry.notes
                tag.score = Double(entry.score ?? 0)

                context.insert(tag)

                tag.dictionary = dictionary
            }
        }

        job.dictionary = dictionary
        job.setValue(termBanks, forKey: "termBanks")
        job.setValue(kanjiBanks, forKey: "kanjiBanks")
        job.setValue(termMetaBanks, forKey: "termMetaBanks")
        job.setValue(kanjiMetaBanks, forKey: "kanjiMetaBanks")
        job.setValue(tagBanks, forKey: "tagBanks")

        job.indexProcessed = true
        job.displayProgressMessage = "Processed dictionary index."

        try context.save()
    }

    private func processTagBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Get the dictionary entity
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        // Get the dictionary format
        let format = dictionary.format

        // Process tag banks
        guard let tagBankURLs = job.tagBanks as? [URL] else {
            throw DictionaryImportError.databaseError
        }

        if !tagBankURLs.isEmpty {
            let tagIterator = StreamingBankIterator<TagBankV3Entry>(
                bankURLs: tagBankURLs,
                dataFormat: Int(format)
            )

            for try await entry in tagIterator {
                // Insert into Core Data
                let tag = DictionaryTagMeta(context: context)
                tag.id = UUID()
                tag.name = entry.name
                tag.category = entry.category
                tag.order = Double(entry.order)
                tag.notes = entry.notes
                tag.score = Double(entry.score)

                context.insert(tag)

                tag.dictionary = dictionary
            }
        }

        job.setValue(tagBankURLs, forKey: "processedTagBanks")
        try context.save()
        try Task.checkCancellation()
    }

    private func processTermBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Get the dictionary entity
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        // Get the dictionary format
        let format = dictionary.format

        // Process term banks
        guard let termBankURLs = job.termBanks as? [URL] else {
            throw DictionaryImportError.databaseError
        }

        if !termBankURLs.isEmpty {
            job.displayProgressMessage = "Processing terms..."
            try context.save()

            if format == 3 {
                let termIterator = StreamingBankIterator<TermBankV3Entry>(
                    bankURLs: termBankURLs,
                    dataFormat: Int(format)
                )

                for try await entry in termIterator {
                    try Task.checkCancellation()

                    // Find or create Term entity
                    let term = try findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

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
                    try linkTagsToTermEntry(termEntry, termTags: entry.termTags, definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                }
            } else if format == 1 {
                logger.debug("Processing term bank in format V1")
                let termIterator = StreamingBankIterator<TermBankV1Entry>(
                    bankURLs: termBankURLs,
                    dataFormat: Int(format)
                )

                for try await entry in termIterator {
                    try Task.checkCancellation()

                    // Find or create Term entity
                    let term = try findOrCreateTerm(expression: entry.expression, reading: entry.reading, context: context)

                    // Create TermEntry
                    let termEntry = TermEntry(context: context)
                    termEntry.id = UUID()
                    termEntry.setValue(entry.definitionTags, forKey: "definitionTags")
                    termEntry.setValue(entry.rules, forKey: "rules")
                    termEntry.score = entry.score
                    termEntry.setValue(entry.glossary, forKey: "glossary")
                    termEntry.sequence = 0
                    termEntry.setValue([], forKey: "termTags")

                    context.insert(termEntry)

                    // Link relationships
                    termEntry.term = term
                    termEntry.dictionary = dictionary

                    // Link tags (V1 only has definition tags)
                    try linkTagsToTermEntry(termEntry, termTags: [], definitionTags: entry.definitionTags, dictionary: dictionary, context: context)
                }
            }

            job.setValue(termBankURLs, forKey: "processedTermBanks")
            job.displayProgressMessage = "Processed terms."
            try context.save()
        }

        try Task.checkCancellation()
    }

    private func findOrCreateTerm(expression: String, reading: String, context: NSManagedObjectContext) throws -> Term {
        let request: NSFetchRequest<Term> = Term.fetchRequest()
        request.predicate = NSPredicate(format: "expression == %@ AND reading == %@", expression, reading)
        request.fetchLimit = 1

        if let existingTerm = try context.fetch(request).first {
            return existingTerm
        }

        // Create new Term
        let term = Term(context: context)
        term.id = UUID()
        term.expression = expression
        term.reading = reading

        context.insert(term)

        return term
    }

    private func linkTagsToTermEntry(_ termEntry: TermEntry, termTags: [String], definitionTags: [String]?, dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link term tags
        for tagName in termTags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                termEntry.addToRichTermTags(tagMeta)
            }
        }

        // Link definition tags
        if let definitionTags {
            for tagName in definitionTags {
                if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                    termEntry.addToRichDefinitionTags(tagMeta)
                }
            }
        }
    }

    private func findTagMeta(name: String, dictionary: Dictionary, context: NSManagedObjectContext) throws -> DictionaryTagMeta? {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND dictionary == %@", name, dictionary)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }

    private func copyMedia(_: DictionaryZIPFileImport) async throws {
        // Walk workingDirectory, copy non-json files preserving structure
        // Update job.mediaImported
    }

    private func cleanup(_: DictionaryZIPFileImport) async {
        // Delete working directory if complete/failed/cancelled
    }
}
