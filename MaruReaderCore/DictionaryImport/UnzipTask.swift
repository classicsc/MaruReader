//
//  UnzipTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log
internal import Zip

struct UnzipTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MaruReader", category: "UnzipTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer = DictionaryPersistenceController.shared.container) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() async throws {
        logger.debug("Starting unzip task for job \(self.jobID)")
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        let (jobURL, jobDirectory) = try await context.perform {
            guard let dictionary = try context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            guard let jobURL = dictionary.file else {
                throw DictionaryImportError.missingFile
            }
            guard let jobDirectory = dictionary.workingDirectory else {
                throw DictionaryImportError.noWorkingDirectory
            }

            // Update progress message
            dictionary.displayProgressMessage = "Extracting dictionary archive..."
            try context.save()
            return (jobURL, jobDirectory)
        }

        try Task.checkCancellation()

        guard jobURL.startAccessingSecurityScopedResource() else {
            throw DictionaryImportError.fileAccessDenied
        }

        defer {
            jobURL.stopAccessingSecurityScopedResource()
        }

        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw DictionaryImportError.missingFile
        }

        do {
            // Use Zip.unzipFile to extract the archive
            // This preserves directory structure automatically
            try Zip.unzipFile(jobURL, destination: jobDirectory, overwrite: true, password: nil)

        } catch let error as NSError {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        // Update job status to completed
        try await context.perform {
            guard let dictionary = try context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            dictionary.archiveExtracted = true
            dictionary.displayProgressMessage = "Extracted dictionary archive."
            try context.save()
        }
    }
}
