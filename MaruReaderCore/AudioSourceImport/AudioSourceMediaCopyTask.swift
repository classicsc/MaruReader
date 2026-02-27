// AudioSourceMediaCopyTask.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import os
internal import ReadiumZIPFoundation

/// A task to copy audio files from the archive to the app group container.
/// This task only runs for local audio sources (isLocal = true).
struct AudioSourceMediaCopyTask {
    let jobID: NSManagedObjectID
    let sourceID: UUID
    let indexURL: URL
    let archiveURL: URL
    let indexEntryPath: String
    let persistentContainer: NSPersistentContainer
    let baseDirectory: URL?
    private static let logger = Logger.maru(category: "AudioSourceMediaCopyTask")

    init(
        jobID: NSManagedObjectID,
        sourceID: UUID,
        indexURL: URL,
        archiveURL: URL,
        indexEntryPath: String,
        container: NSPersistentContainer,
        baseDirectory: URL? = nil
    ) {
        self.jobID = jobID
        self.sourceID = sourceID
        self.indexURL = indexURL
        self.archiveURL = archiveURL
        self.indexEntryPath = indexEntryPath
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

        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            job.displayProgressMessage = "Copying audio files..."
            try context.save()
        }

        try Task.checkCancellation()

        // Parse meta to get media_dir
        let meta = try AudioSourceMetaParser.parse(from: indexURL)
        let mediaDir = meta.mediaDir ?? "media"
        let basePath = (indexEntryPath as NSString).deletingLastPathComponent
        let mediaPrefix = basePath.isEmpty ? mediaDir : "\(basePath)/\(mediaDir)"
        let mediaPrefixWithSlash = mediaPrefix.hasSuffix("/") ? mediaPrefix : "\(mediaPrefix)/"

        // Setup destination directory
        let fileManager = FileManager.default

        guard let baseDir = baseDirectory else {
            throw AudioSourceImportError.mediaDirectoryCreationFailed
        }

        let destMediaDir = baseDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)

        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destMediaDir.path) {
            try fileManager.createDirectory(at: destMediaDir, withIntermediateDirectories: true, attributes: nil)
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
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }

        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }
        var filesCopied = 0

        for entry in entries where entry.type == .file {
            try Task.checkCancellation()

            guard entry.path.hasPrefix(mediaPrefixWithSlash) else { continue }
            let relativePath = String(entry.path.dropFirst(mediaPrefixWithSlash.count))
            guard !relativePath.isEmpty else { continue }

            let destinationURL = destMediaDir.appendingPathComponent(relativePath)
            guard destinationURL.isContained(in: destMediaDir) else {
                Self.logger.error("File path \(relativePath, privacy: .public) outside destination directory")
                continue
            }

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                _ = try await archive.extract(entry, to: destinationURL, skipCRC32: false)
                filesCopied += 1
            } catch {
                throw AudioSourceImportError.unzipFailed(underlyingError: error)
            }

            if filesCopied % 1000 == 0 {
                Self.logger.debug("Copied \(filesCopied) audio files...")
            }
        }

        if filesCopied == 0 {
            Self.logger.warning("Media entries not found for prefix \(mediaPrefixWithSlash, privacy: .public)")
        }

        Self.logger.info("Copied \(filesCopied) audio files to \(destMediaDir.path)")

        try Task.checkCancellation()

        let totalFilesCopied = filesCopied
        let progressMessage = totalFilesCopied == 0 ? String(localized: "No media files to copy.") : String(localized: "Copied \(totalFilesCopied) audio files.")
        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            job.mediaImported = true
            job.displayProgressMessage = progressMessage
            try context.save()
        }
    }

    /// Clean up the media directory for a given audio source.
    /// - Parameters:
    ///   - sourceID: The UUID of the audio source.
    ///   - baseDirectory: The base directory containing AudioMedia. If nil, uses the app group container.
    static func cleanMediaDirectory(sourceID: UUID, baseDirectory: URL? = nil) {
        let fileManager = FileManager.default

        guard let baseDir = baseDirectory ?? fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return
        }

        let mediaDir = baseDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)

        if fileManager.fileExists(atPath: mediaDir.path) {
            do {
                try fileManager.removeItem(at: mediaDir)
            } catch {
                logger.error("Failed to clean media directory: \(error.localizedDescription)")
            }
        }
    }
}
