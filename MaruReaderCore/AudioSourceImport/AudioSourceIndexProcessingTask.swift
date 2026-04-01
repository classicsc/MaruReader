// AudioSourceIndexProcessingTask.swift
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

internal import ReadiumZIPFoundation
import CoreData
import Foundation
import os

struct AudioSourceIndexResult {
    let sourceID: UUID
    let indexURL: URL
    let indexEntryPath: String
    let archiveURL: URL
    let isLocal: Bool
}

/// A task to process the audio source index JSON and create the AudioSource entity.
struct AudioSourceIndexProcessingTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger.maru(category: "AudioSourceIndexProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    /// Process the index and create the AudioSource entity.
    /// - Returns: Audio source metadata for use by subsequent tasks.
    func start() async throws -> AudioSourceIndexResult {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let jobURL = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            guard let jobURL = job.file else {
                throw AudioSourceImportError.missingFile
            }

            job.displayProgressMessage = FrameworkLocalization.string("Processing audio source index...")
            try context.save()
            return jobURL
        }

        // Access security scoped resource if needed (returns false for in-sandbox files)
        let didStartAccess = jobURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                jobURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw AudioSourceImportError.missingFile
        }

        let archive: Archive
        do {
            archive = try await Archive(url: jobURL, accessMode: .read)
        } catch {
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }

        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }
        let indexEntry = try findIndexEntry(in: entries)
        let indexEntryPath = indexEntry.path

        let indexURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        var shouldCleanupIndex = true
        defer {
            if shouldCleanupIndex {
                try? FileManager.default.removeItem(at: indexURL)
            }
        }
        do {
            _ = try await archive.extract(indexEntry, to: indexURL, skipCRC32: false)
        } catch {
            throw AudioSourceImportError.unzipFailed(underlyingError: error)
        }
        logger.debug("Found index file at \(indexEntryPath)")

        try Task.checkCancellation()

        // Parse the meta section
        let meta = try AudioSourceMetaParser.parse(from: indexURL)

        // Determine if this is a local or online source
        let isLocal = meta.mediaDirAbs == nil

        // Detect file extensions from the files section (we'll scan a sample)
        let fileExtensions = try detectFileExtensions(from: indexURL)

        let sourceID = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }

            if job.id == nil {
                job.id = UUID()
            }
            job.name = meta.name
            job.attribution = meta.attribution
            job.year = Int64(meta.year ?? 0)
            job.version = Int64(meta.version ?? 0)
            job.isLocal = isLocal
            job.baseRemoteURL = meta.mediaDirAbs
            job.indexedByHeadword = true
            job.enabled = true
            job.audioFileExtensions = fileExtensions.joined(separator: ",")
            job.indexProcessed = true
            job.displayProgressMessage = FrameworkLocalization.string("Processed audio source index.")

            try context.save()
            guard let id = job.id else {
                throw AudioSourceImportError.databaseError
            }
            return id
        }

        shouldCleanupIndex = false
        return AudioSourceIndexResult(
            sourceID: sourceID,
            indexURL: indexURL,
            indexEntryPath: indexEntryPath,
            archiveURL: jobURL,
            isLocal: isLocal
        )
    }

    /// Find the index JSON entry in an archive.
    /// For local sources: must be named "index.json"
    /// For online sources: any single JSON file at root level
    private func findIndexEntry(in entries: [Entry]) throws -> Entry {
        let fileEntries = entries.filter { $0.type == .file }
        let rootEntries = fileEntries.filter { !$0.path.contains("/") }

        if let indexEntry = rootEntries.first(where: { $0.path == "index.json" }) {
            return indexEntry
        }

        if let nestedIndex = fileEntries.first(where: { entry in
            entry.path.hasSuffix("/index.json") && entry.path.split(separator: "/").count == 2
        }) {
            return nestedIndex
        }

        let jsonFiles = rootEntries.filter { $0.path.lowercased().hasSuffix(".json") }
        if jsonFiles.count == 1, let entry = jsonFiles.first {
            return entry
        }

        throw AudioSourceImportError.notAnAudioSource
    }

    /// Detect unique file extensions from the files section.
    /// Decodes just the file names to extract extensions without loading all file info.
    private func detectFileExtensions(from indexURL: URL) throws -> Set<String> {
        var extensions: Set<String> = []

        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()

        // Decode just the files keys to get extensions
        struct FilesOnly: Codable {
            let files: [String: AudioFileInfo]
        }

        if let filesOnly = try? decoder.decode(FilesOnly.self, from: data) {
            for filename in filesOnly.files.keys {
                let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                if !ext.isEmpty {
                    extensions.insert(ext)
                }
            }
        }

        return extensions
    }
}
