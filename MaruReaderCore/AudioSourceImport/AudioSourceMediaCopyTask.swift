//
//  AudioSourceMediaCopyTask.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import CoreData
import Foundation
import os.log

/// A task to copy audio files from the working directory to the app group container.
/// This task only runs for local audio sources (isLocal = true).
struct AudioSourceMediaCopyTask {
    let jobID: NSManagedObjectID
    let sourceID: UUID
    let indexURL: URL
    let persistentContainer: NSPersistentContainer
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioSourceMediaCopyTask")

    init(jobID: NSManagedObjectID, sourceID: UUID, indexURL: URL, container: NSPersistentContainer) {
        self.jobID = jobID
        self.sourceID = sourceID
        self.indexURL = indexURL
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let workingDirectory = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSourceImport else {
                throw AudioSourceImportError.importNotFound
            }
            guard let workingDirectory = job.workingDirectory else {
                throw AudioSourceImportError.noWorkingDirectory
            }

            job.displayProgressMessage = "Copying audio files..."
            try context.save()
            return workingDirectory
        }

        try Task.checkCancellation()

        // Parse meta to get media_dir
        let meta = try AudioSourceMetaParser.parse(from: indexURL)
        let mediaDir = meta.mediaDir ?? "media"
        let sourceMediaDir = workingDirectory.appendingPathComponent(mediaDir)

        // Setup destination directory in app group
        let fileManager = FileManager.default

        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            throw AudioSourceImportError.mediaDirectoryCreationFailed
        }

        let destMediaDir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)

        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destMediaDir.path) {
            try fileManager.createDirectory(at: destMediaDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Check if source media directory exists
        guard fileManager.fileExists(atPath: sourceMediaDir.path) else {
            Self.logger.warning("Media directory not found at \(sourceMediaDir.path), skipping media copy")
            // Mark as complete even if no media to copy
            try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? AudioSourceImport else {
                    throw AudioSourceImportError.importNotFound
                }
                job.mediaImported = true
                job.displayProgressMessage = "No media files to copy."
                try context.save()
            }
            return
        }

        // Copy files recursively
        let resolvedSourcePath = sourceMediaDir.resolvingSymlinksInPath().path
        let enumerator = fileManager.enumerator(at: sourceMediaDir, includingPropertiesForKeys: nil)
        var filesCopied = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()

            // Skip directories
            if fileURL.hasDirectoryPath {
                continue
            }

            // Determine relative path
            let resolvedFilePath = fileURL.resolvingSymlinksInPath().path

            guard resolvedFilePath.hasPrefix(resolvedSourcePath) else {
                Self.logger.error("File path \(resolvedFilePath, privacy: .public) outside source directory")
                continue
            }

            var relativePath = String(resolvedFilePath.dropFirst(resolvedSourcePath.count))
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }

            let destinationURL = destMediaDir.appendingPathComponent(relativePath)
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
            filesCopied += 1

            if filesCopied % 1000 == 0 {
                Self.logger.debug("Copied \(filesCopied) audio files...")
            }
        }

        Self.logger.info("Copied \(filesCopied) audio files to \(destMediaDir.path)")

        try Task.checkCancellation()

        let totalFilesCopied = filesCopied
        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSourceImport else {
                throw AudioSourceImportError.importNotFound
            }
            job.mediaImported = true
            job.displayProgressMessage = "Copied \(totalFilesCopied) audio files."
            try context.save()
        }
    }

    /// Clean up the media directory for a given audio source.
    static func cleanMediaDirectory(sourceID: UUID) {
        let fileManager = FileManager.default

        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return
        }

        let mediaDir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)

        if fileManager.fileExists(atPath: mediaDir.path) {
            do {
                try fileManager.removeItem(at: mediaDir)
            } catch {
                logger.error("Failed to clean media directory: \(error.localizedDescription)")
            }
        }
    }
}
