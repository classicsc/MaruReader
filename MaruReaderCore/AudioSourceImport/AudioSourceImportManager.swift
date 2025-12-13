//
//  AudioSourceImportManager.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import CoreData
import Foundation
import os.log

/// Manages the import of audio source archives.
///
/// The manager handles queueing, processing, and cancellation of audio source imports.
/// Imports are processed sequentially to avoid resource contention.
///
/// Usage:
/// ```swift
/// let jobID = try await AudioSourceImportManager.shared.enqueueImport(from: zipURL)
/// await AudioSourceImportManager.shared.waitForCompletion(jobID: jobID)
/// ```
public actor AudioSourceImportManager {
    public static let shared = AudioSourceImportManager(container: DictionaryPersistenceController.shared.container)

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var container: NSPersistentContainer
    private var logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioSourceImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Enqueue a new audio source import from the given ZIP file URL.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    /// - Returns: The NSManagedObjectID of the created AudioSourceImport job.
    public func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let job = AudioSourceImport(context: context)
            let jobID = UUID()
            job.id = jobID
            job.file = zipURL
            // Use application support directory with job ID as working directory
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let workingDir = appSupport.appendingPathComponent("AudioSourceImports").appendingPathComponent(jobID.uuidString)
            try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
            job.workingDirectory = workingDir
            job.timeQueued = Date()
            try context.save()
            return job.objectID
        }
        queue.append(importJob)
        processNextIfIdle()
        return importJob
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the AudioSourceImport to cancel.
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            await MainActor.run {
                let context = DictionaryPersistenceController.shared.container.viewContext
                if let job = try? context.existingObject(with: jobID) as? AudioSourceImport {
                    job.isCancelled = true
                    job.timeCancelled = Date()
                    try? context.save()
                }
            }
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the AudioSourceImport to wait for.
    func waitForCompletion(jobID: NSManagedObjectID) async {
        while true {
            if currentJobID == jobID {
                await currentTask?.value
                return
            } else if !queue.contains(jobID) {
                return
            } else {
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
            processNextIfIdle()
        }
        currentJobID = nextJob
    }

    private func runImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting audio source import job \(jobID)")
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        var sourceID: UUID?

        do {
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                    throw AudioSourceImportError.databaseError
                }
                job.isStarted = true
                job.timeStarted = Date()
                job.displayProgressMessage = "Starting import..."
                try context.save()
            }

            try Task.checkCancellation()
            try testErrorInjection?()

            // Stage 1: Unzip
            let unzipTask = AudioSourceUnzipTask(jobID: jobID, container: container)
            try await unzipTask.start()
            logger.debug("Audio source job \(jobID) unzipped")

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Stage 2: Process index
            let indexTask = AudioSourceIndexProcessingTask(jobID: jobID, container: container)
            let (importedSourceID, indexURL, isLocal) = try await indexTask.start()
            sourceID = importedSourceID
            logger.debug("Audio source job \(jobID) index processed")

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Stage 3: Process entries
            let entryTask = AudioSourceEntryProcessingTask(
                jobID: jobID,
                sourceID: importedSourceID,
                indexURL: indexURL,
                container: container
            )
            try await entryTask.start()
            logger.debug("Audio source job \(jobID) entries processed")

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Stage 4: Copy media (only for local sources)
            if isLocal {
                let mediaTask = AudioSourceMediaCopyTask(
                    jobID: jobID,
                    sourceID: importedSourceID,
                    indexURL: indexURL,
                    container: container
                )
                try await mediaTask.start()
                logger.debug("Audio source job \(jobID) media copied")
            } else {
                // Mark media as imported for online sources (no media to copy)
                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                        throw AudioSourceImportError.databaseError
                    }
                    job.mediaImported = true
                    try context.save()
                }
            }

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Mark import as complete
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                    throw AudioSourceImportError.databaseError
                }
                job.isComplete = true
                job.timeCompleted = Date()
                job.displayProgressMessage = "Import complete."
                try context.save()
            }

        } catch is CancellationError {
            let capturedSourceID = sourceID
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                    return
                }
                job.isCancelled = true
                job.timeCancelled = Date()
                if let audioSource = job.audioSource {
                    context.delete(audioSource)
                }
                try? context.save()
                if let id = capturedSourceID {
                    AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id)
                }
            }
        } catch {
            let capturedSourceID = sourceID
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                    return
                }
                job.isFailed = true
                job.displayProgressMessage = error.localizedDescription
                job.timeFailed = Date()
                if let audioSource = job.audioSource {
                    context.delete(audioSource)
                }
                try? context.save()
                if let id = capturedSourceID {
                    AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id)
                }
            }
        }

        // Clean up working directory
        await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? AudioSourceImport else {
                return
            }
            Self.cleanup(job: job)
        }
    }

    static func cleanup(job: AudioSourceImport) {
        let fileManager = FileManager.default
        if let workingDir = job.workingDirectory, fileManager.fileExists(atPath: workingDir.path) {
            do {
                try fileManager.removeItem(at: workingDir)
            } catch {}
        }
    }

    // MARK: - Test Helper Methods

    func setTestCancellationHook(_ hook: (() async throws -> Void)?) {
        testCancellationHook = hook
    }

    func setTestErrorInjection(_ injection: (() throws -> Void)?) {
        testErrorInjection = injection
    }

    // MARK: - Deletion

    /// Delete an audio source and all its associated data.
    /// - Parameter sourceID: The NSManagedObjectID of the AudioSource to delete.
    /// - Parameter batchSize: The number of entities to delete in each batch (default: 10000).
    public func deleteAudioSource(sourceID: NSManagedObjectID, batchSize: Int = 10000) async {
        logger.debug("Starting audio source deletion for \(sourceID)")

        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        taskContext.undoManager = nil

        do {
            // Get source UUID for media cleanup
            let audioSourceUUID = try await taskContext.perform {
                guard let audioSource = try? taskContext.existingObject(with: sourceID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                return audioSource.id
            }

            // Clean up media directory
            if let uuid = audioSourceUUID {
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: uuid)
            }

            // Delete AudioHeadword entities in batches
            if let uuid = audioSourceUUID {
                try await deleteEntitiesInBatches(
                    entityName: "AudioHeadword",
                    sourceID: uuid,
                    batchSize: batchSize
                )
                try await deleteEntitiesInBatches(
                    entityName: "AudioFile",
                    sourceID: uuid,
                    batchSize: batchSize
                )
            }

            // Delete the AudioSource itself
            let finalContext = container.newBackgroundContext()
            finalContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            finalContext.undoManager = nil

            try await finalContext.perform {
                guard let audioSource = try? finalContext.existingObject(with: sourceID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                finalContext.delete(audioSource)
                try finalContext.save()
            }

            logger.debug("Audio source deletion completed for \(sourceID)")

        } catch {
            logger.error("Audio source deletion failed for \(sourceID): \(error.localizedDescription)")
        }
    }

    private func deleteEntitiesInBatches(entityName: String, sourceID: UUID, batchSize: Int) async throws {
        while true {
            let moreToDelete = try await deleteEntityBatch(entityName: entityName, sourceID: sourceID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteEntityBatch(entityName: String, sourceID: UUID, batchSize: Int) async throws -> Bool {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "sourceID == %@", sourceID as CVarArg)
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
