// DictionaryImportManager.swift
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

public actor DictionaryImportManager {
    private struct CompressionRetryCleanupError: LocalizedError {
        let underlyingError: (any Error)?
        let remainingEntityCounts: [String: Int]

        var errorDescription: String? {
            let remainingDescription = remainingEntityCounts
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")

            if let underlyingError {
                return FrameworkLocalization.string(
                    "Failed to clean up partially imported dictionary data before retrying: \(underlyingError.localizedDescription). Remaining rows: \(remainingDescription)"
                )
            }

            return FrameworkLocalization.string(
                "Failed to clean up partially imported dictionary data before retrying. Remaining rows: \(remainingDescription)"
            )
        }
    }

    public static let shared = DictionaryImportManager(
        container: DictionaryPersistenceController.shared.container,
        baseDirectory: DictionaryPersistenceController.shared.baseDirectory
    )

    /// Constants
    /// The supported dictionary format versions
    static let supportedFormats: Set<Int> = [1, 3]
    private static let dictionaryEntryEntityNames = [
        "TermEntry",
        "KanjiEntry",
        "TermFrequencyEntry",
        "KanjiFrequencyEntry",
        "IPAEntry",
        "PitchAccentEntry",
        "DictionaryTagMeta",
    ]

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var backgroundExpired = false
    private var deletionTasks: [NSManagedObjectID: Task<Void, Never>] = [:]
    private var container: NSPersistentContainer
    private var baseDirectory: URL?
    private let glossaryCompressionVersion: GlossaryCompressionCodecVersion
    private let glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile
    private var backgroundTaskRunner = ApplicationBackgroundTaskRunner.live
    private let logger = Logger.maru(category: "DictionaryImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?
    var testDeleteDictionaryEntitiesHook: (@Sendable (UUID, Int) async throws -> Void)?

    /// Initializer for both shared instance and testing with custom container
    public init(
        container: NSPersistentContainer,
        baseDirectory: URL? = nil,
        glossaryCompressionVersion: GlossaryCompressionCodecVersion = GlossaryCompressionCodec.defaultImportVersion,
        glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile = .runtime
    ) {
        self.container = container
        self.baseDirectory = baseDirectory ?? FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
        self.glossaryCompressionVersion = glossaryCompressionVersion
        self.glossaryCompressionTrainingProfile = glossaryCompressionTrainingProfile
    }

    /// Enqueue a new dictionary import from the given ZIP file URL.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    public func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        try await enqueueImport(from: zipURL, updateTaskID: nil)
    }

    /// Enqueue a dictionary import tied to an update task.
    /// - Parameters:
    ///   - zipURL: The file URL of the ZIP archive to import.
    ///   - updateTaskID: The update task UUID, if this import is part of an update.
    func enqueueImport(from zipURL: URL, updateTaskID: UUID?) async throws -> NSManagedObjectID {
        backgroundExpired = false
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let dictionary = Dictionary(context: context)
            let jobID = UUID()
            dictionary.id = jobID
            dictionary.file = zipURL
            let baseTitle = zipURL.deletingPathExtension().lastPathComponent
            dictionary.title = baseTitle.isEmpty ? "Imported Dictionary" : baseTitle
            dictionary.timeQueued = Date()
            dictionary.displayProgressMessage = FrameworkLocalization.string("Queued for import.")
            dictionary.isComplete = false
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.isStarted = false
            dictionary.errorMessage = nil
            dictionary.updateReady = false
            dictionary.updateTaskID = updateTaskID
            try context.save()
            return dictionary.objectID
        }
        queue.append(importJob)
        processNextIfIdle()
        return importJob
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the Dictionary import to cancel.
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            await markQueuedImportsCancelled([jobID])
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the Dictionary import to wait for.
    public func waitForCompletion(jobID: NSManagedObjectID) async {
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

    /// Mark interrupted jobs as failed and clean any partially imported data.
    public func cleanupInterruptedImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (cleanupIDs, retryJobIDs): ([UUID], [NSManagedObjectID]) = await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO AND pendingDeletion == NO")
            let dictionaries = (try? context.fetch(request)) ?? []
            guard !dictionaries.isEmpty else { return ([], []) }

            let now = Date()
            var ids: [UUID] = []
            var retryJobIDs: [NSManagedObjectID] = []
            for dictionary in dictionaries {
                if let dictionaryID = dictionary.id {
                    ids.append(dictionaryID)
                }
                if dictionary.updateTaskID != nil {
                    dictionary.isFailed = false
                    dictionary.isCancelled = false
                    dictionary.isComplete = false
                    dictionary.isStarted = false
                    dictionary.displayProgressMessage = FrameworkLocalization.string("Retrying update import.")
                    dictionary.errorMessage = nil
                    dictionary.timeQueued = now
                    dictionary.timeStarted = nil
                    dictionary.timeFailed = nil
                    dictionary.timeCancelled = nil
                    retryJobIDs.append(dictionary.objectID)
                } else {
                    dictionary.isFailed = true
                    dictionary.isCancelled = false
                    dictionary.isComplete = false
                    dictionary.displayProgressMessage = FrameworkLocalization.string("Import interrupted.")
                    dictionary.errorMessage = FrameworkLocalization.string("Import interrupted.")
                    dictionary.timeFailed = now
                }
                dictionary.termCount = 0
                dictionary.kanjiCount = 0
                dictionary.termFrequencyCount = 0
                dictionary.kanjiFrequencyCount = 0
                dictionary.pitchesCount = 0
                dictionary.ipaCount = 0
                dictionary.tagCount = 0
                dictionary.indexProcessed = false
                dictionary.banksProcessed = false
                dictionary.mediaImported = false
            }

            try? context.save()
            return (ids, retryJobIDs)
        }

        guard !cleanupIDs.isEmpty else { return }
        logger.debug("Cleaning up \(cleanupIDs.count, privacy: .public) interrupted dictionary imports")

        for dictionaryID in cleanupIDs {
            try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: dictionaryID, batchSize: 10000)
            cleanMediaDirectoryByUUID(dictionaryUUID: dictionaryID)
            cleanCompressionDictionaryByUUID(dictionaryUUID: dictionaryID)
            cleanScratchDirectoryByUUID(dictionaryUUID: dictionaryID)
        }

        guard !retryJobIDs.isEmpty else { return }
        for jobID in retryJobIDs where currentJobID != jobID && !queue.contains(jobID) {
            queue.append(jobID)
        }
        processNextIfIdle()
    }

    private func processNextIfIdle() {
        guard !backgroundExpired, currentTask == nil, let nextJob = queue.first else { return }

        let runner = backgroundTaskRunner
        currentTask = Task {
            await runner.run("Dictionary Import", {
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
        logger.error("Background time expired for dictionary import \(jobID)")
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
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    continue
                }
                dictionary.isCancelled = true
                dictionary.isFailed = false
                dictionary.isComplete = false
                dictionary.isStarted = false
                dictionary.timeCancelled = cancelledAt
                dictionary.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
                dictionary.errorMessage = nil
                dictionary.termCount = 0
                dictionary.kanjiCount = 0
                dictionary.termFrequencyCount = 0
                dictionary.kanjiFrequencyCount = 0
                dictionary.pitchesCount = 0
                dictionary.ipaCount = 0
                dictionary.tagCount = 0
                dictionary.indexProcessed = false
                dictionary.banksProcessed = false
                dictionary.mediaImported = false
            }
            try? context.save()
        }
    }

    private func runImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting import job \(jobID)")
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        var dictionaryUUID: UUID?
        var scratchSpace: ImportScratchSpace?
        defer {
            scratchSpace?.cleanupBestEffort()
        }
        do {
            dictionaryUUID = try await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    throw DictionaryImportError.databaseError
                }
                if dictionary.id == nil {
                    dictionary.id = UUID()
                }
                dictionary.isStarted = true
                dictionary.isComplete = false
                dictionary.isFailed = false
                dictionary.isCancelled = false
                dictionary.timeStarted = Date()
                dictionary.displayProgressMessage = FrameworkLocalization.string("Starting import...")
                dictionary.errorMessage = nil
                try context.save()
                return dictionary.id
            }
            if let dictionaryUUID {
                scratchSpace = ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryUUID)
            }
            try Task.checkCancellation()
            try testErrorInjection?()
            let indexProcessingTask = IndexProcessingTask(jobID: jobID, container: container)
            let indexResult = try await indexProcessingTask.start()
            logger.debug("Import job \(jobID) index processed")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let glossaryCompressionDictionaryTask = GlossaryCompressionDictionaryImportTask(
                jobID: jobID,
                dictionaryID: indexResult.dictionaryID,
                archiveURL: indexResult.archiveURL,
                bankPaths: indexResult.bankPaths,
                glossaryCompressionVersion: glossaryCompressionVersion,
                glossaryCompressionTrainingProfile: glossaryCompressionTrainingProfile,
                baseDirectory: baseDirectory,
                container: container
            )
            let preparedGlossaryCompressionVersion = try await glossaryCompressionDictionaryTask.start()
            logger.debug("Import job \(jobID) glossary compression prepared using \(preparedGlossaryCompressionVersion.rawValue, privacy: .public)")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let importedGlossaryCompressionVersion = try await processDataBanksWithGlossaryCompressionFallback(
                jobID: jobID,
                dictionaryID: indexResult.dictionaryID,
                archiveURL: indexResult.archiveURL,
                bankPaths: indexResult.bankPaths,
                preparedGlossaryCompressionVersion: preparedGlossaryCompressionVersion
            )
            logger.debug("Import job \(jobID) term banks processed using \(importedGlossaryCompressionVersion.rawValue, privacy: .public)")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let mediaCopyTask = MediaCopyProcessingTask(
                jobID: jobID,
                archiveURL: indexResult.archiveURL,
                container: container,
                baseDirectory: baseDirectory
            )
            try await mediaCopyTask.start()
            logger.debug("Import job \(jobID) media copied")
            try Task.checkCancellation()
            try await testCancellationHook?()

            try await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    throw DictionaryImportError.databaseError
                }
                context.refresh(dictionary, mergeChanges: true)
                dictionary.isComplete = true
                dictionary.timeCompleted = Date()
                dictionary.displayProgressMessage = FrameworkLocalization.string("Import complete.")
                dictionary.isFailed = false
                dictionary.isCancelled = false
                dictionary.errorMessage = nil

                // Enable the dictionary for each type of entry if the import completed successfully
                if dictionary.isComplete {
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
                        if let dictionaryID = dictionary.id {
                            fetchRequest.predicate = NSPredicate(format: "termFrequencyEnabled == true AND id != %@", dictionaryID as CVarArg)
                        }
                        fetchRequest.fetchLimit = 1
                        if let existing = try? context.fetch(fetchRequest), existing.isEmpty {
                            dictionary.termFrequencyEnabled = true
                        }
                    }

                    if dictionary.kanjiFrequencyCount > 0 {
                        let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
                        if let dictionaryID = dictionary.id {
                            fetchRequest.predicate = NSPredicate(format: "kanjiFrequencyEnabled == true AND id != %@", dictionaryID as CVarArg)
                        }
                        fetchRequest.fetchLimit = 1
                        if let existing = try? context.fetch(fetchRequest), existing.isEmpty {
                            dictionary.kanjiFrequencyEnabled = true
                        }
                    }
                }
                try context.save()
            }
        } catch is CancellationError {
            if let uuid = dictionaryUUID {
                try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: uuid, batchSize: 10000)
            }
            let uuidToClean: UUID? = await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    return nil
                }
                dictionary.isCancelled = true
                dictionary.isFailed = false
                dictionary.isComplete = false
                dictionary.timeCancelled = Date()
                dictionary.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
                dictionary.errorMessage = nil
                dictionary.termCount = 0
                dictionary.kanjiCount = 0
                dictionary.termFrequencyCount = 0
                dictionary.kanjiFrequencyCount = 0
                dictionary.pitchesCount = 0
                dictionary.ipaCount = 0
                dictionary.tagCount = 0

                try? context.save()

                return dictionary.id
            }
            if let uuid = uuidToClean {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
            }
        } catch {
            if let uuid = dictionaryUUID {
                try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: uuid, batchSize: 10000)
            }
            let uuidToClean: UUID? = await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    return nil
                }
                dictionary.isFailed = true
                dictionary.isCancelled = false
                dictionary.isComplete = false
                dictionary.displayProgressMessage = FrameworkLocalization.string("Import failed.")
                dictionary.errorMessage = error.localizedDescription
                dictionary.timeFailed = Date()
                dictionary.termCount = 0
                dictionary.kanjiCount = 0
                dictionary.termFrequencyCount = 0
                dictionary.kanjiFrequencyCount = 0
                dictionary.pitchesCount = 0
                dictionary.ipaCount = 0
                dictionary.tagCount = 0

                try? context.save()

                return dictionary.id
            }
            if let uuid = uuidToClean {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
            }
        }

        await context.perform {
            _ = try? context.existingObject(with: jobID) as? Dictionary
        }
    }

    private func processDataBanksWithGlossaryCompressionFallback(
        jobID: NSManagedObjectID,
        dictionaryID: UUID,
        archiveURL: URL,
        bankPaths: DictionaryBankPaths,
        preparedGlossaryCompressionVersion: GlossaryCompressionCodecVersion
    ) async throws -> GlossaryCompressionCodecVersion {
        let versionsToTry = Self.glossaryCompressionVersionsToTry(
            requested: glossaryCompressionVersion,
            prepared: preparedGlossaryCompressionVersion
        )

        for (index, version) in versionsToTry.enumerated() {
            let dataBankProcessingTask = DataBankProcessingTask(
                jobID: jobID,
                dictionaryID: dictionaryID,
                archiveURL: archiveURL,
                bankPaths: bankPaths,
                glossaryCompressionVersion: version,
                glossaryCompressionBaseDirectory: baseDirectory,
                container: container
            )

            do {
                try await dataBankProcessingTask.start()
                return version
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard index + 1 < versionsToTry.count else {
                    throw error
                }

                let fallbackVersion = versionsToTry[index + 1]
                logger.warning(
                    "Import job \(jobID) glossary compression with \(version.rawValue, privacy: .public) failed; retrying with \(fallbackVersion.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )

                try await cleanupPartialImportForCompressionRetry(
                    dictionaryUUID: dictionaryID,
                    batchSize: 10000
                )
                if version == .zstdRuntimeV1, fallbackVersion != .zstdRuntimeV1 {
                    cleanCompressionDictionaryByUUID(dictionaryUUID: dictionaryID)
                }
                try await resetImportStateForCompressionRetry(jobID: jobID)
            }
        }

        return preparedGlossaryCompressionVersion
    }

    static func glossaryCompressionVersionsToTry(
        requested: GlossaryCompressionCodecVersion,
        prepared: GlossaryCompressionCodecVersion
    ) -> [GlossaryCompressionCodecVersion] {
        var versions = [prepared]

        func appendIfNeeded(_ version: GlossaryCompressionCodecVersion) {
            guard !versions.contains(version) else {
                return
            }
            versions.append(version)
        }

        switch requested {
        case .zstdRuntimeV1:
            appendIfNeeded(.zstdV1)
            appendIfNeeded(.lzfseV1)
            appendIfNeeded(.uncompressedV1)
        case .zstdV1:
            appendIfNeeded(.lzfseV1)
            appendIfNeeded(.uncompressedV1)
        case .lzfseV1:
            appendIfNeeded(.uncompressedV1)
        case .uncompressedV1:
            break
        @unknown default:
            break
        }

        return versions
    }

    func cleanupPartialImportForCompressionRetry(
        dictionaryUUID: UUID,
        batchSize: Int
    ) async throws {
        var deletionError: (any Error)?

        do {
            if let testDeleteDictionaryEntitiesHook {
                try await testDeleteDictionaryEntitiesHook(dictionaryUUID, batchSize)
            } else {
                try await deleteDictionaryEntitiesInBatches(
                    dictionaryUUID: dictionaryUUID,
                    batchSize: batchSize
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            deletionError = error
        }

        let remainingEntityCounts = try await remainingDictionaryEntityCounts(dictionaryUUID: dictionaryUUID)
        guard remainingEntityCounts.isEmpty else {
            throw CompressionRetryCleanupError(
                underlyingError: deletionError,
                remainingEntityCounts: remainingEntityCounts
            )
        }

        if let deletionError {
            logger.warning(
                "Retry cleanup for dictionary \(dictionaryUUID.uuidString, privacy: .public) reported an error but no rows remained: \(deletionError.localizedDescription, privacy: .public)"
            )
        }
    }

    private func remainingDictionaryEntityCounts(dictionaryUUID: UUID) async throws -> [String: Int] {
        var remainingCounts: [String: Int] = [:]

        for entityName in Self.dictionaryEntryEntityNames {
            try Task.checkCancellation()

            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            let count = try await context.perform {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.predicate = NSPredicate(format: "dictionaryID == %@", dictionaryUUID as CVarArg)
                return try context.count(for: fetchRequest)
            }

            if count > 0 {
                remainingCounts[entityName] = count
            }
        }

        return remainingCounts
    }

    private func resetImportStateForCompressionRetry(jobID: NSManagedObjectID) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }

            dictionary.banksProcessed = false
            dictionary.termCount = 0
            dictionary.kanjiCount = 0
            dictionary.termFrequencyCount = 0
            dictionary.kanjiFrequencyCount = 0
            dictionary.pitchesCount = 0
            dictionary.ipaCount = 0
            dictionary.tagCount = 0
            dictionary.displayProgressMessage = FrameworkLocalization.string("Processing dictionary data...")
            try context.save()
        }
    }

    /// Check if media directory exists for a given dictionary import
    func mediaDirectoryExists(for jobID: NSManagedObjectID) async throws -> Bool {
        let context = container.newBackgroundContext()
        let baseDir = baseDirectory
        return try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            guard let dictionaryID = dictionary.id else { return false }
            guard let baseDir else { return false }
            let mediaDir = baseDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)
            return FileManager.default.fileExists(atPath: mediaDir.path)
        }
    }

    private func cleanMediaDirectoryByUUID(dictionaryUUID: UUID) {
        let fileManager = FileManager.default

        do {
            guard let baseDir = baseDirectory else { return }
            let mediaDir = baseDir.appendingPathComponent("Media").appendingPathComponent(dictionaryUUID.uuidString)

            if fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.removeItem(at: mediaDir)
            }
        } catch {}
    }

    private func cleanCompressionDictionaryByUUID(dictionaryUUID: UUID) {
        let fileManager = FileManager.default
        GlossaryCompressionCodec.evictRuntimeZSTDDictionary(dictionaryID: dictionaryUUID)

        do {
            guard let baseDir = baseDirectory else { return }
            let dictionaryURL = GlossaryCompressionCodec.zstdDictionaryURL(
                dictionaryID: dictionaryUUID,
                in: baseDir
            )

            if fileManager.fileExists(atPath: dictionaryURL.path) {
                try fileManager.removeItem(at: dictionaryURL)
            }
        } catch {}
    }

    private func cleanScratchDirectoryByUUID(dictionaryUUID: UUID) {
        ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryUUID).cleanupBestEffort()
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

    func setTestDeleteDictionaryEntitiesHook(_ hook: (@Sendable (UUID, Int) async throws -> Void)?) {
        testDeleteDictionaryEntitiesHook = hook
    }

    func setBackgroundTaskRunner(_ runner: ApplicationBackgroundTaskRunner) {
        backgroundTaskRunner = runner
    }

    /// Clean up dictionaries marked for deletion but not yet removed.
    public func cleanupPendingDeletions(batchSize: Int = 10000) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "pendingDeletion == YES")
            let dictionaries = (try? context.fetch(request)) ?? []
            return dictionaries.map(\.objectID)
        }

        guard !pendingIDs.isEmpty else { return }
        logger.debug("Cleaning up \(pendingIDs.count, privacy: .public) pending dictionary deletions")

        for dictionaryID in pendingIDs {
            await deleteDictionary(dictionaryID: dictionaryID, batchSize: batchSize)
        }
    }

    /// Delete a dictionary and all its associated data using batch deletions for performance.
    /// - Parameter dictionaryID: The NSManagedObjectID of the Dictionary to delete.
    /// - Parameter batchSize: The number of entities to delete in each batch (default: 1000).
    public func deleteDictionary(dictionaryID: NSManagedObjectID, batchSize: Int = 10000) async {
        logger.debug("Starting dictionary deletion for \(dictionaryID) with batch size \(batchSize)")

        guard deletionTasks[dictionaryID] == nil else { return }

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
            logger.error("Failed to mark dictionary for deletion \(dictionaryID): \(error.localizedDescription)")
            return
        }

        let runner = backgroundTaskRunner
        let task = Task {
            await runner.run("Dictionary Delete", {
                Task {
                    await self.handleDeletionExpiration(for: dictionaryID)
                }
            }, {
                await self.runDictionaryDeletion(
                    dictionaryID: dictionaryID,
                    batchSize: batchSize,
                    taskContext: taskContext
                )
            })
            finishDeletionTask(for: dictionaryID)
        }
        deletionTasks[dictionaryID] = task
    }

    private func handleDeletionExpiration(for dictionaryID: NSManagedObjectID) {
        guard let task = deletionTasks[dictionaryID] else { return }
        logger.error("Background time expired for dictionary deletion \(dictionaryID)")
        task.cancel()
    }

    private func finishDeletionTask(for dictionaryID: NSManagedObjectID) {
        deletionTasks[dictionaryID] = nil
    }

    private func runDictionaryDeletion(
        dictionaryID: NSManagedObjectID,
        batchSize: Int,
        taskContext: NSManagedObjectContext
    ) async {
        do {
            try Task.checkCancellation()

            let dictionaryUUID = try await taskContext.perform {
                guard let dictionary = try? taskContext.existingObject(with: dictionaryID) as? Dictionary else {
                    throw DictionaryImportError.databaseError
                }
                return dictionary.id
            }

            try Task.checkCancellation()

            if let uuid = dictionaryUUID {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
                cleanScratchDirectoryByUUID(dictionaryUUID: uuid)
            }

            try Task.checkCancellation()

            if let uuid = dictionaryUUID {
                try await deleteDictionaryEntitiesInBatches(dictionaryUUID: uuid, batchSize: batchSize)
            } else {
                throw DictionaryImportError.databaseError
            }

            try Task.checkCancellation()

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

            logger.debug("Dictionary deletion completed for \(dictionaryID)")
        } catch is CancellationError {
            logger.error("Dictionary deletion cancelled for \(dictionaryID); cleanup will resume later")
        } catch {
            logger.error("Dictionary deletion failed for \(dictionaryID): \(error.localizedDescription)")
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

    /// Delete dictionary entry entities in batches for memory efficiency.
    private func deleteDictionaryEntitiesInBatches(dictionaryUUID: UUID, batchSize: Int) async throws {
        for entityName in Self.dictionaryEntryEntityNames {
            try Task.checkCancellation()
            logger.debug("Deleting \(entityName) entities for dictionary \(dictionaryUUID)")
            try await deleteBatchesForEntity(entityName: entityName, dictionaryUUID: dictionaryUUID, batchSize: batchSize)
        }
    }

    /// Delete entities of a specific type in batches.
    private func deleteBatchesForEntity(entityName: String, dictionaryUUID: UUID, batchSize: Int) async throws {
        while true {
            try Task.checkCancellation()
            let moreToDelete = try await deleteEntityBatch(entityName: entityName, dictionaryUUID: dictionaryUUID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteEntityBatch(entityName: String, dictionaryUUID: UUID, batchSize: Int) async throws -> Bool {
        try Task.checkCancellation()
        // Create a fresh context for each batch to manage memory
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        return try await context.perform {
            // Create fetch request for this entity type
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "dictionaryID == %@", dictionaryUUID as CVarArg)
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
