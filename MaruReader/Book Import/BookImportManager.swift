// BookImportManager.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import os.log

actor BookImportManager {
    static let shared = BookImportManager(container: BookDataPersistenceController.shared.container)

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var container: NSPersistentContainer
    private var logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    /// Initializer for both shared instance and testing with custom container
    init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Enqueue a new book import from the given EPUB file URL.
    /// - Parameter epubURL: The file URL of the EPUB file to import.
    func enqueueImport(from epubURL: URL) async throws -> NSManagedObjectID {
        // Create Book import record in Core Data
        let context = container.newBackgroundContext()
        let importBookID = try await context.perform {
            let book = Book(context: context)
            book.id = UUID()
            book.importFile = epubURL
            book.originalFileName = epubURL.lastPathComponent
            book.pendingDeletion = false
            let now = Date()
            book.timeQueued = now
            book.added = now
            book.displayProgressMessage = "Queued for import."
            try context.save()
            return book.objectID
        }
        queue.append(importBookID)
        processNextIfIdle()
        return importBookID
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the Book to cancel.
    func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true
            await context.perform {
                if let book = try? context.existingObject(with: jobID) as? Book {
                    book.isCancelled = true
                    book.timeCancelled = Date()
                    book.displayProgressMessage = "Import cancelled."
                    book.importFile = nil
                    try? context.save()
                }
            }
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the Book to wait for.
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

    /// Mark interrupted jobs as failed and clean any partially imported files.
    func cleanupInterruptedImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupInfos: [(UUID, String?, String?)] = await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == NO AND isCancelled == NO AND pendingDeletion == NO AND (errorMessage == nil OR errorMessage == '')")
            let books = (try? context.fetch(request)) ?? []
            guard !books.isEmpty else { return [] }

            var infos: [(UUID, String?, String?)] = []
            for book in books {
                book.isComplete = false
                book.isCancelled = false
                book.isStarted = false
                book.displayProgressMessage = "Import interrupted."
                book.errorMessage = "Import interrupted."
                book.importFile = nil

                let fileName = book.fileName
                let coverFileName = book.coverFileName
                book.fileName = nil
                book.coverFileName = nil
                book.fileCopied = false
                book.coverExtracted = false

                infos.append((book.id ?? UUID(), fileName, coverFileName))
            }

            try? context.save()
            return infos
        }

        guard !cleanupInfos.isEmpty else { return }
        logger.debug("Cleaning up \(cleanupInfos.count, privacy: .public) interrupted book imports")

        for (uuid, fileName, coverFileName) in cleanupInfos {
            Self.cleanupBookFilesByUUID(bookUUID: uuid, fileName: fileName, coverFileName: coverFileName)
        }
    }

    /// Clean up books that were marked for deletion but not yet removed.
    func cleanupPendingDeletions() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "pendingDeletion == YES")
            let books = (try? context.fetch(request)) ?? []
            return books.map(\.objectID)
        }

        guard !pendingIDs.isEmpty else { return }
        logger.debug("Cleaning up \(pendingIDs.count, privacy: .public) pending book deletions")

        for bookID in pendingIDs {
            do {
                try await deleteBookEntity(bookID: bookID)
            } catch {
                logger.error("Pending book deletion cleanup failed for \(bookID): \(error.localizedDescription)")
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
                guard let book = try? context.existingObject(with: jobID) as? Book else {
                    throw BookImportError.databaseError
                }
                book.isStarted = true
                book.timeStarted = Date()
                book.displayProgressMessage = "Starting import..."
                try context.save()
            }
            try Task.checkCancellation()
            try testErrorInjection?()

            let metadataTask = MetadataProcessingTask(bookID: jobID, container: container)
            try await metadataTask.start()
            logger.debug("Import job \(jobID) metadata processed")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let fileCopyTask = FileCopyTask(bookID: jobID, container: container)
            try await fileCopyTask.start()
            logger.debug("Import job \(jobID) file copied")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let coverExtractionTask = CoverExtractionTask(bookID: jobID, container: container)
            try await coverExtractionTask.start()
            logger.debug("Import job \(jobID) cover extracted")
            try Task.checkCancellation()
            try await testCancellationHook?()

            // Important: tasks run in their own contexts, so use a fresh context here to avoid stale relationships.
            let finalizeContext = container.newBackgroundContext()
            finalizeContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            finalizeContext.undoManager = nil

            try await finalizeContext.perform {
                guard let book = try? finalizeContext.existingObject(with: jobID) as? Book else {
                    throw BookImportError.databaseError
                }
                book.isComplete = true
                book.timeCompleted = Date()
                book.displayProgressMessage = "Import complete."
                book.errorMessage = nil
                book.importFile = nil

                try finalizeContext.save()
            }
        } catch is CancellationError {
            let cleanupContext = container.newBackgroundContext()
            cleanupContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            cleanupContext.undoManager = nil

            let cleanupInfo: (UUID, String?, String?)? = await cleanupContext.perform {
                guard let book = try? cleanupContext.existingObject(with: jobID) as? Book else {
                    return nil
                }
                book.isCancelled = true
                book.timeCancelled = Date()
                book.displayProgressMessage = "Import cancelled."
                book.importFile = nil

                let fileName = book.fileName
                let coverFileName = book.coverFileName
                book.fileName = nil
                book.coverFileName = nil
                book.fileCopied = false
                book.coverExtracted = false
                try? cleanupContext.save()
                return (book.id ?? UUID(), fileName, coverFileName)
            }

            if let (uuid, fileName, coverFileName) = cleanupInfo {
                Self.cleanupBookFilesByUUID(bookUUID: uuid, fileName: fileName, coverFileName: coverFileName)
            }
        } catch {
            let cleanupContext = container.newBackgroundContext()
            cleanupContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            cleanupContext.undoManager = nil

            let cleanupInfo: (UUID, String?, String?)? = await cleanupContext.perform {
                guard let book = try? cleanupContext.existingObject(with: jobID) as? Book else {
                    return nil
                }
                book.displayProgressMessage = error.localizedDescription
                book.errorMessage = error.localizedDescription
                book.importFile = nil
                let fileName = book.fileName
                let coverFileName = book.coverFileName
                book.fileName = nil
                book.coverFileName = nil
                book.fileCopied = false
                book.coverExtracted = false
                try? cleanupContext.save()
                return (book.id ?? UUID(), fileName, coverFileName)
            }

            if let (uuid, fileName, coverFileName) = cleanupInfo {
                Self.cleanupBookFilesByUUID(bookUUID: uuid, fileName: fileName, coverFileName: coverFileName)
            }
        }
    }

    /// Clean up book files (EPUB and cover) for a given book
    static func cleanupBookFiles(book: Book) {
        let fileManager = FileManager.default

        do {
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )

            // Clean up EPUB file
            if let fileName = book.fileName {
                let bookFile = appSupportDir.appendingPathComponent("Books").appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: bookFile.path) {
                    try? fileManager.removeItem(at: bookFile)
                }
            }

            // Clean up cover file
            if let coverFileName = book.coverFileName {
                let coverFile = appSupportDir.appendingPathComponent("Covers").appendingPathComponent(coverFileName)
                if fileManager.fileExists(atPath: coverFile.path) {
                    try? fileManager.removeItem(at: coverFile)
                }
            }
        } catch {}
    }

    /// Clean up book files by UUID
    static func cleanupBookFilesByUUID(bookUUID _: UUID, fileName: String?, coverFileName: String?) {
        let fileManager = FileManager.default

        do {
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )

            // Clean up EPUB file
            if let fileName {
                let bookFile = appSupportDir.appendingPathComponent("Books").appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: bookFile.path) {
                    try? fileManager.removeItem(at: bookFile)
                }
            }

            // Clean up cover file
            if let coverFileName {
                let coverFile = appSupportDir.appendingPathComponent("Covers").appendingPathComponent(coverFileName)
                if fileManager.fileExists(atPath: coverFile.path) {
                    try? fileManager.removeItem(at: coverFile)
                }
            }
        } catch {}
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

    /// Delete a book and all its associated data.
    /// - Parameter bookID: The NSManagedObjectID of the Book to delete.
    func deleteBook(bookID: NSManagedObjectID) async {
        logger.debug("Starting book deletion for \(bookID)")

        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        taskContext.undoManager = nil
        taskContext.shouldDeleteInaccessibleFaults = true

        do {
            try await taskContext.perform {
                guard let book = try? taskContext.existingObject(with: bookID) as? Book else {
                    throw BookImportError.databaseError
                }
                book.pendingDeletion = true
                book.displayProgressMessage = nil
                try taskContext.save()
            }
        } catch {
            logger.error("Failed to mark book for deletion \(bookID): \(error.localizedDescription)")
            return
        }

        Task {
            do {
                try await deleteBookEntity(bookID: bookID)
                logger.debug("Book deletion completed for \(bookID)")
            } catch {
                logger.error("Book deletion failed for \(bookID): \(error.localizedDescription)")
                await taskContext.perform {
                    guard let book = try? taskContext.existingObject(with: bookID) as? Book else {
                        return
                    }
                    book.pendingDeletion = false
                    try? taskContext.save()
                }
            }
        }
    }

    private func deleteBookEntity(bookID: NSManagedObjectID) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupInfo = try await context.perform {
            guard let book = try? context.existingObject(with: bookID) as? Book else {
                throw BookImportError.databaseError
            }

            let fileName = book.fileName
            let coverFileName = book.coverFileName
            let bookUUID = book.id ?? UUID()

            context.delete(book)
            try context.save()

            return (bookUUID, fileName, coverFileName)
        }

        Self.cleanupBookFilesByUUID(bookUUID: cleanupInfo.0, fileName: cleanupInfo.1, coverFileName: cleanupInfo.2)
    }
}
