// MangaImportManager.swift
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
internal import ReadiumZIPFoundation
import UIKit

public actor MangaImportManager {
    public static let shared = MangaImportManager(container: MangaDataPersistenceController.shared.container)
    public static var isMetadataExtractorAvailable: Bool {
        MangaFilenameMetadataExtractor.isModelAvailable
    }

    private var queue: [NSManagedObjectID] = []
    private var currentTask: Task<Void, Never>?
    private var currentJobID: NSManagedObjectID?
    private let container: NSPersistentContainer
    private let metadataExtractor = MangaFilenameMetadataExtractor()
    private let logger = Logger(subsystem: "net.undefinedstar.MaruManga", category: "MangaImport")

    // Supported image extensions
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp"]

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    // Initializer for both shared instance and testing with custom container
    public init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - Public API

    /// Prewarm the metadata extractor model
    public func prewarmMetadataExtractor() {
        guard shouldUseSmartMetadataExtraction else {
            return
        }
        metadataExtractor.prewarm()
    }

    /// Enqueue a new manga archive import from the given file URL.
    /// - Parameter archiveURL: The file URL of the ZIP/CBZ archive to import.
    /// - Returns: The NSManagedObjectID of the created MangaArchive entity.
    public func enqueueImport(from archiveURL: URL) async throws -> NSManagedObjectID {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let importMangaID = try await context.perform {
            let manga = MangaArchive(context: context)
            manga.id = UUID()
            manga.importFile = archiveURL
            manga.title = archiveURL.deletingPathExtension().lastPathComponent
            manga.originalFileName = archiveURL.lastPathComponent
            manga.dateAdded = Date()
            manga.importComplete = false
            try context.save()
            return manga.objectID
        }
        queue.append(importMangaID)
        processNextIfIdle()
        return importMangaID
    }

    /// Cancel an ongoing or queued import job.
    /// - Parameter jobID: The NSManagedObjectID of the MangaArchive to cancel.
    public func cancelImport(jobID: NSManagedObjectID) async {
        if currentJobID == jobID {
            currentTask?.cancel()
        } else {
            queue.removeAll { $0 == jobID }
            // Also mark as cancelled in Core Data
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true
            await context.perform {
                if let manga = try? context.existingObject(with: jobID) as? MangaArchive {
                    manga.importErrorMessage = "Import cancelled."
                    manga.importFile = nil
                    try? context.save()
                }
            }
        }
    }

    /// Wait for a given import job to complete.
    /// - Parameter jobID: The NSManagedObjectID of the MangaArchive to wait for.
    public func waitForCompletion(jobID: NSManagedObjectID) async {
        while true {
            if currentJobID == jobID {
                await currentTask?.value
                return
            } else if !queue.contains(jobID) {
                return
            } else {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    /// Delete a manga and its associated files.
    /// - Parameter mangaID: The NSManagedObjectID of the MangaArchive to delete.
    public func deleteManga(mangaID: NSManagedObjectID) async {
        logger.debug("Starting manga deletion for \(mangaID)")

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        do {
            try await context.perform {
                guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                    throw MangaImportError.databaseError
                }

                let localPath = manga.localPath
                let coverImage = manga.coverImage

                context.delete(manga)
                try context.save()

                Self.cleanupMangaFiles(localPath: localPath, coverImage: coverImage)
            }

            logger.debug("Manga deletion completed for \(mangaID)")
        } catch {
            logger.error("Manga deletion failed for \(mangaID): \(error.localizedDescription)")
        }
    }

    // MARK: - Test Helper Methods

    /// Set test cancellation hook for controlled testing
    public func setTestCancellationHook(_ hook: (() async throws -> Void)?) {
        testCancellationHook = hook
    }

    /// Set test error injection for controlled testing
    public func setTestErrorInjection(_ injection: (() throws -> Void)?) {
        testErrorInjection = injection
    }

    // MARK: - Private Implementation

    private func processNextIfIdle() {
        guard currentTask == nil, let nextJob = queue.first else { return }

        currentTask = Task {
            await runImport(for: nextJob)
            queue.removeFirst()
            currentTask = nil
            currentJobID = nil
            processNextIfIdle()
        }
        currentJobID = nextJob
    }

    private func runImport(for jobID: NSManagedObjectID) async {
        logger.debug("Starting manga import job \(jobID)")

        do {
            // Get the import file URL
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            let importInfo: (URL, UUID, String) = try await context.perform {
                guard let manga = try? context.existingObject(with: jobID) as? MangaArchive else {
                    throw MangaImportError.archiveNotFound
                }
                guard let importFile = manga.importFile else {
                    throw MangaImportError.missingFile
                }
                guard let mangaID = manga.id else {
                    throw MangaImportError.databaseError
                }
                let fileExtension = importFile.pathExtension.isEmpty ? "cbz" : importFile.pathExtension
                return (importFile, mangaID, fileExtension)
            }

            let (importFile, mangaUUID, fileExtension) = importInfo

            try Task.checkCancellation()
            try testErrorInjection?()

            // Access security-scoped resource if needed
            let didStartAccess = importFile.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    importFile.stopAccessingSecurityScopedResource()
                }
            }

            // Validate the archive and count images
            guard FileManager.default.fileExists(atPath: importFile.path) else {
                throw MangaImportError.missingFile
            }

            let archive: Archive
            do {
                archive = try await Archive(url: importFile, accessMode: .read)
            } catch {
                throw MangaImportError.invalidArchive
            }

            let entries = try await archive.entries()
            let imageEntries = sortedImageEntries(entries)

            guard !imageEntries.isEmpty else {
                throw MangaImportError.noImagesFound
            }

            let totalPages = imageEntries.count
            let coverEntry = imageEntries[0]
            let shouldUseSmartMetadata = shouldUseSmartMetadataExtraction
            async let extractedMetadata = metadataExtractor.extractMetadata(
                from: importFile.lastPathComponent,
                useSmartExtraction: shouldUseSmartMetadata
            )

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Copy archive to Documents/Manga/
            let mangaDir = try mangaDirectory()
            let destinationFileName = "\(mangaUUID.uuidString).\(fileExtension)"
            let destinationURL = mangaDir.appendingPathComponent(destinationFileName)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: importFile, to: destinationURL)
            } catch {
                throw MangaImportError.fileCopyFailed(underlyingError: error)
            }

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Extract cover to Application Support/Covers/
            let coversDir = try coversDirectory()
            let coverFileName = "\(mangaUUID.uuidString).png"
            let coverURL = coversDir.appendingPathComponent(coverFileName)

            do {
                try await extractCover(from: archive, entry: coverEntry, to: coverURL)
            } catch {
                // Clean up copied archive on cover extraction failure
                try? FileManager.default.removeItem(at: destinationURL)
                throw MangaImportError.coverExtractionFailed(underlyingError: error)
            }

            let metadata = await extractedMetadata
            let authorValue = metadata.author.trimmingCharacters(in: .whitespacesAndNewlines)

            try Task.checkCancellation()
            try await testCancellationHook?()

            // Update the MangaArchive entity
            let finalizeContext = container.newBackgroundContext()
            finalizeContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            finalizeContext.undoManager = nil

            try await finalizeContext.perform {
                guard let manga = try? finalizeContext.existingObject(with: jobID) as? MangaArchive else {
                    throw MangaImportError.databaseError
                }
                manga.localFileName = destinationFileName
                manga.coverFileName = coverFileName
                manga.totalPages = Int64(totalPages)
                manga.title = metadata.title
                manga.author = authorValue.isEmpty ? nil : authorValue
                manga.titleWasExtracted = metadata.titleWasExtracted
                manga.authorWasExtracted = metadata.authorWasExtracted
                manga.importComplete = true
                manga.importErrorMessage = nil
                manga.importFile = nil

                try finalizeContext.save()
            }

            logger.debug("Manga import completed for \(jobID)")

        } catch is CancellationError {
            await handleCancellation(for: jobID)
        } catch {
            await handleError(error, for: jobID)
        }
    }

    private func handleCancellation(for jobID: NSManagedObjectID) async {
        let cleanupContext = container.newBackgroundContext()
        cleanupContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        cleanupContext.undoManager = nil

        let cleanupInfo: (URL?, URL?)? = await cleanupContext.perform {
            guard let manga = try? cleanupContext.existingObject(with: jobID) as? MangaArchive else {
                return nil
            }
            manga.importErrorMessage = "Import cancelled."
            manga.importFile = nil

            let localPath = manga.localPath
            let coverImage = manga.coverImage
            manga.localFileName = nil
            manga.coverFileName = nil
            manga.importComplete = false
            try? cleanupContext.save()
            return (localPath, coverImage)
        }

        if let (localPath, coverImage) = cleanupInfo {
            Self.cleanupMangaFiles(localPath: localPath, coverImage: coverImage)
        }
    }

    private func handleError(_ error: Error, for jobID: NSManagedObjectID) async {
        let cleanupContext = container.newBackgroundContext()
        cleanupContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        cleanupContext.undoManager = nil

        // Use our custom error description if it's a MangaImportError
        let errorMessage = (error as? MangaImportError)?.localizedDescription ?? error.localizedDescription

        let cleanupInfo: (URL?, URL?)? = await cleanupContext.perform {
            guard let manga = try? cleanupContext.existingObject(with: jobID) as? MangaArchive else {
                return nil
            }
            manga.importErrorMessage = errorMessage
            manga.importFile = nil
            let localPath = manga.localPath
            let coverImage = manga.coverImage
            manga.localFileName = nil
            manga.coverFileName = nil
            manga.importComplete = false
            try? cleanupContext.save()
            return (localPath, coverImage)
        }

        if let (localPath, coverImage) = cleanupInfo {
            Self.cleanupMangaFiles(localPath: localPath, coverImage: coverImage)
        }

        logger.error("Manga import failed for \(jobID): \(errorMessage)")
    }

    // MARK: - Helper Methods

    private var shouldUseSmartMetadataExtraction: Bool {
        MangaMetadataExtractionSettings.smartExtractionEnabled && metadataExtractor.isModelAvailable
    }

    private func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    private func sortedImageEntries(_ entries: [Entry]) -> [Entry] {
        entries
            .filter { $0.type == .file && isImageFile($0.path) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func extractCover(from archive: Archive, entry: Entry, to coverURL: URL) async throws {
        // Extract to a temp location first to avoid concurrency issues with streaming closure
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await archive.extract(entry, to: tempURL)

        let imageData = try Data(contentsOf: tempURL)
        guard let image = UIImage(data: imageData) else {
            throw NSError(domain: "MangaImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }

        guard let pngData = image.pngData() else {
            throw NSError(domain: "MangaImport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to PNG"])
        }

        try pngData.write(to: coverURL)
    }

    // MARK: - Directory Management

    private func mangaDirectory() throws -> URL {
        let documentsDir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let mangaDir = documentsDir.appendingPathComponent("Manga")
        if !FileManager.default.fileExists(atPath: mangaDir.path) {
            try FileManager.default.createDirectory(at: mangaDir, withIntermediateDirectories: true)
        }
        return mangaDir
    }

    private func coversDirectory() throws -> URL {
        let appSupportDir = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let coversDir = appSupportDir.appendingPathComponent("Covers")
        if !FileManager.default.fileExists(atPath: coversDir.path) {
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        }
        return coversDir
    }

    // MARK: - File Cleanup

    static func cleanupMangaFiles(localPath: URL?, coverImage: URL?) {
        let fileManager = FileManager.default

        if let localPath {
            if fileManager.fileExists(atPath: localPath.path) {
                try? fileManager.removeItem(at: localPath)
            }
        }

        if let coverImage {
            if fileManager.fileExists(atPath: coverImage.path) {
                try? fileManager.removeItem(at: coverImage)
            }
        }
    }
}
