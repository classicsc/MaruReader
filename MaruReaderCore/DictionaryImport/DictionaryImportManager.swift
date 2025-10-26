//
//  DictionaryImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/20/25.
//

import CoreData
import Foundation
import os.log
internal import Zip

public actor DictionaryImportManager {
    public static let shared = DictionaryImportManager(container: DictionaryPersistenceController.shared.container)

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
    public func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
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
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            await MainActor.run {
                let context = DictionaryPersistenceController.shared.container.viewContext
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
            try await unzipTask.start()
            logger.debug("Import job \(jobID) unzipped")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let indexProcessingTask = IndexProcessingTask(jobID: jobID, container: container)
            let dictionaryID = try await indexProcessingTask.start()
            logger.debug("Import job \(jobID) index processed")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let dataBankProcessingTask = DataBankProcessingTask(jobID: jobID, dictionaryID: dictionaryID, container: container)
            try await dataBankProcessingTask.start()
            logger.debug("Import job \(jobID) term banks processed")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let mediaCopyTask = MediaCopyProcessingTask(jobID: jobID, container: container)
            try await mediaCopyTask.start()
            logger.debug("Import job \(jobID) media copied")
            try Task.checkCancellation()
            try await testCancellationHook?()

            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.isComplete = true
                job.dictionary?.isComplete = true
                job.timeCompleted = Date()
                job.displayProgressMessage = "Import complete."
                // Enable the dictionary for each type of entry if the import completed successfully
                if job.isComplete, let dictionary = job.dictionary {
                    if dictionary.termCount > 0 {
                        dictionary.termResultsEnabled = true
                    }
                    if dictionary.kanjiCount > 0 {
                        dictionary.kanjiResultsEnabled = true
                    }
                    if dictionary.ipaCount > 0 {
                        dictionary.ipaEnabled = true
                    }
                    if dictionary.pitchesCount > 0 {
                        dictionary.pitchAccentEnabled = true
                    }
                    // If this is a frequency dictionary and we imported frequency:
                    // it should be enabled for the frequency type if there is not already a frequency dictionary enabled
                    if dictionary.termFrequencyCount > 0 {
                        let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "termFrequencyEnabled == true AND id != %@", dictionary.objectID)
                        fetchRequest.fetchLimit = 1
                        if let existing = try? context.fetch(fetchRequest), existing.isEmpty {
                            dictionary.termFrequencyEnabled = true
                        }
                    }

                    if dictionary.kanjiFrequencyCount > 0 {
                        let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "kanjiFrequencyEnabled == true AND id != %@", dictionary.objectID)
                        fetchRequest.fetchLimit = 1
                        if let existing = try? context.fetch(fetchRequest), existing.isEmpty {
                            dictionary.kanjiFrequencyEnabled = true
                        }
                    }
                }
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
                Self.cleanMediaDirectory(job: job)
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
                Self.cleanMediaDirectory(job: job)
            }
        }

        await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                return
            }
            Self.cleanup(job: job)
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

            guard let appGroupDir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
            ) else {
                return false
            }
            let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)
            return FileManager.default.fileExists(atPath: mediaDir.path)
        }
    }

    static func cleanMediaDirectory(job: DictionaryZIPFileImport) {
        let fileManager = FileManager.default
        guard let dictionary = job.dictionary, let dictionaryID = dictionary.id else {
            return
        }

        do {
            guard let appGroupDir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
            ) else {
                return
            }
            let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

            if fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.removeItem(at: mediaDir)
            }
        } catch {}
    }

    static func cleanMediaDirectoryByUUID(dictionaryUUID: UUID) {
        let fileManager = FileManager.default

        do {
            guard let appGroupDir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
            ) else {
                return
            }
            let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryUUID.uuidString)

            if fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.removeItem(at: mediaDir)
            }
        } catch {}
    }

    static func cleanup(job: DictionaryZIPFileImport) {
        // Delete working directory if complete/failed/cancelled
        let fileManager = FileManager.default
        if let workingDir = job.workingDirectory, fileManager.fileExists(atPath: workingDir.path) {
            do {
                try fileManager.removeItem(at: workingDir)
            } catch {}
        }
    }

    // MARK: - Test Helper Methods

    /// Set test cancellation hook for controlled testing
    func setTestCancellationHook(_ hook: (() async throws -> Void)?) {
        testCancellationHook = hook
    }

    /// Set test error injection for controlled testing
    func setTestErrorInjection(_ injection: (() throws -> Void)?) {
        testErrorInjection = injection
    }

    /// Delete a dictionary and all its associated data using batch deletions for performance.
    /// - Parameter dictionaryID: The NSManagedObjectID of the Dictionary to delete.
    /// - Parameter batchSize: The number of entities to delete in each batch (default: 1000).
    public func deleteDictionary(dictionaryID: NSManagedObjectID, batchSize: Int = 10000) async {
        logger.debug("Starting dictionary deletion for \\(dictionaryID) with batch size \\(batchSize)")

        // First, mark as pending deletion for immediate UI feedback
        let taskContext = container.newBackgroundContext()
        do {
            try await taskContext.perform {
                guard let dictionary = try? taskContext.existingObject(with: dictionaryID) as? Dictionary else {
                    throw DictionaryImportError.databaseError
                }
                dictionary.pendingDeletion = true
                dictionary.errorMessage = nil
                try taskContext.save()
            }
        } catch {
            logger.error("Failed to mark dictionary for deletion \\(dictionaryID): \\(error.localizedDescription)")
            return
        }

        // Perform the actual deletion in a background task
        Task {
            do {
                // Get dictionary UUID for media cleanup
                let dictionaryUUID = try await taskContext.perform {
                    guard let dictionary = try? taskContext.existingObject(with: dictionaryID) as? Dictionary else {
                        throw DictionaryImportError.databaseError
                    }
                    return dictionary.id
                }

                // Clean up media directory first
                if let uuid = dictionaryUUID {
                    Self.cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                }

                // Delete entry entities in batches
                try await deleteDictionaryEntitiesInBatches(dictionaryID: dictionaryID, batchSize: batchSize)

                // Finally delete the dictionary itself
                let finalContext = container.newBackgroundContext()
                finalContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
                finalContext.undoManager = nil

                try await finalContext.perform {
                    guard let dictionary = try? finalContext.existingObject(with: dictionaryID) as? Dictionary else {
                        throw DictionaryImportError.databaseError
                    }
                    finalContext.delete(dictionary)
                    try finalContext.save()
                }

                logger.debug("Dictionary deletion completed for \\(dictionaryID)")

            } catch {
                logger.error("Dictionary deletion failed for \\(dictionaryID): \\(error.localizedDescription)")
                // Update the dictionary with error information
                await taskContext.perform {
                    guard let dictionary = try? taskContext.existingObject(with: dictionaryID) as? Dictionary else {
                        return
                    }
                    dictionary.pendingDeletion = false
                    dictionary.errorMessage = DictionaryImportError.deletionFailed.localizedDescription
                    try? taskContext.save()
                }
            }
        }
    }

    /// Delete dictionary entry entities in batches for memory efficiency.
    private func deleteDictionaryEntitiesInBatches(dictionaryID: NSManagedObjectID, batchSize: Int) async throws {
        let entityNames = [
            "TermEntry",
            "KanjiEntry",
            "TermFrequencyEntry",
            "KanjiFrequencyEntry",
            "IPAEntry",
            "PitchAccentEntry",
            "DictionaryTagMeta",
        ]

        for entityName in entityNames {
            logger.debug("Deleting \\(entityName) entities for dictionary \\(dictionaryID)")
            try await deleteBatchesForEntity(entityName: entityName, dictionaryID: dictionaryID, batchSize: batchSize)
        }
    }

    /// Delete entities of a specific type in batches.
    private func deleteBatchesForEntity(entityName: String, dictionaryID: NSManagedObjectID, batchSize: Int) async throws {
        while true {
            let moreToDelete = try await deleteEntityBatch(entityName: entityName, dictionaryID: dictionaryID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteEntityBatch(entityName: String, dictionaryID: NSManagedObjectID, batchSize: Int) async throws -> Bool {
        // Create a fresh context for each batch to manage memory
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        return try await context.perform {
            // Create fetch request for this entity type
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "dictionaryID == %@", dictionaryID)
            fetchRequest.fetchLimit = batchSize
            fetchRequest.resultType = .managedObjectIDResultType

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeCount
            if let result = try context.execute(deleteRequest) as? NSBatchDeleteResult,
               let count = result.result as? Int,
               count > 0
            {
                return true
            } else {
                return false
            }
        }
    }
}
