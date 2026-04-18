// ImportManager.swift
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

/// Unified import manager for dictionary and audio source archives.
///
/// Handles queueing, processing, cancellation, and deletion for both Yomitan
/// dictionaries and AJT audio sources. Imports are processed sequentially.
///
/// Usage:
/// ```swift
/// // Auto-detect archive type:
/// let jobID = try await ImportManager.shared.enqueueImport(from: zipURL)
///
/// // Or import a known type:
/// let jobID = try await ImportManager.shared.enqueueDictionaryImport(from: zipURL)
/// let jobID = try await ImportManager.shared.enqueueAudioSourceImport(from: zipURL)
/// ```
public actor ImportManager {
    // MARK: - Types

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

    /// Type-safe queue item so `runImport` dispatches unambiguously.
    enum QueuedImport: Equatable {
        case dictionary(NSManagedObjectID)
        case audioSource(NSManagedObjectID)
        case tokenizerDictionary(NSManagedObjectID)

        var jobID: NSManagedObjectID {
            switch self {
            case let .dictionary(id), let .audioSource(id), let .tokenizerDictionary(id): id
            }
        }
    }

    // MARK: - Shared State

    public static let shared = ImportManager(
        container: DictionaryPersistenceController.shared.container,
        baseDirectory: DictionaryPersistenceController.shared.baseDirectory
    )

    /// Supported Yomitan dictionary format versions.
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

    private var queue: [QueuedImport] = []
    private var currentTask: Task<Void, Never>?
    private var currentJob: QueuedImport?
    private var backgroundExpired = false
    private var deletionTasks: [NSManagedObjectID: Task<Void, Never>] = [:]
    private var container: NSPersistentContainer
    private var baseDirectory: URL?
    private let glossaryCompressionVersion: GlossaryCompressionCodecVersion
    private let glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile
    private var backgroundTaskRunner = ApplicationBackgroundTaskRunner.live
    private let logger = Logger.maru(category: "ImportManager")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?
    var testDeleteDictionaryEntitiesHook: (@Sendable (UUID, Int) async throws -> Void)?

    // MARK: - Init

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

    // MARK: - Public API: Enqueue

    /// Auto-detect the archive type and enqueue an import.
    /// - Parameter zipURL: The file URL of the ZIP archive to import.
    /// - Returns: The NSManagedObjectID of the created import job entity.
    public func enqueueImport(from zipURL: URL) async throws -> NSManagedObjectID {
        // Copy the file into app-controlled storage while we still have access.
        // Security-scoped URLs from fileImporter lose their access grant after a
        // balanced stop, and Core Data URI attributes strip security-scope info on
        // round-trip. Working from a local copy avoids both issues and makes the
        // import pipeline resilient to lifecycle/timing changes.
        let localURL = try Self.copyToImportStaging(from: zipURL)
        let originalDisplayName = zipURL.deletingPathExtension().lastPathComponent
        let contentType: ArchiveContentType
        do {
            contentType = try await ArchiveTypeDetector.detect(zipURL: localURL, manageSecurityScope: false)
        } catch {
            try? FileManager.default.removeItem(at: localURL)
            throw error
        }
        switch contentType {
        case .dictionary:
            return try await enqueueDictionaryImport(
                from: localURL,
                queuedDisplayName: originalDisplayName,
                updateTaskID: nil
            )
        case .audioSource:
            return try await enqueueAudioSourceImport(from: localURL, queuedDisplayName: originalDisplayName)
        case .tokenizerDictionary:
            return try await enqueueTokenizerDictionaryImport(
                from: localURL,
                queuedDisplayName: originalDisplayName,
                updateTaskID: nil
            )
        }
    }

    /// Copy a file into a staging directory in the temporary directory.
    ///
    /// Uses a UUID prefix to avoid name collisions from concurrent imports.
    private static func copyToImportStaging(from sourceURL: URL) throws -> URL {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportStaging", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let destURL = stagingDir.appendingPathComponent(
            UUID().uuidString + "-" + sourceURL.lastPathComponent
        )
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    private static var importStagingDirectoryURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportStaging", isDirectory: true)
    }

    private static func cleanupImportStagingFileIfNeeded(at fileURL: URL?) {
        guard let fileURL else { return }

        let stagingDirectoryURL = importStagingDirectoryURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let resolvedFileURL = fileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let stagingPath = stagingDirectoryURL.path
        let filePath = resolvedFileURL.path

        guard filePath == stagingPath || filePath.hasPrefix(stagingPath + "/") else {
            return
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: resolvedFileURL.path) {
            try? fileManager.removeItem(at: resolvedFileURL)
        }

        guard fileManager.fileExists(atPath: stagingDirectoryURL.path) else { return }
        if let remainingEntries = try? fileManager.contentsOfDirectory(
            at: stagingDirectoryURL,
            includingPropertiesForKeys: nil
        ), remainingEntries.isEmpty {
            try? fileManager.removeItem(at: stagingDirectoryURL)
        }
    }

    /// Enqueue a dictionary import from the given ZIP file URL.
    public func enqueueDictionaryImport(from zipURL: URL) async throws -> NSManagedObjectID {
        try await enqueueDictionaryImport(from: zipURL, queuedDisplayName: nil, updateTaskID: nil)
    }

    /// Enqueue a dictionary import tied to an update task.
    func enqueueDictionaryImport(
        from zipURL: URL,
        queuedDisplayName: String?,
        updateTaskID: UUID?
    ) async throws -> NSManagedObjectID {
        backgroundExpired = false
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let dictionary = Dictionary(context: context)
            let jobID = UUID()
            dictionary.id = jobID
            dictionary.file = zipURL
            let baseTitle = queuedDisplayName ?? zipURL.deletingPathExtension().lastPathComponent
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
        queue.append(.dictionary(importJob))
        processNextIfIdle()
        return importJob
    }

    /// Enqueue an audio source import from the given ZIP file URL.
    public func enqueueAudioSourceImport(from zipURL: URL) async throws -> NSManagedObjectID {
        try await enqueueAudioSourceImport(from: zipURL, queuedDisplayName: nil)
    }

    private func enqueueAudioSourceImport(from zipURL: URL, queuedDisplayName: String?) async throws -> NSManagedObjectID {
        backgroundExpired = false
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let job = AudioSource(context: context)
            let jobID = UUID()
            job.id = jobID
            job.file = zipURL
            let baseName = queuedDisplayName ?? zipURL.deletingPathExtension().lastPathComponent
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
            job.priority = try Self.getNextAudioSourcePriority(in: context)
            job.timeQueued = Date()
            try context.save()
            return job.objectID
        }
        queue.append(.audioSource(importJob))
        processNextIfIdle()
        return importJob
    }

    public func enqueueTokenizerDictionaryImport(from zipURL: URL) async throws -> NSManagedObjectID {
        try await enqueueTokenizerDictionaryImport(from: zipURL, queuedDisplayName: nil, updateTaskID: nil)
    }

    func enqueueTokenizerDictionaryImport(
        from zipURL: URL,
        queuedDisplayName: String?,
        updateTaskID: UUID?
    ) async throws -> NSManagedObjectID {
        backgroundExpired = false
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let tokenizerDictionary = TokenizerDictionary(context: context)
            let jobID = UUID()
            tokenizerDictionary.id = jobID
            tokenizerDictionary.file = zipURL
            let baseName = queuedDisplayName ?? zipURL.deletingPathExtension().lastPathComponent
            tokenizerDictionary.name = baseName.isEmpty ? "Imported Tokenizer Dictionary" : baseName
            tokenizerDictionary.timeQueued = Date()
            tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Queued for import.")
            tokenizerDictionary.isComplete = false
            tokenizerDictionary.isCurrent = false
            tokenizerDictionary.isFailed = false
            tokenizerDictionary.isCancelled = false
            tokenizerDictionary.isStarted = false
            tokenizerDictionary.errorMessage = nil
            tokenizerDictionary.updateReady = false
            tokenizerDictionary.updateTaskID = updateTaskID
            try context.save()
            return tokenizerDictionary.objectID
        }
        queue.append(.tokenizerDictionary(importJob))
        processNextIfIdle()
        return importJob
    }

    // MARK: - Public API: Cancel / Wait

    /// Cancel an ongoing or queued import job.
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJob?.jobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0.jobID == jobID }
            // Determine type for marking cancelled
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            let stagedArchiveURL: URL? = await context.perform {
                if let dictionary = try? context.existingObject(with: jobID) as? Dictionary {
                    Self.markDictionaryCancelled(dictionary)
                    let fileURL = dictionary.file
                    dictionary.file = nil
                    try? context.save()
                    return fileURL
                } else if let audioSource = try? context.existingObject(with: jobID) as? AudioSource {
                    Self.markAudioSourceCancelled(audioSource)
                    let fileURL = audioSource.file
                    audioSource.file = nil
                    try? context.save()
                    return fileURL
                } else if let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary {
                    Self.markTokenizerDictionaryCancelled(tokenizerDictionary)
                    let fileURL = tokenizerDictionary.file
                    tokenizerDictionary.file = nil
                    try? context.save()
                    return fileURL
                }
                return nil
            }
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        }
    }

    /// Wait for a given import job to complete.
    public func waitForCompletion(jobID: NSManagedObjectID) async {
        while true {
            if currentJob?.jobID == jobID {
                await currentTask?.value
                return
            } else if !queue.contains(where: { $0.jobID == jobID }) {
                return
            } else {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    // MARK: - Public API: Cleanup

    /// Mark interrupted imports as failed and clean any partially imported data.
    public func cleanupInterruptedImports() async {
        await cleanupInterruptedDictionaryImports()
        await cleanupInterruptedAudioSourceImports()
        await cleanupInterruptedTokenizerDictionaryImports()
    }

    /// Clean up entities marked for deletion but not yet removed.
    public func cleanupPendingDeletions(batchSize: Int = 10000) async {
        await cleanupPendingDictionaryDeletions(batchSize: batchSize)
        await cleanupPendingAudioSourceDeletions(batchSize: batchSize)
        await cleanupPendingTokenizerDictionaryDeletions()
    }

    // MARK: - Public API: Deletion

    /// Delete a dictionary and all its associated data.
    public func deleteDictionary(dictionaryID: NSManagedObjectID, batchSize: Int = 10000) async {
        logger.debug("Starting dictionary deletion for \(dictionaryID) with batch size \(batchSize)")

        guard deletionTasks[dictionaryID] == nil else { return }

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

    /// Delete an audio source and all its associated data.
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

    public func deleteTokenizerDictionary(tokenizerDictionaryID: NSManagedObjectID) async {
        guard deletionTasks[tokenizerDictionaryID] == nil else { return }

        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        taskContext.undoManager = nil

        do {
            try await taskContext.perform {
                guard let tokenizerDictionary = try? taskContext.existingObject(with: tokenizerDictionaryID) as? TokenizerDictionary else {
                    throw TokenizerDictionaryImportError.databaseError
                }
                tokenizerDictionary.pendingDeletion = true
                tokenizerDictionary.errorMessage = nil
                try taskContext.save()
            }
        } catch {
            logger.error("Failed to mark tokenizer dictionary for deletion \(tokenizerDictionaryID): \(error.localizedDescription)")
            return
        }

        let runner = backgroundTaskRunner
        let task = Task {
            await runner.run("Tokenizer Dictionary Delete", {
                Task {
                    await self.handleDeletionExpiration(for: tokenizerDictionaryID)
                }
            }, {
                await self.runTokenizerDictionaryDeletion(
                    tokenizerDictionaryID: tokenizerDictionaryID,
                    taskContext: taskContext
                )
            })
            finishDeletionTask(for: tokenizerDictionaryID)
        }
        deletionTasks[tokenizerDictionaryID] = task
    }

    // MARK: - Queue Lifecycle (Shared)

    private func processNextIfIdle() {
        guard !backgroundExpired, currentTask == nil, let nextJob = queue.first else { return }

        let runner = backgroundTaskRunner
        currentTask = Task {
            await runner.run("Import", {
                Task {
                    await self.handleImportExpiration(for: nextJob)
                }
            }, {
                await self.runImport(for: nextJob)
            })
            finishImportTask(for: nextJob)
        }
        currentJob = nextJob
    }

    private func finishImportTask(for job: QueuedImport) {
        if let index = queue.firstIndex(of: job) {
            queue.remove(at: index)
        }
        currentTask = nil
        currentJob = nil
        processNextIfIdle()
    }

    private func handleImportExpiration(for job: QueuedImport) async {
        guard currentJob == job else { return }
        backgroundExpired = true
        logger.error("Background time expired for import \(job.jobID)")
        let queuedJobs = queue.filter { $0 != job }
        queue.removeAll { $0 != job }
        if !queuedJobs.isEmpty {
            await markQueuedImportsCancelled(queuedJobs)
        }
        currentTask?.cancel()
    }

    private func markQueuedImportsCancelled(_ jobs: [QueuedImport]) async {
        guard !jobs.isEmpty else { return }

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let stagedArchiveURLs: [URL] = await context.perform {
            var fileURLs: [URL] = []
            for job in jobs {
                switch job {
                case let .dictionary(jobID):
                    guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else { continue }
                    Self.markDictionaryCancelled(dictionary)
                    if let fileURL = dictionary.file {
                        fileURLs.append(fileURL)
                    }
                    dictionary.file = nil
                case let .audioSource(jobID):
                    guard let audioSource = try? context.existingObject(with: jobID) as? AudioSource else { continue }
                    Self.markAudioSourceCancelled(audioSource)
                    if let fileURL = audioSource.file {
                        fileURLs.append(fileURL)
                    }
                    audioSource.file = nil
                case let .tokenizerDictionary(jobID):
                    guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else { continue }
                    Self.markTokenizerDictionaryCancelled(tokenizerDictionary)
                    if let fileURL = tokenizerDictionary.file {
                        fileURLs.append(fileURL)
                    }
                    tokenizerDictionary.file = nil
                }
            }
            try? context.save()
            return fileURLs
        }

        for fileURL in stagedArchiveURLs {
            Self.cleanupImportStagingFileIfNeeded(at: fileURL)
        }
    }

    private static func markDictionaryCancelled(_ dictionary: Dictionary) {
        let cancelledAt = Date()
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

    private static func markAudioSourceCancelled(_ audioSource: AudioSource) {
        let cancelledAt = Date()
        audioSource.isCancelled = true
        audioSource.isFailed = false
        audioSource.isComplete = false
        audioSource.isStarted = false
        audioSource.timeCancelled = cancelledAt
        audioSource.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
        audioSource.indexProcessed = false
        audioSource.entriesProcessed = false
        audioSource.mediaImported = false
    }

    private static func markTokenizerDictionaryCancelled(_ tokenizerDictionary: TokenizerDictionary) {
        let cancelledAt = Date()
        tokenizerDictionary.isCancelled = true
        tokenizerDictionary.isFailed = false
        tokenizerDictionary.isComplete = false
        tokenizerDictionary.isStarted = false
        tokenizerDictionary.timeCancelled = cancelledAt
        tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Import cancelled.")
        tokenizerDictionary.errorMessage = nil
        tokenizerDictionary.isCurrent = false
        tokenizerDictionary.updateReady = false
    }

    private func takeDictionaryImportArchiveURL(
        jobID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) async -> URL? {
        await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                return nil
            }
            let fileURL = dictionary.file
            dictionary.file = nil
            try? context.save()
            return fileURL
        }
    }

    private func takeAudioSourceImportArchiveURL(
        jobID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) async -> URL? {
        await context.perform {
            guard let audioSource = try? context.existingObject(with: jobID) as? AudioSource else {
                return nil
            }
            let fileURL = audioSource.file
            audioSource.file = nil
            try? context.save()
            return fileURL
        }
    }

    private func takeTokenizerDictionaryImportArchiveURL(
        jobID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) async -> URL? {
        await context.perform {
            guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                return nil
            }
            let fileURL = tokenizerDictionary.file
            tokenizerDictionary.file = nil
            try? context.save()
            return fileURL
        }
    }

    // MARK: - Import Dispatch

    private func runImport(for job: QueuedImport) async {
        switch job {
        case let .dictionary(jobID):
            await runDictionaryImport(for: jobID)
        case let .audioSource(jobID):
            await runAudioSourceImport(for: jobID)
        case let .tokenizerDictionary(jobID):
            await runTokenizerDictionaryImport(for: jobID)
        }
    }

    // MARK: - Dictionary Import Pipeline

    private func runDictionaryImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting dictionary import job \(jobID)")
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
            let stagedArchiveURL = await takeDictionaryImportArchiveURL(jobID: jobID, in: context)
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        } catch is CancellationError {
            if let uuid = dictionaryUUID {
                try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: uuid, batchSize: 10000)
            }
            let cleanupInfo: (UUID?, URL?) = await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    return (nil, nil)
                }
                Self.markDictionaryCancelled(dictionary)
                let fileURL = dictionary.file
                dictionary.file = nil
                try? context.save()
                return (dictionary.id, fileURL)
            }
            Self.cleanupImportStagingFileIfNeeded(at: cleanupInfo.1)
            if let uuid = cleanupInfo.0 {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
            }
        } catch {
            if let uuid = dictionaryUUID {
                try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: uuid, batchSize: 10000)
            }
            let cleanupInfo: (UUID?, URL?) = await context.perform {
                guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                    return (nil, nil)
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
                let fileURL = dictionary.file
                dictionary.file = nil

                try? context.save()

                return (dictionary.id, fileURL)
            }
            Self.cleanupImportStagingFileIfNeeded(at: cleanupInfo.1)
            if let uuid = cleanupInfo.0 {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
            }
        }

        await context.perform {
            _ = try? context.existingObject(with: jobID) as? Dictionary
        }
    }

    // MARK: - Audio Source Import Pipeline

    private func runAudioSourceImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting audio source import job \(jobID)")
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        var sourceID: UUID?
        var scratchSpace: ImportScratchSpace?
        defer {
            scratchSpace?.cleanupBestEffort()
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
            if let sourceID {
                scratchSpace = ImportScratchSpace(kind: .audio, jobUUID: sourceID)
            }

            try Task.checkCancellation()
            try testErrorInjection?()

            // Stage 1: Process index
            let indexTask = AudioSourceIndexProcessingTask(jobID: jobID, container: container)
            let indexResult = try await indexTask.start()
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
            let stagedArchiveURL = await takeAudioSourceImportArchiveURL(jobID: jobID, in: context)
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)

        } catch is CancellationError {
            let capturedSourceID = sourceID
            let capturedBaseDirectory = baseDirectory
            if let id = capturedSourceID {
                try? await deleteAudioSourceEntitiesInBatches(sourceID: id, batchSize: 10000)
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id, baseDirectory: capturedBaseDirectory)
            }
            let stagedArchiveURL: URL? = await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    return nil
                }
                Self.markAudioSourceCancelled(job)
                let fileURL = job.file
                job.file = nil
                try? context.save()
                return fileURL
            }
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        } catch {
            let capturedSourceID = sourceID
            let capturedBaseDirectory = baseDirectory
            if let id = capturedSourceID {
                try? await deleteAudioSourceEntitiesInBatches(sourceID: id, batchSize: 10000)
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: id, baseDirectory: capturedBaseDirectory)
            }
            let stagedArchiveURL: URL? = await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? AudioSource else {
                    return nil
                }
                job.isFailed = true
                job.isCancelled = false
                job.isComplete = false
                job.displayProgressMessage = error.localizedDescription
                job.timeFailed = Date()
                let fileURL = job.file
                job.file = nil
                try? context.save()
                return fileURL
            }
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        }

        await context.perform {
            _ = try? context.existingObject(with: jobID) as? AudioSource
        }
    }

    // MARK: - Tokenizer Dictionary Import Pipeline

    private func runTokenizerDictionaryImport(for jobID: NSManagedObjectID) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        var tokenizerID: UUID?
        var scratchSpace: ImportScratchSpace?
        defer {
            scratchSpace?.cleanupBestEffort()
        }

        do {
            tokenizerID = try await context.perform {
                guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                    throw TokenizerDictionaryImportError.databaseError
                }
                if tokenizerDictionary.id == nil {
                    tokenizerDictionary.id = UUID()
                }
                tokenizerDictionary.isComplete = false
                tokenizerDictionary.isCurrent = false
                tokenizerDictionary.isFailed = false
                tokenizerDictionary.isCancelled = false
                tokenizerDictionary.isStarted = true
                tokenizerDictionary.timeStarted = Date()
                tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Starting import...")
                tokenizerDictionary.errorMessage = nil
                try context.save()
                guard let tokenizerID = tokenizerDictionary.id else {
                    throw TokenizerDictionaryImportError.databaseError
                }
                return tokenizerID
            }
            if let tokenizerID {
                scratchSpace = ImportScratchSpace(kind: .tokenizer, jobUUID: tokenizerID)
            }

            try Task.checkCancellation()
            try testErrorInjection?()

            let importTask = TokenizerDictionaryImportTask(
                jobID: jobID,
                container: container,
                baseDirectory: baseDirectory
            )
            let result = try await importTask.start()

            for replacedObjectID in result.replacedTokenizerObjectIDs {
                await deleteTokenizerDictionary(tokenizerDictionaryID: replacedObjectID)
            }
            let stagedArchiveURL = await takeTokenizerDictionaryImportArchiveURL(jobID: jobID, in: context)
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        } catch is CancellationError {
            let stagedArchiveURL: URL? = await context.perform {
                guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                    return nil
                }
                Self.markTokenizerDictionaryCancelled(tokenizerDictionary)
                let fileURL = tokenizerDictionary.file
                tokenizerDictionary.file = nil
                try? context.save()
                return fileURL
            }
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        } catch {
            let stagedArchiveURL: URL? = await context.perform {
                guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                    return nil
                }
                tokenizerDictionary.isFailed = true
                tokenizerDictionary.isCancelled = false
                tokenizerDictionary.isComplete = false
                tokenizerDictionary.isCurrent = false
                tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Import failed.")
                tokenizerDictionary.errorMessage = error.localizedDescription
                tokenizerDictionary.timeFailed = Date()
                let fileURL = tokenizerDictionary.file
                tokenizerDictionary.file = nil
                try? context.save()
                return fileURL
            }
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        }

        await context.perform {
            _ = try? context.existingObject(with: jobID) as? TokenizerDictionary
        }
    }

    // MARK: - Dictionary Cleanup

    private func cleanupInterruptedDictionaryImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (cleanupEntries, retryJobIDs): ([(UUID, URL?)], [NSManagedObjectID]) = await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO AND pendingDeletion == NO")
            let dictionaries = (try? context.fetch(request)) ?? []
            guard !dictionaries.isEmpty else { return ([], []) }

            let now = Date()
            var entries: [(UUID, URL?)] = []
            var retryJobIDs: [NSManagedObjectID] = []
            for dictionary in dictionaries {
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
                    if let dictionaryID = dictionary.id {
                        entries.append((dictionaryID, dictionary.file))
                    }
                    dictionary.isFailed = true
                    dictionary.isCancelled = false
                    dictionary.isComplete = false
                    dictionary.displayProgressMessage = FrameworkLocalization.string("Import interrupted.")
                    dictionary.errorMessage = FrameworkLocalization.string("Import interrupted.")
                    dictionary.timeFailed = now
                    dictionary.file = nil
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
            return (entries, retryJobIDs)
        }

        if !cleanupEntries.isEmpty {
            logger.debug("Cleaning up \(cleanupEntries.count, privacy: .public) interrupted dictionary imports")

            for (dictionaryID, stagedArchiveURL) in cleanupEntries {
                try? await deleteDictionaryEntitiesInBatches(dictionaryUUID: dictionaryID, batchSize: 10000)
                cleanMediaDirectoryByUUID(dictionaryUUID: dictionaryID)
                cleanCompressionDictionaryByUUID(dictionaryUUID: dictionaryID)
                cleanDictionaryScratchDirectory(dictionaryUUID: dictionaryID)
                Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
            }
        }

        guard !retryJobIDs.isEmpty else { return }
        for jobID in retryJobIDs where currentJob?.jobID != jobID && !queue.contains(where: { $0.jobID == jobID }) {
            queue.append(.dictionary(jobID))
        }
        processNextIfIdle()
    }

    private func cleanupPendingDictionaryDeletions(batchSize: Int) async {
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

    // MARK: - Audio Source Cleanup

    private func cleanupInterruptedAudioSourceImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupEntries: [(UUID, URL?)] = await context.perform {
            let request: NSFetchRequest<AudioSource> = AudioSource.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO AND pendingDeletion == NO")
            let sources = (try? context.fetch(request)) ?? []
            guard !sources.isEmpty else { return [] }

            let now = Date()
            var entries: [(UUID, URL?)] = []
            for source in sources {
                if let sourceID = source.id {
                    entries.append((sourceID, source.file))
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
                source.file = nil
            }

            try? context.save()
            return entries
        }

        guard !cleanupEntries.isEmpty else { return }
        logger.debug("Cleaning up \(cleanupEntries.count, privacy: .public) interrupted audio source imports")

        for (sourceID, stagedArchiveURL) in cleanupEntries {
            try? await deleteAudioSourceEntitiesInBatches(sourceID: sourceID, batchSize: 10000)
            AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: sourceID, baseDirectory: baseDirectory)
            cleanAudioSourceScratchDirectory(sourceID: sourceID)
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        }
    }

    private func cleanupPendingAudioSourceDeletions(batchSize: Int) async {
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

    // MARK: - Tokenizer Dictionary Cleanup

    private func cleanupInterruptedTokenizerDictionaryImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (cleanupEntries, retryJobIDs): ([(UUID, URL?)], [NSManagedObjectID]) = await context.perform {
            let request: NSFetchRequest<TokenizerDictionary> = TokenizerDictionary.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO AND pendingDeletion == NO")
            let tokenizerDictionaries = (try? context.fetch(request)) ?? []
            guard !tokenizerDictionaries.isEmpty else { return ([], []) }

            let now = Date()
            var entries: [(UUID, URL?)] = []
            var retryJobIDs: [NSManagedObjectID] = []
            for tokenizerDictionary in tokenizerDictionaries {
                if tokenizerDictionary.updateTaskID != nil {
                    tokenizerDictionary.isFailed = false
                    tokenizerDictionary.isCancelled = false
                    tokenizerDictionary.isComplete = false
                    tokenizerDictionary.isStarted = false
                    tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Retrying update import.")
                    tokenizerDictionary.errorMessage = nil
                    tokenizerDictionary.timeQueued = now
                    tokenizerDictionary.timeStarted = nil
                    tokenizerDictionary.timeFailed = nil
                    tokenizerDictionary.timeCancelled = nil
                    retryJobIDs.append(tokenizerDictionary.objectID)
                } else {
                    if let tokenizerID = tokenizerDictionary.id {
                        entries.append((tokenizerID, tokenizerDictionary.file))
                    }
                    tokenizerDictionary.isFailed = true
                    tokenizerDictionary.isCancelled = false
                    tokenizerDictionary.isComplete = false
                    tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Import interrupted.")
                    tokenizerDictionary.errorMessage = FrameworkLocalization.string("Import interrupted.")
                    tokenizerDictionary.timeFailed = now
                    tokenizerDictionary.file = nil
                }
                tokenizerDictionary.isCurrent = false
            }

            try? context.save()
            return (entries, retryJobIDs)
        }

        for (tokenizerID, stagedArchiveURL) in cleanupEntries {
            ImportScratchSpace(kind: .tokenizer, jobUUID: tokenizerID).cleanupBestEffort()
            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)
        }

        for jobID in retryJobIDs where currentJob?.jobID != jobID && !queue.contains(where: { $0.jobID == jobID }) {
            queue.append(.tokenizerDictionary(jobID))
        }
        processNextIfIdle()
    }

    private func cleanupPendingTokenizerDictionaryDeletions() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<TokenizerDictionary> = TokenizerDictionary.fetchRequest()
            request.predicate = NSPredicate(format: "pendingDeletion == YES")
            let tokenizerDictionaries = (try? context.fetch(request)) ?? []
            return tokenizerDictionaries.map(\.objectID)
        }

        for tokenizerDictionaryID in pendingIDs {
            await deleteTokenizerDictionary(tokenizerDictionaryID: tokenizerDictionaryID)
        }
    }

    // MARK: - Deletion Workers

    private func handleDeletionExpiration(for entityID: NSManagedObjectID) {
        guard let task = deletionTasks[entityID] else { return }
        logger.error("Background time expired for deletion \(entityID)")
        task.cancel()
    }

    private func finishDeletionTask(for entityID: NSManagedObjectID) {
        deletionTasks[entityID] = nil
    }

    private func runDictionaryDeletion(
        dictionaryID: NSManagedObjectID,
        batchSize: Int,
        taskContext: NSManagedObjectContext
    ) async {
        do {
            try Task.checkCancellation()

            let (dictionaryUUID, stagedArchiveURL) = try await taskContext.perform {
                guard let dictionary = try? taskContext.existingObject(with: dictionaryID) as? Dictionary else {
                    throw DictionaryImportError.databaseError
                }
                let fileURL = dictionary.file
                dictionary.file = nil
                try taskContext.save()
                return (dictionary.id, fileURL)
            }

            try Task.checkCancellation()

            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)

            try Task.checkCancellation()

            if let uuid = dictionaryUUID {
                cleanMediaDirectoryByUUID(dictionaryUUID: uuid)
                cleanCompressionDictionaryByUUID(dictionaryUUID: uuid)
                cleanDictionaryScratchDirectory(dictionaryUUID: uuid)
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

    private func runAudioSourceDeletion(
        sourceID: NSManagedObjectID,
        batchSize: Int,
        taskContext: NSManagedObjectContext
    ) async {
        do {
            try Task.checkCancellation()

            let (audioSourceUUID, stagedArchiveURL) = try await taskContext.perform {
                guard let audioSource = try? taskContext.existingObject(with: sourceID) as? AudioSource else {
                    throw AudioSourceImportError.databaseError
                }
                let fileURL = audioSource.file
                audioSource.file = nil
                try taskContext.save()
                return (audioSource.id, fileURL)
            }

            try Task.checkCancellation()

            Self.cleanupImportStagingFileIfNeeded(at: stagedArchiveURL)

            try Task.checkCancellation()

            if let uuid = audioSourceUUID {
                AudioSourceMediaCopyTask.cleanMediaDirectory(sourceID: uuid, baseDirectory: baseDirectory)
                cleanAudioSourceScratchDirectory(sourceID: uuid)
                try Task.checkCancellation()
                try await deleteAudioSourceEntitiesInBatches(sourceID: uuid, batchSize: batchSize)
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

    private func runTokenizerDictionaryDeletion(
        tokenizerDictionaryID: NSManagedObjectID,
        taskContext: NSManagedObjectContext
    ) async {
        do {
            try Task.checkCancellation()

            let tokenizerInfo = try await taskContext.perform {
                guard let tokenizerDictionary = try? taskContext.existingObject(with: tokenizerDictionaryID) as? TokenizerDictionary else {
                    throw TokenizerDictionaryImportError.databaseError
                }
                let fileURL = tokenizerDictionary.file
                tokenizerDictionary.file = nil
                try taskContext.save()
                return (tokenizerDictionary.id, tokenizerDictionary.isCurrent, fileURL)
            }

            try Task.checkCancellation()

            Self.cleanupImportStagingFileIfNeeded(at: tokenizerInfo.2)

            try Task.checkCancellation()

            if tokenizerInfo.1, let installDirectory = TokenizerDictionaryStorage.installedDirectoryURL(in: baseDirectory),
               FileManager.default.fileExists(atPath: installDirectory.path)
            {
                try FileManager.default.removeItem(at: installDirectory)
            }

            if let tokenizerID = tokenizerInfo.0 {
                ImportScratchSpace(kind: .tokenizer, jobUUID: tokenizerID).cleanupBestEffort()
            }

            try Task.checkCancellation()

            let finalContext = container.newBackgroundContext()
            finalContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            finalContext.undoManager = nil

            try await finalContext.perform {
                guard let tokenizerDictionary = try? finalContext.existingObject(with: tokenizerDictionaryID) as? TokenizerDictionary else {
                    throw TokenizerDictionaryImportError.databaseError
                }
                finalContext.delete(tokenizerDictionary)
                try finalContext.save()
            }
        } catch is CancellationError {
            logger.error("Tokenizer dictionary deletion cancelled for \(tokenizerDictionaryID); cleanup will resume later")
        } catch {
            logger.error("Tokenizer dictionary deletion failed for \(tokenizerDictionaryID): \(error.localizedDescription)")
            await taskContext.perform {
                guard let tokenizerDictionary = try? taskContext.existingObject(with: tokenizerDictionaryID) as? TokenizerDictionary else {
                    return
                }
                tokenizerDictionary.pendingDeletion = false
                tokenizerDictionary.errorMessage = error.localizedDescription
                try? taskContext.save()
            }
        }
    }

    // MARK: - Dictionary Glossary Compression Fallback

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
                glossaryZSTDCompressionLevel: glossaryCompressionTrainingProfile.zstdCompressionLevel,
                container: container
            )
            do {
                try await dataBankProcessingTask.start()
                return version
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let isLastVersion = index == versionsToTry.count - 1
                if isLastVersion {
                    throw error
                }
                logger.warning(
                    "Dictionary \(dictionaryID.uuidString, privacy: .public) import using \(version.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public). Retrying with next compression version."
                )
                try await cleanupPartialImportForCompressionRetry(
                    dictionaryUUID: dictionaryID,
                    batchSize: 10000
                )
                try await resetImportStateForCompressionRetry(jobID: jobID)
            }
        }

        throw DictionaryImportError.databaseError
    }

    static func glossaryCompressionVersionsToTry(
        requested: GlossaryCompressionCodecVersion,
        prepared: GlossaryCompressionCodecVersion
    ) -> [GlossaryCompressionCodecVersion] {
        var versions = [prepared]

        func appendIfNeeded(_ version: GlossaryCompressionCodecVersion) {
            guard version != prepared else {
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

    // MARK: - Dictionary Batch Deletion

    private func deleteDictionaryEntitiesInBatches(dictionaryUUID: UUID, batchSize: Int) async throws {
        for entityName in Self.dictionaryEntryEntityNames {
            try Task.checkCancellation()
            logger.debug("Deleting \(entityName) entities for dictionary \(dictionaryUUID)")
            try await deleteBatchesForDictionaryEntity(entityName: entityName, dictionaryUUID: dictionaryUUID, batchSize: batchSize)
        }
    }

    private func deleteBatchesForDictionaryEntity(entityName: String, dictionaryUUID: UUID, batchSize: Int) async throws {
        while true {
            try Task.checkCancellation()
            let moreToDelete = try await deleteDictionaryEntityBatch(entityName: entityName, dictionaryUUID: dictionaryUUID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteDictionaryEntityBatch(entityName: String, dictionaryUUID: UUID, batchSize: Int) async throws -> Bool {
        try Task.checkCancellation()
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        return try await context.perform {
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

    // MARK: - Audio Source Batch Deletion

    private func deleteAudioSourceEntitiesInBatches(sourceID: UUID, batchSize: Int) async throws {
        try await deleteAudioSourceEntityBatches(entityName: "AudioHeadword", sourceID: sourceID, batchSize: batchSize)
        try await deleteAudioSourceEntityBatches(entityName: "AudioFile", sourceID: sourceID, batchSize: batchSize)
    }

    private func deleteAudioSourceEntityBatches(entityName: String, sourceID: UUID, batchSize: Int) async throws {
        while true {
            try Task.checkCancellation()
            let moreToDelete = try await deleteAudioSourceEntityBatch(entityName: entityName, sourceID: sourceID, batchSize: batchSize)
            if !moreToDelete {
                break
            }
        }
    }

    private func deleteAudioSourceEntityBatch(entityName: String, sourceID: UUID, batchSize: Int) async throws -> Bool {
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

    // MARK: - File Cleanup Helpers

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

    private func cleanDictionaryScratchDirectory(dictionaryUUID: UUID) {
        ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryUUID).cleanupBestEffort()
    }

    private func cleanAudioSourceScratchDirectory(sourceID: UUID) {
        ImportScratchSpace(kind: .audio, jobUUID: sourceID).cleanupBestEffort()
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

    // MARK: - Audio Source Priority

    private static func getNextAudioSourcePriority(in context: NSManagedObjectContext) throws -> Int64 {
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

    func setTestDeleteDictionaryEntitiesHook(_ hook: (@Sendable (UUID, Int) async throws -> Void)?) {
        testDeleteDictionaryEntitiesHook = hook
    }

    func setBackgroundTaskRunner(_ runner: ApplicationBackgroundTaskRunner) {
        backgroundTaskRunner = runner
    }
}
