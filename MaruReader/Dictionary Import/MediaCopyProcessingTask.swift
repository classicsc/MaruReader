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
actor MediaCopyProcessingTask {
    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "MediaCopyProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
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

            // Get job information from Core Data
            let (workingDirectory, dictionaryID): (URL, UUID) = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                guard let workingDirectory = job.workingDirectory else {
                    throw DictionaryImportError.noWorkingDirectory
                }
                guard let dictionary = job.dictionary else {
                    throw DictionaryImportError.databaseError
                }
                guard let dictionaryID = dictionary.id else {
                    throw DictionaryImportError.databaseError
                }

                // Update progress message
                job.displayProgressMessage = "Copying media files..."
                try context.save()

                return (workingDirectory, dictionaryID)
            }

            try Task.checkCancellation()

            // Setup media directory path
            let fileManager = FileManager.default

            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

            // Create media directory if it doesn't exist
            if !fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true, attributes: nil)
            }

            // Recursively copy files
            let enumerator = fileManager.enumerator(at: workingDirectory, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                try Task.checkCancellation()

                // Skip JSON files
                if fileURL.pathExtension.lowercased() == "json" {
                    continue
                }

                // Determine relative path
                let relativePath = fileURL.path.replacingOccurrences(of: workingDirectory.path, with: "")
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
            }

            try Task.checkCancellation()

            // Mark media as imported in Core Data
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.mediaImported = true
                job.displayProgressMessage = "Copied media files."
                try context.save()
            }
        }
    }
}
