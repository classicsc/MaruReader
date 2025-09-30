//
//  BookImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

import CoreData
import Foundation
import os.log

actor BookImportManager {
    static let shared = BookImportManager(container: PersistenceController.shared.container)

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private var container: NSPersistentContainer
    private var logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    // Initializer for both shared instance and testing with custom container
    init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Enqueue a new book import from the given EPUB file URL.
    /// - Parameter epubURL: The file URL of the EPUB file to import.
    func enqueueImport(from epubURL: URL) async throws -> NSManagedObjectID {
        // Create BookEPUBImport in Core Data
        let context = container.newBackgroundContext()
        let importJob = try await context.perform {
            let job = BookEPUBImport(context: context)
            let jobID = UUID()
            job.id = jobID
            job.file = epubURL
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
    /// - Parameter jobID: The NSManagedObjectID of the BookEPUBImport to cancel.
    func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            await MainActor.run {
                let context = PersistenceController.shared.container.viewContext
                if let job = try? context.existingObject(with: jobID) as? BookEPUBImport {
                    job.isCancelled = true
                    job.timeCancelled = Date()
                    try? context.save()
                }
            }
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the BookEPUBImport to wait for.
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
                guard let job = try? context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.databaseError
                }
                job.isStarted = true
                job.timeStarted = Date()
                job.displayProgressMessage = "Starting import..."
                try context.save()
            }
            try Task.checkCancellation()
            try testErrorInjection?()

            let metadataTask = MetadataProcessingTask(jobID: jobID, container: container)
            await metadataTask.start()
            try await metadataTask.task?.value
            logger.debug("Import job \(jobID) metadata processed")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let fileCopyTask = FileCopyTask(jobID: jobID, container: container)
            await fileCopyTask.start()
            try await fileCopyTask.task?.value
            logger.debug("Import job \(jobID) file copied")
            try Task.checkCancellation()
            try await testCancellationHook?()

            let coverExtractionTask = CoverExtractionTask(jobID: jobID, container: container)
            await coverExtractionTask.start()
            try await coverExtractionTask.task?.value
            logger.debug("Import job \(jobID) cover extracted")
            try Task.checkCancellation()
            try await testCancellationHook?()

            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.databaseError
                }
                job.isComplete = true
                job.book?.isComplete = true
                job.timeCompleted = Date()
                job.displayProgressMessage = "Import complete."

                try context.save()
            }
        } catch is CancellationError {
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? BookEPUBImport else {
                    return
                }
                job.isCancelled = true
                job.timeCancelled = Date()
                if let book = job.book {
                    context.delete(book)
                    Self.cleanupBookFiles(book: book)
                }
                try? context.save()
            }
        } catch {
            await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? BookEPUBImport else {
                    return
                }
                job.displayProgressMessage = error.localizedDescription
                if let book = job.book {
                    book.errorMessage = error.localizedDescription
                    context.delete(book)
                    Self.cleanupBookFiles(book: book)
                }
                try? context.save()
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

        let context = container.newBackgroundContext()
        do {
            try await context.perform {
                guard let book = try? context.existingObject(with: bookID) as? Book else {
                    throw BookImportError.databaseError
                }

                // Get file names before deletion
                let fileName = book.fileName
                let coverFileName = book.coverFileName
                let bookUUID = book.id

                // Delete the book entity
                context.delete(book)
                try context.save()

                // Clean up files
                if let uuid = bookUUID {
                    Self.cleanupBookFilesByUUID(bookUUID: uuid, fileName: fileName, coverFileName: coverFileName)
                }
            }

            logger.debug("Book deletion completed for \(bookID)")
        } catch {
            logger.error("Book deletion failed for \(bookID): \(error.localizedDescription)")
        }
    }
}
