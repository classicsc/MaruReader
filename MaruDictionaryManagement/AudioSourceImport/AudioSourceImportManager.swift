// AudioSourceImportManager.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import MaruReaderCore
import os

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
    public static let shared = AudioSourceImportManager(
        container: DictionaryPersistenceController.shared.container,
        baseDirectory: DictionaryPersistenceController.shared.baseDirectory
    )

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var backgroundExpired = false
    private var deletionTasks: [NSManagedObjectID: Task<Void, Never>] = [:]
    private var container: NSPersistentContainer
    private var baseDirectory: URL?
    private var backgroundTaskRunner = ApplicationBackgroundTaskRunner.live
    private let logger = Logger.maru(category: "AudioSourceImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    public init(container: NSPersistentContainer, baseDirectory: URL? = nil) {
        self.container = container
        self.baseDirectory = baseDirectory ?? FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
    }

    /// Enqueue a new audio source import from the given ZIP file URL.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    /// - Returns: The NSManagedObjectID of the created AudioSource import job.
    public func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        backgroundExpired = false
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let job = AudioSource(context: context)
            let jobID = UUID()
            job.id = jobID
            job.file = zipURL
            let baseName = zipURL.deletingPathExtension().lastPathComponent
            job.name = baseName.isEmpty ? "Imported Audio Source" : baseName
            job.dateAdded = Date()
            job.enabled = true
            job.indexedByHeadword = true
            job.isLocal = true
            job.baseRemoteURL = nil
            job.urlPattern = nil
            job.urlPatternReturnsJSON = false
            job.audioFileExtensions = ""
            job.isComplete = false
            job.isFailed = false
            job.isCancelled = false
            job.isStarted = false
            job.pendingDeletion = false
            job.indexProcessed = false
            job.entriesProcessed = false
            job.mediaImported = false
            job.displayProgressMessage = FrameworkLocalization.string("Queued for import.")
            job.priority = try Self.getNextPriority(in: context)
            job.timeQueued = Date()
            try context.save()
            return job.objectID
        }
        queue.append(importJob)
        processNextIfIdle()
        return importJob
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the AudioSource import to cancel.
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            await markQueuedImportsCancelled([jobID])
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the AudioSource import to wait for.
    public func waitForCompletion(jobID: NSManagedObjectID) async {
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

    /// Mark interrupted jobs as failed and clean any partially imported data.
    public func cleanupInterruptedImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupIDs: [UUID] = await context.perform {
            let request: NSFetchRequest<AudioSource> = AudioSource.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO AND pendingDeletion == NO")
            let sources = (try? context.fetch(request)) ?? []
            guard !sources.isEmpty else { return [] }

            let now = Date()
            var ids: [UUID] = []
            for source in sources {
                if let sourceID = source.id {
                    ids.append(sourceID)
                }
                source.isFailed = true
                source.isCancelled = false
                source.isComplete = false
                source.isStarted = false
                source.timeFailed = now
                source.displayProgressMessage = FrameworkLocalization.string("Import interrupted.")
                source.indexProcessed = false
                source.entriesProcessed = false
                source.mediaImported = false
            }

            try? context.save()
            return ids
        }

        guard !cleanupIDs.isEmpty else { return }
        logger.debug("Cleaning up \(cleanupIDs.count, privacy: .public) interrupted audio source imports")

        for sourceID in cleanupIDs {
            try? await deleteEntitiesInBatches(entityName: "AudioHeadword", sourceID: sourceID, batchSize: 10000)
            try? await deleteEntitiesInBatches(entityName: "AudioFile", sourceID: sourceID, batchSize: 10000)
            AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: sourceID, baseDirectory: baseDirectory)
        }
    }

    private func processNextIfIdle() {
        guard !backgroundExpired, currentTask == nil, let nextJob = queue.first else { return }

        let runner = backgroundTaskRunner
        currentTask = Task {
            await runner.run("Audio Source Import", {
                Task {
                    await self.handleImportExpiration(for: nextJob)
                }
            }, {
                await self.runImport(for: nextJob)
            })
            finishImportTask(for: nextJob)
        }
        currentJobID = nextJob
    }

    private func finishImportTask(for jobID: NSManagedObjectID) {
        if let index = queue.firstIndex(of: jobID) {
            queue.remove(at: index)
        }
        currentTask = nil
        currentJobID = nil
        processNextIfIdle()
    }

    private func handleImportExpiration(for jobID: NSManagedObjectID) async {
        guard currentJobID == jobID else { return }
        backgroundExpired = true
        logger.error("Background time expired for audio source import \(jobID)")
        let queuedJobIDs = queue.filter { $0 != jobID }
        queue.removeAll { $0 != jobID }
        if !queuedJobIDs.isEmpty {
            await markQueuedImportsCancelled(queuedJobIDs)
        }
        currentTask?.cancel()
    }

    private func markQueuedImportsCancelled(_ jobIDs: [NSManagedObjectID]) async {
        guard !jobIDs.isEmpty else { return }

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        await context.perform {
            let cancelledAt = Date()
            for jobID in jobIDs {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    continue
                }
                job.isCancelled = true
                job.isFailed = false
                job.isComplete = false
                job.isStarted = false
                job.timeCancelled = cancelledAt
                job.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
                job.indexProcessed = false
                job.entriesProcessed = false
                job.mediaImported = false
            }
            try? context.save()
        }
    }

    private func runImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting audio source import job \(jobID)")
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        var sourceID: UUID?
        var indexURL: URL?

        defer {
            if let indexURL {
                try? FileManager.default.removeItem(at: indexURL)
            }
        }

        do {
            sourceID = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                if job.id == nil {
                    job.id = UUID()
                }
                job.isComplete = false
                job.isFailed = false
                job.isCancelled = false
                job.isStarted = true
                job.timeStarted = Date()
                job.displayProgressMessage = FrameworkLocalization.string("Starting import...")
                try context.save()
                guard let id = job.id else {
                    throw AudioSourceImportError.databaseError
                }
                return id
            }

            try Task.checkCancellation()
            try testErrorInjection?()

            // Stage 1: Process index
            let indexTask = AudioSourceIndexProcessingTask(jobID: jobID, container: container)
            let indexResult = try await indexTask.start()
            indexURL = indexResult.indexURL
            let importedSourceID = indexResult.sourceID
            let isLocal = indexResult.isLocal
            logger.debug("Audio source job \(jobID) index processed")

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Stage 2: Process entries
            let entryTask = AudioSourceEntryProcessingTask(
                jobID: jobID,
                sourceID: importedSourceID,
                indexURL: indexResult.indexURL,
                container: container
            )
            try await entryTask.start()
            logger.debug("Audio source job \(jobID) entries processed")

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Stage 3: Copy media (only for local sources)
            if isLocal {
                let mediaTask = AudioSourceMediaCopyTask(
                    jobID: jobID,
                    sourceID: importedSourceID,
                    indexURL: indexResult.indexURL,
                    archiveURL: indexResult.archiveURL,
                    indexEntryPath: indexResult.indexEntryPath,
                    container: container,
                    baseDirectory: baseDirectory
                )
                try await mediaTask.start()
                logger.debug("Audio source job \(jobID) media copied")
            } else {
                // Mark media as imported for online sources (no media to copy)
                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
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
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                job.isComplete = true
                job.isFailed = false
                job.isCancelled = false
                job.timeCompleted = Date()
                job.displayProgressMessage = FrameworkLocalization.string("Import complete.")
                try context.save()
            }

        } catch is CancellationError {
            let capturedSourceID = sourceID
            let capturedBaseDirectory = baseDirectory
            if let id = capturedSourceID {
                try? await deleteEntitiesInBatches(entityName: "AudioHeadword", sourceID: id, batchSize: 10000)
                try? await deleteEntitiesInBatches(entityName: "AudioFile", sourceID: id, batchSize: 10000)
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id, baseDirectory: capturedBaseDirectory)
            }
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    return
                }
                job.isCancelled = true
                job.isFailed = false
                job.isComplete = false
                job.timeCancelled = Date()
                job.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
                try? context.save()
            }
        } catch {
            let capturedSourceID = sourceID
            let capturedBaseDirectory = baseDirectory
            if let id = capturedSourceID {
                try? await deleteEntitiesInBatches(entityName: "AudioHeadword", sourceID: id, batchSize: 10000)
                try? await deleteEntitiesInBatches(entityName: "AudioFile", sourceID: id, batchSize: 10000)
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id, baseDirectory: capturedBaseDirectory)
            }
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    return
                }
                job.isFailed = true
                job.isCancelled = false
                job.isComplete = false
                job.displayProgressMessage = error.localizedDescription
                job.timeFailed = Date()
                try? context.save()
            }
        }

        await context.perform {
            _ = try? context.existingObject(with: jobID) as? AudioSource
        }
    }

    private static func getNextPriority(in context: NSManagedObjectContext) throws -> Int64 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioSource")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]
        fetchRequest.fetchLimit = 1

        if let results = try context.fetch(fetchRequest) as? [NSManagedObject],
           let maxSource = results.first,
           let maxPriority = maxSource.value(forKey: "priority") as? Int64
        {
            return maxPriority + 1
        }
        return 0
    }

    // MARK: - Test Helper Methods

    func setTestCancellationHook(_ hook: (() async throws -> Void)?) {
        testCancellationHook = hook
    }

    func setTestErrorInjection(_ injection: (() throws -> Void)?) {
        testErrorInjection = injection
    }

    func setBackgroundTaskRunner(_ runner: ApplicationBackgroundTaskRunner) {
        backgroundTaskRunner = runner
    }

    /// Clean up audio sources marked for deletion but not yet removed.
    public func cleanupPendingDeletions(batchSize: Int = 10000) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<AudioSource> = AudioSource.fetchRequest()
            request.predicate = NSPredicate(format: "pendingDeletion == YES")
            let sources = (try? context.fetch(request)) ?? []
            return sources.map(\.objectID)
        }

        guard !pendingIDs.isEmpty else { return }
        logger.debug("Cleaning up \(pendingIDs.count, privacy: .public) pending audio source deletions")

        for sourceID in pendingIDs {
            await deleteAudioSource(sourceID: sourceID, batchSize: batchSize)
        }
    }

    // MARK: - Deletion

    /// Delete an audio source and all its associated data.
    /// - Parameter sourceID: The NSManagedObjectID of the AudioSource to delete.
    /// - Parameter batchSize: The number of entities to delete in each batch (default: 10000).
    public func deleteAudioSource(sourceID: NSManagedObjectID, batchSize: Int = 10000) async {
        logger.debug("Starting audio source deletion for \(sourceID)")

        guard deletionTasks[sourceID] == nil else { return }

        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        taskContext.undoManager = nil

        do {
            try await taskContext.perform {
                guard let audioSource = try? taskContext.existingObject(with: sourceID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                audioSource.pendingDeletion = true
                audioSource.displayProgressMessage = nil
                try taskContext.save()
            }
        } catch {
            logger.error("Failed to mark audio source for deletion \(sourceID): \(error.localizedDescription)")
            return
        }

        let runner = backgroundTaskRunner
        let task = Task {
            await runner.run("Audio Source Delete", {
                Task {
                    await self.handleDeletionExpiration(for: sourceID)
                }
            }, {
                await self.runAudioSourceDeletion(
                    sourceID: sourceID,
                    batchSize: batchSize,
                    taskContext: taskContext
                )
            })
            finishDeletionTask(for: sourceID)
        }
        deletionTasks[sourceID] = task
    }

    private func handleDeletionExpiration(for sourceID: NSManagedObjectID) {
        guard let task = deletionTasks[sourceID] else { return }
        logger.error("Background time expired for audio source deletion \(sourceID)")
        task.cancel()
    }

    private func finishDeletionTask(for sourceID: NSManagedObjectID) {
        deletionTasks[sourceID] = nil
    }

    private func runAudioSourceDeletion(
        sourceID: NSManagedObjectID,
        batchSize: Int,
        taskContext: NSManagedObjectContext
    ) async {
        do {
            try Task.checkCancellation()

            let audioSourceUUID = try await taskContext.perform {
                guard let audioSource = try? taskContext.existingObject(with: sourceID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                return audioSource.id
            }

            try Task.checkCancellation()

            if let uuid = audioSourceUUID {
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: uuid, baseDirectory: baseDirectory)
                try Task.checkCancellation()
                try await deleteEntitiesInBatches(
                    entityName: "AudioHeadword",
                    sourceID: uuid,
                    batchSize: batchSize
                )
                try Task.checkCancellation()
                try await deleteEntitiesInBatches(
                    entityName: "AudioFile",
                    sourceID: uuid,
                    batchSize: batchSize
                )
            }

            try Task.checkCancellation()

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
        } catch is CancellationError {
            logger.error("Audio source deletion cancelled for \(sourceID); cleanup will resume later")
        } catch {
            logger.error("Audio source deletion failed for \(sourceID): \(error.localizedDescription)")
            await taskContext.perform {
                guard let audioSource = try? taskContext.existingObject(with: sourceID) as? AudioSource else {
                    return
                }
                audioSource.pendingDeletion = false
                audioSource.displayProgressMessage = AudioSourceImportError.deletionFailed.localizedDescription
                try? taskContext.save()
            }
        }
    }

    private func deleteEntitiesInBatches(entityName: String, sourceID: UUID, batchSize: Int) async throws {
        while true {
            try Task.checkCancellation()
            let moreToDelete = try await deleteEntityBatch(entityName: entityName, sourceID: sourceID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteEntityBatch(entityName: String, sourceID: UUID, batchSize: Int) async throws -> Bool {
        try Task.checkCancellation()
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
