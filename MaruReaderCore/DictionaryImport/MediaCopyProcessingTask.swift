// MediaCopyProcessingTask.swift
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
internal import ReadiumZIPFoundation

/// A task to copy media files from the archive to the permanent media directory.
struct MediaCopyProcessingTask {
    let jobID: NSManagedObjectID
    let archiveURL: URL
    let persistentContainer: NSPersistentContainer
    let baseDirectory: URL?
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "MediaCopyProcessingTask")

    init(jobID: NSManagedObjectID, archiveURL: URL, container: NSPersistentContainer, baseDirectory: URL? = nil) {
        self.jobID = jobID
        self.archiveURL = archiveURL
        self.persistentContainer = container
        self.baseDirectory = baseDirectory ?? FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        // Get job information from Core Data
        let dictionaryID: UUID = try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            guard let dictionaryID = dictionary.id else {
                throw DictionaryImportError.databaseError
            }

            // Update progress message
            dictionary.displayProgressMessage = "Copying media files..."
            try context.save()

            return dictionaryID
        }

        try Task.checkCancellation()

        // Setup media directory path
        let fileManager = FileManager.default

        guard let baseDir = baseDirectory else {
            throw DictionaryImportError.mediaDirectoryCreationFailed
        }
        let mediaDir = baseDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Create media directory if it doesn't exist
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Access security scoped resource if needed (returns false for in-sandbox files)
        let didStartAccess = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        let archive: Archive
        do {
            archive = try await Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
        for entry in entries where entry.type == .file {
            try Task.checkCancellation()

            let path = entry.path
            if path.lowercased().hasSuffix(".json") {
                continue
            }

            let destinationURL = mediaDir.appendingPathComponent(path)
            guard destinationURL.isContained(in: mediaDir) else {
                MediaCopyProcessingTask.logger.error("Skipped media path outside destination: \(path, privacy: .public)")
                continue
            }
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                _ = try await archive.extract(entry, to: destinationURL, skipCRC32: true)
                MediaCopyProcessingTask.logger.debug("Copied media file to \(destinationURL.path, privacy: .public)")
            } catch {
                throw DictionaryImportError.unzipFailed(underlyingError: error)
            }
        }

        try Task.checkCancellation()

        // Mark media as imported in Core Data
        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.mediaImported = true
            dictionary.displayProgressMessage = "Copied media files."
            try context.save()
        }
    }
}
