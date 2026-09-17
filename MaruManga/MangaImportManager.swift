// MangaImportManager.swift
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
import MaruReaderCore
import MaruVision
import os
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
    private let logger = Logger.maru(category: "MangaImport")

    /// Supported image extensions
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp"]

    // Test hooks for controlled testing
    var testCancellationHook: (() async throws -> Void)?
    var testErrorInjection: (() throws -> Void)?

    /// Initializer for both shared instance and testing with custom container
    public init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - Public API

    /// Prewarm the metadata extractor model
    public func prewarmMetadataExtractor() async {
        guard shouldUseSmartMetadataExtraction else {
            return
        }
        await metadataExtractor.prewarm()
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
            manga.pendingDeletion = false
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
                    manga.importErrorMessage = MangaLocalization.string("Import cancelled.")
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

    /// Mark interrupted jobs as failed and clean any partially imported files.
    public func cleanupInterruptedImports() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupInfos: [(URL?, URL?)] = await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.predicate = NSPredicate(format: "importComplete == NO AND pendingDeletion == NO AND (importErrorMessage == nil OR importErrorMessage == '')")
            let archives = (try? context.fetch(request)) ?? []
            guard !archives.isEmpty else { return [] }

            var infos: [(URL?, URL?)] = []
            for manga in archives {
                manga.importErrorMessage = MangaLocalization.string("Import interrupted.")
                manga.importFile = nil

                let localPath = manga.localPath
                let coverImage = manga.coverImage
                manga.localFileName = nil
                manga.coverFileName = nil
                manga.importComplete = false

                infos.append((localPath, coverImage))
            }

            try? context.save()
            return infos
        }

        guard !cleanupInfos.isEmpty else { return }
        logger.debug("Cleaning up \(cleanupInfos.count, privacy: .public) interrupted manga imports")

        for (localPath, coverImage) in cleanupInfos {
            Self.cleanupMangaFiles(localPath: localPath, coverImage: coverImage)
        }
    }

    /// Delete a manga and its associated files.
    /// - Parameter mangaID: The NSManagedObjectID of the MangaArchive to delete.
    public func deleteManga(mangaID: NSManagedObjectID) async {
        logger.debug("Starting manga deletion for \(mangaID)")

        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        taskContext.undoManager = nil
        taskContext.shouldDeleteInaccessibleFaults = true

        do {
            try await taskContext.perform {
                guard let manga = try? taskContext.existingObject(with: mangaID) as? MangaArchive else {
                    throw MangaImportError.databaseError
                }
                manga.pendingDeletion = true
                manga.importErrorMessage = nil
                try taskContext.save()
            }
        } catch {
            logger.error("Failed to mark manga for deletion \(mangaID): \(error.localizedDescription)")
            return
        }

        Task {
            do {
                try await deleteMangaEntity(mangaID: mangaID)
                logger.debug("Manga deletion completed for \(mangaID)")
            } catch {
                logger.error("Manga deletion failed for \(mangaID): \(error.localizedDescription)")
                await taskContext.perform {
                    guard let manga = try? taskContext.existingObject(with: mangaID) as? MangaArchive else {
                        return
                    }
                    manga.pendingDeletion = false
                    try? taskContext.save()
                }
            }
        }
    }

    /// Attaches a mokuro OCR data file to an already-imported manga.
    /// Validates the file decodes as mokuro JSON with at least one page before
    /// copying it in and updating the manga's `mokuroFileName`. Overwrites any
    /// previously attached mokuro file for this manga.
    /// - Parameters:
    ///   - url: The file URL of the `.mokuro` file to attach.
    ///   - mangaID: The NSManagedObjectID of the MangaArchive to attach it to.
    public func attachMokuroFile(from url: URL, to mangaID: NSManagedObjectID) async throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MangaImportError.fileAccessDenied
        }

        let volume = try decodeMokuroVolume(from: data)

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (mangaUUID, mangaTotalPages, mangaTitle): (UUID, Int64, String?) = try await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive,
                  let mangaUUID = manga.id
            else {
                throw MangaImportError.databaseError
            }
            return (mangaUUID, manga.totalPages, manga.title)
        }

        logMokuroPageCountMismatch(
            volume: volume,
            totalPages: mangaTotalPages,
            mangaDescription: mangaTitle ?? mangaUUID.uuidString
        )

        let destinationFileName = try writeMokuroData(data, forMangaUUID: mangaUUID)
        let destinationURL = try mangaDirectory().appendingPathComponent(destinationFileName)

        do {
            try await context.perform {
                guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                    throw MangaImportError.databaseError
                }
                manga.mokuroFileName = destinationFileName
                try context.save()
            }
        } catch {
            // Avoid leaving an orphaned mokuro file with no corresponding
            // mokuroFileName if the Core Data update fails.
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    /// Removes an attached mokuro file from a manga, clearing the attribute
    /// and deleting the copied file.
    /// - Parameter mangaID: The NSManagedObjectID of the MangaArchive to remove it from.
    public func removeMokuroFile(from mangaID: NSManagedObjectID) async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let logger = self.logger
        // Only delete the file once the attribute is actually cleared. Deleting on a
        // failed save would leave mokuroFileName persisted with no file behind it:
        // every later open would log a read failure and the UI would keep offering
        // "Remove Mokuro File" for an attachment that no longer exists.
        let fileToDelete: URL? = await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return nil
            }
            let fileURL = manga.mokuroFile
            manga.mokuroFileName = nil
            do {
                try context.save()
            } catch {
                logger.error("Failed to clear mokuroFileName; leaving the file in place: \(error.localizedDescription)")
                return nil
            }
            return fileURL
        }

        if let fileToDelete, FileManager.default.fileExists(atPath: fileToDelete.path) {
            try? FileManager.default.removeItem(at: fileToDelete)
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

    /// Clean up manga archives marked for deletion but not yet removed.
    public func cleanupPendingDeletions() async {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let pendingIDs: [NSManagedObjectID] = await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.predicate = NSPredicate(format: "pendingDeletion == YES")
            let archives = (try? context.fetch(request)) ?? []
            return archives.map(\.objectID)
        }

        guard !pendingIDs.isEmpty else { return }
        logger.debug("Cleaning up \(pendingIDs.count, privacy: .public) pending manga deletions")

        for mangaID in pendingIDs {
            do {
                try await deleteMangaEntity(mangaID: mangaID)
            } catch {
                logger.error("Pending manga deletion cleanup failed for \(mangaID): \(error.localizedDescription)")
            }
        }
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

        // Tracked outside the `do` so a cancellation or failure between writing an
        // embedded mokuro file and saving `mokuroFileName` can still delete it.
        // The cleanup paths read the URL back off the entity, where it is still nil.
        var writtenMokuroFile: URL?

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

            // A `.mokuro` packaged inside the archive is attached automatically.
            // Done after the archive copy and cover extraction so a failure here
            // can never orphan those; a mokuro file the user did not explicitly
            // pick is a bonus, so any problem with it is logged and skipped
            // rather than failing the import.
            let embeddedMokuroFileName = await embeddedMokuroFileName(
                from: archive,
                entries: entries,
                mangaUUID: mangaUUID,
                totalPages: totalPages
            )
            if let embeddedMokuroFileName {
                writtenMokuroFile = try? mangaDirectory().appendingPathComponent(embeddedMokuroFileName)
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
                manga.mokuroFileName = embeddedMokuroFileName
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
            removeOrphanedMokuroFile(writtenMokuroFile)
            await handleCancellation(for: jobID)
        } catch {
            removeOrphanedMokuroFile(writtenMokuroFile)
            await handleError(error, for: jobID)
        }
    }

    private func removeOrphanedMokuroFile(_ fileURL: URL?) {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func handleCancellation(for jobID: NSManagedObjectID) async {
        let cleanupContext = container.newBackgroundContext()
        cleanupContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        cleanupContext.undoManager = nil

        let cleanupInfo: (URL?, URL?)? = await cleanupContext.perform {
            guard let manga = try? cleanupContext.existingObject(with: jobID) as? MangaArchive else {
                return nil
            }
            manga.importErrorMessage = MangaLocalization.string("Import cancelled.")
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

        let errorMessage = error.localizedDescription

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
        MangaMetadataExtractionSettings.smartExtractionEnabled && MangaFilenameMetadataExtractor.isModelAvailable
    }

    private func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    private func sortedImageEntries(_ entries: [Entry]) -> [Entry] {
        entries
            .filter(isImageEntry)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func sortedMokuroEntries(_ entries: [Entry]) -> [Entry] {
        entries
            .filter(isMokuroEntry)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func isMokuroEntry(_ entry: Entry) -> Bool {
        entry.type == .file
            && entry.uncompressedSize > 0
            && (entry.path as NSString).pathExtension.lowercased() == "mokuro"
            && !isAppleDoublePath(entry.path)
    }

    /// Extracts, validates and stores a `.mokuro` file packaged inside the archive,
    /// returning the stored filename, or `nil` when the archive has none or the one
    /// it has is unusable.
    ///
    /// Unlike `attachMokuroFile(from:to:)`, nothing here throws: the user asked for
    /// a manga, not for this file, so an unusable embedded mokuro is logged and the
    /// import proceeds with on-device OCR.
    private func embeddedMokuroFileName(
        from archive: Archive,
        entries: [Entry],
        mangaUUID: UUID,
        totalPages: Int
    ) async -> String? {
        let candidates = sortedMokuroEntries(entries)
        guard let entry = candidates.first else { return nil }

        if candidates.count > 1 {
            logger.debug(
                """
                Archive contains \(candidates.count, privacy: .public) .mokuro entries; \
                attaching \(entry.path, privacy: .public)
                """
            )
        }

        do {
            let data = try await extractEntryData(from: archive, entry: entry)
            let volume = try decodeMokuroVolume(from: data)
            logMokuroPageCountMismatch(
                volume: volume,
                totalPages: Int64(totalPages),
                mangaDescription: mangaUUID.uuidString
            )
            let fileName = try writeMokuroData(data, forMangaUUID: mangaUUID)
            logger.debug("Attached embedded mokuro file \(entry.path, privacy: .public) during import")
            return fileName
        } catch {
            logger.warning(
                """
                Embedded mokuro file \(entry.path, privacy: .public) could not be attached \
                (\(error.localizedDescription, privacy: .public)); importing without it
                """
            )
            return nil
        }
    }

    /// Decodes mokuro JSON, rejecting anything that is not a volume with at least one page.
    private func decodeMokuroVolume(from data: Data) throws -> MokuroVolume {
        guard let volume = try? JSONDecoder().decode(MokuroVolume.self, from: data),
              !volume.pages.isEmpty
        else {
            throw MangaImportError.invalidMokuroFile
        }
        return volume
    }

    /// Writes validated mokuro JSON to this manga's mokuro destination, replacing any
    /// file already there, and returns the stored filename.
    private func writeMokuroData(_ data: Data, forMangaUUID mangaUUID: UUID) throws -> String {
        let mangaDir = try mangaDirectory()
        let destinationFileName = "\(mangaUUID.uuidString).mokuro"
        let destinationURL = mangaDir.appendingPathComponent(destinationFileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw MangaImportError.mokuroFileCopyFailed(underlyingError: error)
        }
        return destinationFileName
    }

    /// A mokuro file covering a different number of pages than the archive still
    /// pairs page-by-page on filename, so this is a diagnostic, not a rejection.
    private func logMokuroPageCountMismatch(
        volume: MokuroVolume,
        totalPages: Int64,
        mangaDescription: String
    ) {
        guard Int64(volume.pages.count) != totalPages else { return }
        logger.warning(
            """
            Attached mokuro file page count (\(volume.pages.count, privacy: .public)) does not \
            match manga totalPages (\(totalPages, privacy: .public)) for manga \
            \(mangaDescription, privacy: .public)
            """
        )
    }

    private func isImageEntry(_ entry: Entry) -> Bool {
        entry.type == .file
            && entry.uncompressedSize > 0
            && isImageFile(entry.path)
            && !isAppleDoublePath(entry.path)
    }

    private func isAppleDoublePath(_ path: String) -> Bool {
        let path = path as NSString
        return path.pathComponents.contains("__MACOSX")
            || path.lastPathComponent.hasPrefix("._")
    }

    private static let coverMaxPixelSize: CGFloat = 512

    /// Reads one archive entry into memory.
    ///
    /// Extracts to a temp location first to avoid concurrency issues with the
    /// streaming closure.
    private func extractEntryData(from archive: Archive, entry: Entry) async throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await archive.extract(entry, to: tempURL)
        return try Data(contentsOf: tempURL)
    }

    private func extractCover(from archive: Archive, entry: Entry, to coverURL: URL) async throws {
        let imageData = try await extractEntryData(from: archive, entry: entry)
        guard let image = ImageDownsampler.downsample(
            data: imageData,
            maxPixelSize: Self.coverMaxPixelSize
        ) else {
            throw NSError(
                domain: "MangaImport",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: MangaLocalization.string("Invalid image data")]
            )
        }

        guard let pngData = image.pngData() else {
            throw NSError(
                domain: "MangaImport",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: MangaLocalization.string("Failed to convert to PNG")]
            )
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

    private func deleteMangaEntity(mangaID: NSManagedObjectID) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let cleanupInfo = try await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                throw MangaImportError.databaseError
            }

            let localPath = manga.localPath
            let coverImage = manga.coverImage
            let mokuroFile = manga.mokuroFile

            context.delete(manga)
            try context.save()

            return (localPath, coverImage, mokuroFile)
        }

        Self.cleanupMangaFiles(localPath: cleanupInfo.0, coverImage: cleanupInfo.1, mokuroFile: cleanupInfo.2)
    }

    static func cleanupMangaFiles(localPath: URL?, coverImage: URL?, mokuroFile: URL? = nil) {
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

        if let mokuroFile {
            if fileManager.fileExists(atPath: mokuroFile.path) {
                try? fileManager.removeItem(at: mokuroFile)
            }
        }
    }
}
