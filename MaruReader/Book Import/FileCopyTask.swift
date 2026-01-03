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

struct FileCopyTask {
    let bookID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    init(bookID: NSManagedObjectID, container: NSPersistentContainer = BookDataPersistenceController.shared.container) {
        self.bookID = bookID
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let bookID = self.bookID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (fileURL, bookUUID) = try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }
            guard let fileURL = book.importFile else {
                throw BookImportError.missingFile
            }
            guard let bookUUID = book.id else {
                throw BookImportError.bookCreationFailed
            }

            // Update progress message
            book.displayProgressMessage = "Copying book file..."
            try context.save()
            return (fileURL, bookUUID)
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
        let destinationFileName = "\(bookUUID.uuidString).\(fileExtension)"
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
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }

            book.fileName = destinationFileName
            book.fileCopied = true
            book.displayProgressMessage = "Book file copied."

            try context.save()
        }
    }
}
