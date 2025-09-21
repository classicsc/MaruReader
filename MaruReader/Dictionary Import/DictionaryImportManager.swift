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
    static let shared = DictionaryImportManager(container: PersistenceController.shared.container)

    // Constants
    /// The supported dictionary format versions
    static let supportedFormats: Set<Int> = [1, 3]

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var container: NSPersistentContainer
    private var logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    // Initializer for both shared instance and testing with custom container
    init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Enqueue a new dictionary import from the given ZIP file URL.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        // Create DictionaryZIPFileImport in Core Data (on MainActor)
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
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

            return importJob
        }
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
        do {
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.isStarted = true
                job.timeStarted = Date()
                job.displayProgressMessage = "Starting import..."
                try context.save()
            }
            try Task.checkCancellation()
            try testErrorInjection?()
            let unzipTask = UnzipTask(jobID: jobID, container: container)
            await unzipTask.start()
            try await unzipTask.task?.value
            logger.debug("Import job \(jobID) unzipped")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let indexProcessingTask = IndexProcessingTask(jobID: jobID, container: container)
            await indexProcessingTask.start()
            try await indexProcessingTask.task?.value
            logger.debug("Import job \(jobID) index processed")
            try Task.checkCancellation()
            try await testCancellationHook?()
//            try await processIndex(job, context: context)
//            logger.debug("Import job \(jobID) index processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await processTagBanks(job, context: context)
//            logger.debug("Import job \(jobID) tag banks processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await processTermBanks(job, context: context)
//            logger.debug("Import job \(jobID) term banks processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await processTermMetaBanks(job, context: context)
//            logger.debug("Import job \(jobID) term meta banks processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await processKanjiBanks(job, context: context)
//            logger.debug("Import job \(jobID) kanji banks processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await processKanjiMetaBanks(job, context: context)
//            logger.debug("Import job \(jobID) kanji meta banks processed")
//            try Task.checkCancellation()
//            try await testCancellationHook?()
//            try await copyMedia(job, context: context)
//            logger.debug("Import job \(jobID) media copied")
//            try Task.checkCancellation()
//            try await testCancellationHook?()

            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.isComplete = true
                job.dictionary?.isComplete = true
                job.timeCompleted = Date()
                job.displayProgressMessage = "Import complete."
                try context.save()
            }
        } catch is CancellationError {
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    return
                }
                job.isCancelled = true
                job.timeCancelled = Date()
                if let dict = job.dictionary {
                    context.delete(dict)
                }
                try? context.save()
                self.cleanMediaDirectory(job: job)
            }
        } catch {
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    return
                }
                job.isFailed = true
                job.displayProgressMessage = error.localizedDescription
                job.timeFailed = Date()
                if let dict = job.dictionary {
                    context.delete(dict)
                }
                try? context.save()
                self.cleanMediaDirectory(job: job)
            }
        }

        await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                return
            }
            self.cleanup(job: job)
        }
    }

    /// Check if working directory exists for a given job
    func workingDirectoryExists(for job: NSManagedObjectID) async throws -> Bool {
        let context = container.newBackgroundContext()
        return try await context.perform {
            guard let job = try? context.existingObject(with: job) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.databaseError
            }
            guard let workingDir = job.workingDirectory else { return false }
            return FileManager.default.fileExists(atPath: workingDir.path)
        }
    }

    /// Check if media directory exists for a given job
    func mediaDirectoryExists(for jobID: NSManagedObjectID) async throws -> Bool {
        let context = container.newBackgroundContext()
        return try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.databaseError
            }
            guard let dictionary = job.dictionary, let dictionaryID = dictionary.id else { return false }

            do {
                let appSupportDir = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
                let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)
                return FileManager.default.fileExists(atPath: mediaDir.path)
            } catch {
                return false
            }
        }
    }
}
