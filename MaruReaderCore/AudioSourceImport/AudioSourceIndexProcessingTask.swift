//
//  AudioSourceIndexProcessingTask.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import CoreData
import Foundation
import os.log

/// A task to process the audio source index JSON and create the AudioSource entity.
struct AudioSourceIndexProcessingTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioSourceIndexProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    /// Process the index and create the AudioSource entity.
    /// - Returns: A tuple of (sourceID, indexURL, isLocal) for use by subsequent tasks.
    func start() async throws -> (sourceID: UUID, indexURL: URL, isLocal: Bool) {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let workingDir = try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSourceImport else {
                throw AudioSourceImportError.importNotFound
            }
            guard let workingDir = job.workingDirectory else {
                throw AudioSourceImportError.noWorkingDirectory
            }

            job.displayProgressMessage = "Processing audio source index..."
            try context.save()
            return workingDir
        }

        // Find the index JSON file
        let indexURL = try findIndexFile(in: workingDir)
        logger.debug("Found index file at \(indexURL.path)")

        try Task.checkCancellation()

        // Parse the meta section
        let meta = try AudioSourceMetaParser.parse(from: indexURL)

        // Determine if this is a local or online source
        let isLocal = meta.mediaDirAbs == nil

        // Detect file extensions from the files section (we'll scan a sample)
        let fileExtensions = try detectFileExtensions(from: indexURL)

        let sourceID = UUID()

        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSourceImport else {
                throw AudioSourceImportError.importNotFound
            }

            // Create the AudioSource entity
            let audioSource = AudioSource(context: context)
            audioSource.id = sourceID
            audioSource.name = meta.name
            audioSource.year = Int64(meta.year ?? 0)
            audioSource.version = Int64(meta.version ?? 0)
            audioSource.isLocal = isLocal
            audioSource.baseRemoteURL = meta.mediaDirAbs
            audioSource.indexedByHeadword = true
            audioSource.enabled = true
            audioSource.dateAdded = Date()
            audioSource.audioFileExtensions = fileExtensions.joined(separator: ",")
            audioSource.priority = try Self.getNextPriority(in: context)

            context.insert(audioSource)

            job.audioSource = audioSource
            job.indexProcessed = true
            job.displayProgressMessage = "Processed audio source index."

            try context.save()
        }

        return (sourceID, indexURL, isLocal)
    }

    /// Find the index JSON file in the working directory.
    /// For local sources: must be named "index.json"
    /// For online sources: any single JSON file at root level
    private func findIndexFile(in workingDir: URL) throws -> URL {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: nil)

        // First, check for index.json (required for local sources)
        let indexJSON = workingDir.appendingPathComponent("index.json")
        if fileManager.fileExists(atPath: indexJSON.path) {
            return indexJSON
        }

        // For online sources, find any JSON file at root level
        let jsonFiles = contents.filter { $0.pathExtension.lowercased() == "json" }

        if jsonFiles.count == 1 {
            return jsonFiles[0]
        } else if jsonFiles.isEmpty {
            throw AudioSourceImportError.notAnAudioSource
        } else {
            // Multiple JSON files without an index.json - ambiguous
            throw AudioSourceImportError.notAnAudioSource
        }
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

    /// Get the next available priority value for audio sources.
    private static func getNextPriority(in context: NSManagedObjectContext) throws -> Int64 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioSource")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]
        fetchRequest.fetchLimit = 1

        if let results = try context.fetch(fetchRequest) as? [NSManagedObject],
           let maxSource = results.first,
           let maxPriority = maxSource.value(forKey: "priority") as? Int64
        {
            return maxPriority + 1
        }
        return 0
    }
}
