// FileCopyTask.swift
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

        // Access security scoped resource if needed (returns false for in-sandbox files)
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
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
