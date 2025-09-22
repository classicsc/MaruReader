//
//  File.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//
import CoreData
import Foundation

extension DictionaryImportManager {
    private func copyMedia(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Walk workingDirectory, copy non-json files preserving structure
        // Destination: Application Support/Media/<dictionary-id>/
        // Create directory if needed
        // Update job.mediaImported

        let fileManager = FileManager.default
        guard let jobDirectory = job.workingDirectory else {
            throw DictionaryImportError.noWorkingDirectory
        }
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        guard let dictionaryID = dictionary.id else {
            throw DictionaryImportError.databaseError
        }
        let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Create media directory if it doesn't exist
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Recursively copy files
        let enumerator = fileManager.enumerator(at: jobDirectory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()
            // Skip JSON files
            if fileURL.pathExtension.lowercased() == "json" {
                continue
            }

            // Determine relative path
            let relativePath = fileURL.path.replacingOccurrences(of: jobDirectory.path, with: "")
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

        job.mediaImported = true
        job.displayProgressMessage = "Copied media files."
        try Task.checkCancellation()
        try context.save()
    }
}
