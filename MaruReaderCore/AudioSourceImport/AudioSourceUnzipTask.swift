// AudioSourceUnzipTask.swift
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
internal import Zip

/// A task to extract an audio source ZIP archive to a working directory.
struct AudioSourceUnzipTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioSourceUnzipTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() async throws {
        logger.debug("Starting unzip task for audio source job \(self.jobID)")
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (jobURL, jobDirectory) = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            guard let jobURL = job.file else {
                throw AudioSourceImportError.missingFile
            }
            guard let jobDirectory = job.workingDirectory else {
                throw AudioSourceImportError.noWorkingDirectory
            }

            job.displayProgressMessage = "Extracting audio source archive..."
            try context.save()
            return (jobURL, jobDirectory)
        }

        try Task.checkCancellation()

        guard jobURL.startAccessingSecurityScopedResource() else {
            throw AudioSourceImportError.fileAccessDenied
        }

        defer {
            jobURL.stopAccessingSecurityScopedResource()
        }

        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw AudioSourceImportError.missingFile
        }

        do {
            try Zip.unzipFile(jobURL, destination: jobDirectory, overwrite: true, password: nil)
        } catch let error as NSError {
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            job.archiveExtracted = true
            job.displayProgressMessage = "Extracted audio source archive."
            try context.save()
        }
    }
}
