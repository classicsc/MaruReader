//
//  UnzipTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import Zip

struct UnzipTask {
    private let jobID: NSManagedObjectID
    private let task: Task<Void, Error>? = nil

    init(jobID: NSManagedObjectID) {
        self.jobID = jobID
    }

    func start() {
        Task {
            try await unzip()
        }
    }

    func waitUntilFinished() async throws {
        try await task?.value
    }

    private func unzip() async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        let (jobURL, jobDirectory) = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.importNotFound
            }
            guard let jobURL = job.file else {
                throw DictionaryImportError.missingFile
            }
            guard let jobDirectory = job.workingDirectory else {
                throw DictionaryImportError.noWorkingDirectory
            }

            // Update progress message
            job.displayProgressMessage = "Extracting dictionary archive..."
            try context.save()
            return (jobURL, jobDirectory)
        }

        try Task.checkCancellation()

        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw DictionaryImportError.missingFile
        }

        guard jobURL.startAccessingSecurityScopedResource() else {
            throw DictionaryImportError.fileAccessDenied
        }

        defer {
            jobURL.stopAccessingSecurityScopedResource()
        }

        do {
            // Use Zip.unzipFile to extract the archive
            // This preserves directory structure automatically
            try Zip.unzipFile(jobURL, destination: jobDirectory, overwrite: true, password: nil)

            _ = try FileManager.default.contentsOfDirectory(at: jobDirectory, includingPropertiesForKeys: nil)

        } catch let error as NSError {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        // Update job status to completed
        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                throw DictionaryImportError.importNotFound
            }
            job.archiveExtracted = true
            job.displayProgressMessage = "Extracted dictionary archive."
            try context.save()
        }
    }
}
