//
//  DictionaryImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/20/25.
//

import Foundation
import CoreData

actor DictionaryImportManager {
    static let shared = DictionaryImportManager()
    
    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    
    func enqueueImport(from zipURL: URL) async throws {
        // Create DictionaryZIPFileImport in Core Data (on MainActor)
        let context = PersistenceController.shared.container.viewContext
        let importJob = try await MainActor.run {
            let job = DictionaryZIPFileImport(context: context)
            job.id = UUID()
            job.file = zipURL
            // Use application support directory with job ID as working directory for resume capability
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let workingDir = appSupport.appendingPathComponent("DictionaryImports").appendingPathComponent(job.id!.uuidString)
            try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
            job.workingDirectory = workingDir
            job.timeQueued = Date()
            try context.save()
            return job.objectID
        }
        
        queue.append(importJob)
        processNextIfIdle()
    }
    
    private func processNextIfIdle() {
        guard currentTask == nil, let nextJob = queue.first else { return }
        
        currentTask = Task {
            await runImport(for: nextJob)
            queue.removeFirst()
            currentTask = nil
            processNextIfIdle() // Move on to next
        }
    }
    
    private func runImport(for jobID: NSManagedObjectID) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else { return }
        do {
            job.isStarted = true
            job.timeStarted = Date()
            job.displayProgressMessage = "Starting import..."
            try context.save()
            guard let jobURL = job.file else {
                throw DictionaryImportError.missingFile
            }
            guard let jobDirectory = job.workingDirectory else {
                throw DictionaryImportError.noWorkingDirectory
            }
            try await unzip(jobURL, into: jobDirectory)
            try await processIndex(job, context: context)
            try await processBanks(job, context: context)
            try await copyMedia(job)
            
            job.isComplete = true
            job.timeCompleted = Date()
            try context.save()
        } catch is CancellationError {
            job.isCancelled = true
            job.timeCancelled = Date()
            try? context.save()
        } catch {
            job.isFailed = true
            job.displayProgressMessage = error.localizedDescription
            job.timeFailed = Date()
            try? context.save()
        }
        
        await cleanup(job)
    }
}

extension DictionaryImportManager {
    private func unzip(_ url: URL, into directory: URL) async throws {
        // Use Zip.unzipFile(...)
        // Store to job.workingDirectory
    }
    
    private func processIndex(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Load index.json
        // Create Dictionary entity
        // Populate job.termBanks, job.kanjiBanks, etc.
        // Index can contain tag metadata that needs to be processed
    }
    
    private func processBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Example with term banks, actually tag banks should be processed first
        guard let termBankURLs = job.termBanks as? [URL] else { return }
        
        // Consider batching for memory efficiency
        var iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: termBankURLs,
            dataFormat: 3
        )
        
        for try await entry in iterator {
            // Insert into Core Data
        }
        
        job.processedTermBanks = termBankURLs as NSArray
        try context.save()
        
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
