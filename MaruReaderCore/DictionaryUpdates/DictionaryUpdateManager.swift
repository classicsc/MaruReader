// DictionaryUpdateManager.swift
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
import os.log

public protocol DictionaryUpdateAnkiPreferencesUpdating: Sendable {
    func replaceDictionaryIDs(oldID: UUID, newID: UUID) async
}

public actor DictionaryUpdateManager {
    public static let shared = DictionaryUpdateManager(
        container: DictionaryPersistenceController.shared.container,
        importManager: DictionaryImportManager.shared,
        networkProvider: URLSession.shared
    )

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentTaskID: NSManagedObjectID?
    private let container: NSPersistentContainer
    private let importManager: DictionaryImportManager
    private let networkProvider: NetworkProviding
    private var ankiUpdater: (any DictionaryUpdateAnkiPreferencesUpdating)?
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryUpdate")

    init(container: NSPersistentContainer, importManager: DictionaryImportManager, networkProvider: NetworkProviding) {
        self.container = container
        self.importManager = importManager
        self.networkProvider = networkProvider
    }

    public func setAnkiPreferencesUpdater(_ updater: (any DictionaryUpdateAnkiPreferencesUpdating)?) {
        ankiUpdater = updater
    }

    public func checkForUpdates() async -> Int {
        struct Candidate: Sendable {
            let objectID: NSManagedObjectID
            let indexURL: String?
            let revision: String?
            let downloadURL: String?
        }

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let candidates: [Candidate] = await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == YES AND pendingDeletion == NO AND isUpdatable == YES")
            let dictionaries = (try? context.fetch(request)) ?? []
            return dictionaries.map { dictionary in
                Candidate(
                    objectID: dictionary.objectID,
                    indexURL: dictionary.indexURL,
                    revision: dictionary.revision,
                    downloadURL: dictionary.downloadURL
                )
            }
        }

        guard !candidates.isEmpty else { return 0 }

        var results: [(NSManagedObjectID, Bool, String?)] = []
        for candidate in candidates {
            do {
                guard let indexURL = candidate.indexURL,
                      let currentRevision = candidate.revision,
                      let url = URL(string: indexURL)
                else {
                    results.append((candidate.objectID, false, nil))
                    continue
                }
                let (data, _) = try await networkProvider.data(from: url)
                let index = try JSONDecoder().decode(DictionaryIndex.self, from: data)
                guard let latestRevision = index.revision else {
                    results.append((candidate.objectID, false, nil))
                    continue
                }
                let hasUpdate = Self.compareRevisions(current: currentRevision, latest: latestRevision)
                let downloadURL = index.downloadUrl ?? candidate.downloadURL
                results.append((candidate.objectID, hasUpdate, downloadURL))
            } catch {
                logger.error("Update check failed: \(error.localizedDescription)")
                results.append((candidate.objectID, false, nil))
            }
        }

        let updateResults = results
        return await context.perform {
            var count = 0
            for (objectID, hasUpdate, downloadURL) in updateResults {
                guard let dictionary = try? context.existingObject(with: objectID) as? Dictionary else {
                    continue
                }
                dictionary.updateReady = hasUpdate
                if hasUpdate {
                    count += 1
                    if let downloadURL {
                        dictionary.downloadURL = downloadURL
                    }
                }
            }
            try? context.save()
            return count
        }
    }

    @discardableResult
    public func enqueueUpdate(for dictionaryID: NSManagedObjectID) async throws -> NSManagedObjectID {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let taskID = try await context.perform {
            guard let dictionary = try? context.existingObject(with: dictionaryID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            guard dictionary.isComplete, dictionary.updateReady else {
                throw DictionaryImportError.importNotFound
            }
            guard let dictionaryUUID = dictionary.id else {
                throw DictionaryImportError.dictionaryCreationFailed
            }

            let existingRequest: NSFetchRequest<DictionaryUpdateTask> = DictionaryUpdateTask.fetchRequest()
            existingRequest.predicate = NSPredicate(format: "dictionaryID == %@ AND isComplete == NO AND isFailed == NO AND isCancelled == NO", dictionaryUUID as CVarArg)
            existingRequest.fetchLimit = 1
            if let existingTask = try? context.fetch(existingRequest).first {
                return existingTask.objectID
            }

            guard let downloadURL = dictionary.downloadURL else {
                throw DictionaryImportError.missingFile
            }

            let task = DictionaryUpdateTask(context: context)
            let taskUUID = UUID()
            task.id = taskUUID
            task.dictionaryID = dictionaryUUID
            task.dictionaryTitle = dictionary.title ?? "Dictionary"
            task.downloadURL = downloadURL
            task.displayProgressMessage = String(localized: "Queued for update.")
            task.isComplete = false
            task.isFailed = false
            task.isCancelled = false
            task.isStarted = false
            task.timeQueued = Date()
            task.bytesReceived = 0
            task.totalBytes = 0

            dictionary.updateReady = false

            try context.save()
            return task.objectID
        }

        if currentTaskID != taskID, !queue.contains(taskID) {
            queue.append(taskID)
            processNextIfIdle()
        }
        return taskID
    }

    public func enqueueUpdates(for dictionaryIDs: [NSManagedObjectID]) async {
        for dictionaryID in dictionaryIDs {
            _ = try? await enqueueUpdate(for: dictionaryID)
        }
    }

    public func resumePendingUpdates() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingTasks: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<DictionaryUpdateTask> = DictionaryUpdateTask.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isFailed == NO AND isCancelled == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "timeQueued", ascending: true)]
            let tasks = (try? context.fetch(request)) ?? []
            return tasks.map(\.objectID)
        }

        guard !pendingTasks.isEmpty else { return }
        for taskID in pendingTasks where currentTaskID != taskID && !queue.contains(taskID) {
            queue.append(taskID)
        }
        processNextIfIdle()
    }

    func waitForCompletion(taskID: NSManagedObjectID) async {
        while true {
            if currentTaskID == taskID {
                await currentTask?.value
                return
            } else if !queue.contains(taskID) {
                return
            } else {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func processNextIfIdle() {
        guard currentTask == nil, let nextTask = queue.first else { return }

        currentTask = Task {
            await runUpdate(for: nextTask)
            queue.removeFirst()
            currentTask = nil
            currentTaskID = nil
            processNextIfIdle()
        }
        currentTaskID = nextTask
    }

    private func runUpdate(for taskID: NSManagedObjectID) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        struct UpdateInfo: Sendable {
            let taskUUID: UUID
            let dictionaryID: UUID
            let downloadURL: String
            let existingFile: URL?
        }

        let updateInfo: UpdateInfo
        do {
            updateInfo = try await context.perform {
                guard let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask,
                      let taskUUID = task.id
                else {
                    throw DictionaryImportError.importNotFound
                }
                guard let dictionaryID = task.dictionaryID,
                      let downloadURL = task.downloadURL
                else {
                    throw DictionaryImportError.dictionaryCreationFailed
                }
                task.isStarted = true
                task.isFailed = false
                task.isCancelled = false
                task.timeStarted = Date()
                task.displayProgressMessage = String(localized: "Preparing update...")
                let existingFile = task.downloadedFile
                try context.save()

                return UpdateInfo(
                    taskUUID: taskUUID,
                    dictionaryID: dictionaryID,
                    downloadURL: downloadURL,
                    existingFile: existingFile
                )
            }
        } catch {
            logger.error("Failed to start update task: \(error.localizedDescription)")
            return
        }

        let updateFileURL: URL
        do {
            if let existingFile = updateInfo.existingFile,
               FileManager.default.fileExists(atPath: existingFile.path)
            {
                updateFileURL = existingFile
            } else {
                guard let downloadURL = URL(string: updateInfo.downloadURL) else {
                    throw DictionaryImportError.missingFile
                }
                await context.perform {
                    if let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask {
                        task.displayProgressMessage = String(localized: "Downloading update...")
                        task.bytesReceived = 0
                        task.totalBytes = 0
                        try? context.save()
                    }
                }

                let (data, response) = try await networkProvider.data(from: downloadURL)
                let expectedBytes = response.expectedContentLength > 0 ? response.expectedContentLength : Int64(data.count)
                let destination = try downloadDestinationURL(for: updateInfo.taskUUID)
                try data.write(to: destination, options: [.atomic])
                updateFileURL = destination

                await context.perform {
                    if let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask {
                        task.bytesReceived = Int64(data.count)
                        task.totalBytes = expectedBytes
                        task.downloadedFile = destination
                        task.displayProgressMessage = String(localized: "Downloaded update.")
                        try? context.save()
                    }
                }
            }
        } catch {
            await markTaskFailed(taskID: taskID, dictionaryID: updateInfo.dictionaryID, error: error)
            return
        }

        await context.perform {
            if let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask {
                task.displayProgressMessage = String(localized: "Importing update...")
                try? context.save()
            }
        }

        let importJobID: NSManagedObjectID
        do {
            if let existingJobID = await findUpdateImportJob(taskUUID: updateInfo.taskUUID, in: context) {
                importJobID = existingJobID
            } else {
                importJobID = try await importManager.enqueueImport(from: updateFileURL, updateTaskID: updateInfo.taskUUID)
            }
        } catch {
            await markTaskFailed(taskID: taskID, dictionaryID: updateInfo.dictionaryID, error: error)
            return
        }

        await importManager.waitForCompletion(jobID: importJobID)

        do {
            let updateOutcome = try await finalizeUpdate(
                taskID: taskID,
                importJobID: importJobID,
                originalDictionaryID: updateInfo.dictionaryID
            )
            await ankiUpdater?.replaceDictionaryIDs(oldID: updateOutcome.oldDictionaryID, newID: updateOutcome.newDictionaryID)
            await importManager.deleteDictionary(dictionaryID: updateOutcome.oldDictionaryObjectID)
            await context.perform {
                if let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask {
                    task.isComplete = true
                    task.timeCompleted = Date()
                    task.displayProgressMessage = String(localized: "Update complete.")
                    try? context.save()
                }
            }
            try? FileManager.default.removeItem(at: updateFileURL)
        } catch {
            await markTaskFailed(taskID: taskID, dictionaryID: updateInfo.dictionaryID, error: error)
        }
    }

    private func markTaskFailed(taskID: NSManagedObjectID, dictionaryID: UUID, error: Error) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        await context.perform {
            if let task = try? context.existingObject(with: taskID) as? DictionaryUpdateTask {
                task.isFailed = true
                task.isComplete = false
                task.isCancelled = false
                task.timeFailed = Date()
                task.errorMessage = error.localizedDescription
                task.displayProgressMessage = String(localized: "Update failed.")
            }
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", dictionaryID as CVarArg)
            request.fetchLimit = 1
            if let dictionary = try? context.fetch(request).first {
                dictionary.updateReady = true
            }
            try? context.save()
        }
    }

    private func findUpdateImportJob(taskUUID: UUID, in context: NSManagedObjectContext) async -> NSManagedObjectID? {
        await context.perform {
            let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            request.predicate = NSPredicate(format: "updateTaskID == %@", taskUUID as CVarArg)
            request.fetchLimit = 1
            let dictionary = try? context.fetch(request).first
            return dictionary?.objectID
        }
    }

    private struct UpdateOutcome: Sendable {
        let newDictionaryID: UUID
        let oldDictionaryID: UUID
        let oldDictionaryObjectID: NSManagedObjectID
    }

    private func finalizeUpdate(
        taskID _: NSManagedObjectID,
        importJobID: NSManagedObjectID,
        originalDictionaryID: UUID
    ) async throws -> UpdateOutcome {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        return try await context.perform {
            guard let newDictionary = try? context.existingObject(with: importJobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            context.refresh(newDictionary, mergeChanges: true)
            guard newDictionary.isComplete, newDictionary.isFailed == false else {
                throw DictionaryImportError.databaseError
            }
            guard let newDictionaryID = newDictionary.id else {
                throw DictionaryImportError.dictionaryCreationFailed
            }

            let oldDictionaryRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
            oldDictionaryRequest.predicate = NSPredicate(format: "id == %@", originalDictionaryID as CVarArg)
            oldDictionaryRequest.fetchLimit = 1
            guard let oldDictionary = try? context.fetch(oldDictionaryRequest).first else {
                throw DictionaryImportError.importNotFound
            }

            Self.applyPreferences(from: oldDictionary, to: newDictionary)
            newDictionary.updateTaskID = nil
            newDictionary.updateReady = false
            oldDictionary.updateReady = false

            try context.save()

            return UpdateOutcome(
                newDictionaryID: newDictionaryID,
                oldDictionaryID: originalDictionaryID,
                oldDictionaryObjectID: oldDictionary.objectID
            )
        }
    }

    private static func applyPreferences(from oldDictionary: Dictionary, to newDictionary: Dictionary) {
        newDictionary.termDisplayPriority = oldDictionary.termDisplayPriority
        newDictionary.kanjiDisplayPriority = oldDictionary.kanjiDisplayPriority
        newDictionary.ipaDisplayPriority = oldDictionary.ipaDisplayPriority
        newDictionary.pitchDisplayPriority = oldDictionary.pitchDisplayPriority
        newDictionary.termFrequencyDisplayPriority = oldDictionary.termFrequencyDisplayPriority
        newDictionary.kanjiFrequencyDisplayPriority = oldDictionary.kanjiFrequencyDisplayPriority

        newDictionary.termResultsEnabled = oldDictionary.termResultsEnabled && newDictionary.termCount > 0
        newDictionary.kanjiResultsEnabled = oldDictionary.kanjiResultsEnabled && newDictionary.kanjiCount > 0
        newDictionary.termFrequencyEnabled = oldDictionary.termFrequencyEnabled && newDictionary.termFrequencyCount > 0
        newDictionary.kanjiFrequencyEnabled = oldDictionary.kanjiFrequencyEnabled && newDictionary.kanjiFrequencyCount > 0
        newDictionary.pitchAccentEnabled = oldDictionary.pitchAccentEnabled && newDictionary.pitchesCount > 0
        newDictionary.ipaEnabled = oldDictionary.ipaEnabled && newDictionary.ipaCount > 0
    }

    private func downloadDestinationURL(for taskUUID: UUID) throws -> URL {
        let updateRoot = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) ?? FileManager.default.temporaryDirectory
        let updateDir = updateRoot.appendingPathComponent("DictionaryUpdates", isDirectory: true)
        try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)
        return updateDir.appendingPathComponent("\(taskUUID.uuidString).zip")
    }

    private static func compareRevisions(current: String, latest: String) -> Bool {
        let pattern = "^(\\d+\\.)*\\d+$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let currentRange = NSRange(location: 0, length: current.utf16.count)
        let latestRange = NSRange(location: 0, length: latest.utf16.count)
        let isCurrentSimple = regex?.firstMatch(in: current, options: [], range: currentRange) != nil
        let isLatestSimple = regex?.firstMatch(in: latest, options: [], range: latestRange) != nil

        guard isCurrentSimple, isLatestSimple else {
            return current < latest
        }

        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        guard currentParts.count == latestParts.count else {
            return current < latest
        }

        for (currentPart, latestPart) in zip(currentParts, latestParts) {
            if currentPart != latestPart {
                return currentPart < latestPart
            }
        }

        return false
    }
}
