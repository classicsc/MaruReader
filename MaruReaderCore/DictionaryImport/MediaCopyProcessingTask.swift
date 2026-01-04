//
//  MediaCopyProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

/// A task to copy media files from the working directory to the permanent media directory.
struct MediaCopyProcessingTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "MediaCopyProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        // Get job information from Core Data
        let (workingDirectory, dictionaryID): (URL, UUID) = try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            guard let workingDirectory = dictionary.workingDirectory else {
                throw DictionaryImportError.noWorkingDirectory
            }
            guard let dictionaryID = dictionary.id else {
                throw DictionaryImportError.databaseError
            }

            // Update progress message
            dictionary.displayProgressMessage = "Copying media files..."
            try context.save()

            return (workingDirectory, dictionaryID)
        }

        try Task.checkCancellation()

        // Setup media directory path
        let fileManager = FileManager.default

        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            throw DictionaryImportError.mediaDirectoryCreationFailed
        }
        let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Create media directory if it doesn't exist
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Recursively copy files
        let enumerator = fileManager.enumerator(at: workingDirectory, includingPropertiesForKeys: nil)
        let resolvedWorkingPath = workingDirectory.resolvingSymlinksInPath().path
        while let fileURL = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()

            // Skip JSON files
            if fileURL.pathExtension.lowercased() == "json" {
                continue
            }

            // Skip directories; enumerator can walk them but we only copy files
            if fileURL.hasDirectoryPath {
                continue
            }

            // Determine relative path
            let resolvedFilePath = fileURL.resolvingSymlinksInPath().path

            guard resolvedFilePath.hasPrefix(resolvedWorkingPath) else {
                MediaCopyProcessingTask.logger.error("File path \(resolvedFilePath, privacy: .public) outside working directory \(resolvedWorkingPath, privacy: .public)")
                continue
            }

            var relativePath = String(resolvedFilePath.dropFirst(resolvedWorkingPath.count))
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }

            let destinationURL = mediaDir.appendingPathComponent(relativePath)
            let destinationDir = destinationURL.deletingLastPathComponent()

            // Create destination directory if needed
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
            }

            // Copy file
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: fileURL, to: destinationURL)
            MediaCopyProcessingTask.logger.debug("Copied media file to \(destinationURL.path, privacy: .public)")
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
