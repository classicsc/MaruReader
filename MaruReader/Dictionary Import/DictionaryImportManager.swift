//
//  DictionaryImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/20/25.
//

import Foundation
import CoreData
import Zip
import os.log

actor DictionaryImportManager {
    static let shared = DictionaryImportManager()
    
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
            try await processBanks(job, context: context)
            logger.debug("Import job \(jobID) banks processed")
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
            
            let extractedContents = try FileManager.default.contentsOfDirectory(at: jobDirectory, includingPropertiesForKeys: nil)
            
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
        
        // Find the bank files in working directory
        let contents = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: nil)
        let termBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_bank_") && $0.pathExtension == "json" }
        let kanjiBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_bank_") && $0.pathExtension == "json" }
        let termMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_meta_bank_") && $0.pathExtension == "json" }
        let kanjiMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_meta_bank_") && $0.pathExtension == "json" }
        let tagBanks = contents.filter { $0.lastPathComponent.hasPrefix("tag_bank_") && $0.pathExtension == "json" }
        
        // Dictionary must have at least one of termBanks, kanjiBanks, termMetaBanks, kanjiMetaBanks
        if termBanks.isEmpty && kanjiBanks.isEmpty && termMetaBanks.isEmpty && kanjiMetaBanks.isEmpty {
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
        dictionary.format = Int64(index.format ?? 0)
        
        try dictionary.validateForInsert()
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

                try tag.validateForInsert()
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
    
    private func processBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Example with term banks, actually tag banks should be processed first
        guard let termBankURLs = job.termBanks as? [URL] else { return }
        
        var iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: termBankURLs,
            dataFormat: 3
        )
        
        for try await entry in iterator {
            // Insert into Core Data
        }
        
        job.processedTermBanks = termBankURLs as NSArray
        try context.save()
        
        try Task.checkCancellation()
        // Then process the other banks similarly
    }
    
    private func copyMedia(_ job: DictionaryZIPFileImport) async throws {
        // Walk workingDirectory, copy non-json files preserving structure
        // Update job.mediaImported
    }
    
    private func cleanup(_ job: DictionaryZIPFileImport) async {
        // Delete working directory if complete/failed/cancelled
    }
}
