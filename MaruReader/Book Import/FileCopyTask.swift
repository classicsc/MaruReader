//
//  FileCopyTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

import CoreData
import Foundation
import MaruReaderCore
import os.log

actor FileCopyTask {
    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer = PersistenceController.shared.container) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() {
        let container = persistentContainer
        let jobID = self.jobID
        task = Task {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            let (fileURL, bookID) = try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }
                guard let fileURL = job.file else {
                    throw BookImportError.missingFile
                }
                guard let book = job.book, let bookID = book.id else {
                    throw BookImportError.bookCreationFailed
                }

                // Update progress message
                job.displayProgressMessage = "Copying book file..."
                try context.save()
                return (fileURL, bookID)
            }

            try Task.checkCancellation()

            // Access security scoped resource
            guard fileURL.startAccessingSecurityScopedResource() else {
                throw BookImportError.fileAccessDenied
            }

            defer {
                fileURL.stopAccessingSecurityScopedResource()
            }

            // Check if file exists and is accessible
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw BookImportError.missingFile
            }

            // Get application support directory
            let appSupportDir: URL
            do {
                appSupportDir = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            } catch {
                throw BookImportError.fileCopyFailed(underlyingError: error)
            }

            // Create Books directory if needed
            let booksDir = appSupportDir.appendingPathComponent("Books")
            do {
                try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
            } catch {
                throw BookImportError.fileCopyFailed(underlyingError: error)
            }

            // Determine file extension
            let fileExtension = fileURL.pathExtension
            let destinationFileName = "\(bookID.uuidString).\(fileExtension)"
            let destinationURL = booksDir.appendingPathComponent(destinationFileName)

            // Copy file
            do {
                // Remove destination if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            } catch {
                throw BookImportError.fileCopyFailed(underlyingError: error)
            }

            try Task.checkCancellation()

            // Update Book entity with file name
            try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }
                guard let book = job.book else {
                    throw BookImportError.bookCreationFailed
                }

                book.fileName = destinationFileName
                job.fileCopied = true
                job.displayProgressMessage = "Book file copied."

                try context.save()
            }
        }
    }
}
