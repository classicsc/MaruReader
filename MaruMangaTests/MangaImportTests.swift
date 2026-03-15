// MangaImportTests.swift
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
@testable import MaruManga
import Testing
import UIKit
import Zip

struct MangaImportTests {
    /// Custom errors for diagnostics
    enum MockArchiveError: Error {
        case fileWriteFailed(URL)
        case fileNotFound(URL)
        case zipCreationFailed
    }

    // MARK: - Helper Methods

    /// Creates a minimal valid manga archive (CBZ) with images
    private func createValidMangaArchive(imageCount: Int = 5, filename: String = "test_manga") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Create dummy image files
        for i in 1 ... imageCount {
            let imageName = "page_\(String(i).padding(toLength: 3, withPad: "0", startingAt: 0)).jpg"
            let imageURL = imagesDir.appendingPathComponent(imageName)

            // Create a minimal valid JPEG using UIKit
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
            let image = renderer.image { context in
                // Draw a colored square (different color per page for uniqueness)
                UIColor(hue: CGFloat(i) / CGFloat(imageCount), saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            }
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw MockArchiveError.fileWriteFailed(imageURL)
            }
            try jpegData.write(to: imageURL)
        }

        // Create CBZ archive
        let archiveURL = tempDir.appendingPathComponent("\(filename).cbz")
        let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)

        try Zip.zipFiles(paths: imageFiles, zipFilePath: archiveURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw MockArchiveError.fileNotFound(archiveURL)
        }

        return archiveURL
    }

    /// Creates a manga archive with images named out of order to test cover detection
    private func createMangaArchiveWithUnorderedImages() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Create images with names out of order
        let imageNames = ["page_03.jpg", "page_01.jpg", "page_02.jpg"]

        for (index, imageName) in imageNames.enumerated() {
            let imageURL = imagesDir.appendingPathComponent(imageName)

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
            let image = renderer.image { context in
                // Different colors for each image
                let color: UIColor = switch index {
                case 0: .red
                case 1: .green // This should be the cover (page_01)
                default: .blue
                }
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            }
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw MockArchiveError.fileWriteFailed(imageURL)
            }
            try jpegData.write(to: imageURL)
        }

        // Create CBZ archive
        let archiveURL = tempDir.appendingPathComponent("unordered_manga.cbz")
        let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)

        try Zip.zipFiles(paths: imageFiles, zipFilePath: archiveURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw MockArchiveError.fileNotFound(archiveURL)
        }

        return archiveURL
    }

    /// Creates an archive with no images (only directories/non-image files)
    private func createEmptyMangaArchive() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        // Create a non-image file
        let textURL = contentsDir.appendingPathComponent("readme.txt")
        try "This archive contains no images".write(to: textURL, atomically: true, encoding: .utf8)

        // Create ZIP archive
        let archiveURL = tempDir.appendingPathComponent("empty_manga.cbz")
        try Zip.zipFiles(paths: [textURL], zipFilePath: archiveURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw MockArchiveError.fileNotFound(archiveURL)
        }

        return archiveURL
    }

    /// Creates a corrupted/invalid archive
    private func createInvalidArchive() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let archiveURL = tempDir.appendingPathComponent("invalid.cbz")
        // Create a file with ZIP-like header but corrupted content
        let corruptedData = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF])
        try corruptedData.write(to: archiveURL)

        return archiveURL
    }

    /// Creates a non-archive file for testing file type validation
    private func createNonArchiveFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let textURL = tempDir.appendingPathComponent("test.txt")
        try "This is not an archive file".write(to: textURL, atomically: true, encoding: .utf8)

        return textURL
    }

    // MARK: - DTO Helper Methods

    private func getMangaDTO(from context: NSManagedObjectContext, mangaID: NSManagedObjectID) async -> MangaArchiveDTO? {
        await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return nil
            }
            return MangaArchiveDTO(from: manga)
        }
    }

    private func getMangaDTO(from context: NSManagedObjectContext, mangaUUID: UUID) async -> MangaArchiveDTO? {
        await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", mangaUUID as CVarArg)
            request.fetchLimit = 1
            guard let manga = try? context.fetch(request).first else {
                return nil
            }
            return MangaArchiveDTO(from: manga)
        }
    }

    private func fetchAllManga(from context: NSManagedObjectContext) async -> [MangaArchiveDTO] {
        await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            let results = (try? context.fetch(request)) ?? []
            return results.map { MangaArchiveDTO(from: $0) }
        }
    }

    // MARK: - Validation Helper Methods

    private func verifyImportCompleted(_ mangaDTO: MangaArchiveDTO?) {
        #expect(mangaDTO != nil)
        #expect(mangaDTO?.importComplete == true)
        #expect(mangaDTO?.importErrorMessage == nil)
        #expect(mangaDTO?.localPath != nil)
        #expect(mangaDTO?.coverImage != nil)
        #expect(mangaDTO?.totalPages ?? 0 > 0)
    }

    private func verifyImportFailed(_ mangaDTO: MangaArchiveDTO?) {
        #expect(mangaDTO != nil)
        #expect(mangaDTO?.importComplete == false)
        #expect(mangaDTO?.importErrorMessage?.isEmpty == false)
    }

    private func verifyImportCancelled(_ mangaDTO: MangaArchiveDTO?) {
        #expect(mangaDTO != nil)
        #expect(mangaDTO?.importComplete == false)
        #expect(mangaDTO?.importErrorMessage == "Import cancelled.")
    }

    private func verifyMangaPersisted(_ mangaDTO: MangaArchiveDTO?, expectedTitle: String, expectedPageCount: Int) {
        #expect(mangaDTO != nil)
        #expect(mangaDTO?.title == expectedTitle)
        #expect(mangaDTO?.id != nil)
        #expect(mangaDTO?.importComplete == true)
        #expect(mangaDTO?.totalPages == Int64(expectedPageCount))
        #expect(mangaDTO?.dateAdded != nil)
    }

    private func verifyArchiveCopied(mangaDTO: MangaArchiveDTO?) throws {
        guard let mangaDTO, let localPath = mangaDTO.localPath else {
            Issue.record("Manga or localPath is nil")
            return
        }

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: localPath.path), "Archive file should be copied to Manga directory")

        // Verify file is not empty
        let fileSize = try? fileManager.attributesOfItem(atPath: localPath.path)[.size] as? Int
        #expect((fileSize ?? 0) > 0, "Copied archive file should not be empty")
    }

    private func verifyCoverExtracted(mangaDTO: MangaArchiveDTO?) throws {
        guard let mangaDTO, let coverImage = mangaDTO.coverImage else {
            Issue.record("Manga or coverImage is nil")
            return
        }

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: coverImage.path), "Cover file should be extracted to Covers directory")

        // Verify file is not empty
        let fileSize = try? fileManager.attributesOfItem(atPath: coverImage.path)[.size] as? Int
        #expect((fileSize ?? 0) > 0, "Extracted cover file should not be empty")
    }

    private func verifyFilesCleanedUp(mangaDTO: MangaArchiveDTO?) throws {
        guard let mangaDTO else { return }

        let fileManager = FileManager.default

        if let localPath = mangaDTO.localPath {
            #expect(!fileManager.fileExists(atPath: localPath.path), "Archive file should be deleted after cancellation/failure")
        }

        if let coverImage = mangaDTO.coverImage {
            #expect(!fileManager.fileExists(atPath: coverImage.path), "Cover file should be deleted after cancellation/failure")
        }
    }

    // MARK: - Test Cases

    @Test func importManga_ValidArchive_ImportsSuccessfully() async throws {
        // Setup: Create a valid manga archive
        let archiveURL = try createValidMangaArchive(imageCount: 5, filename: "my_manga")
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: archiveURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Job completed successfully
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportCompleted(mangaDTO)

        // Assert: Manga entity created with correct metadata
        verifyMangaPersisted(mangaDTO, expectedTitle: "my_manga", expectedPageCount: 5)

        // Assert: Archive file was copied
        try verifyArchiveCopied(mangaDTO: mangaDTO)

        // Assert: Cover was extracted
        try verifyCoverExtracted(mangaDTO: mangaDTO)
    }

    @Test func importManga_ExtractsCoverFromFirstImage() async throws {
        // Setup: Create an archive with images named out of order
        let archiveURL = try createMangaArchiveWithUnorderedImages()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: archiveURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Job completed successfully
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportCompleted(mangaDTO)

        // Assert: totalPages is correct (3 images)
        #expect(mangaDTO?.totalPages == 3)

        // Assert: Cover was extracted (should be page_01 which is green)
        try verifyCoverExtracted(mangaDTO: mangaDTO)
    }

    @Test func importManga_NoImages_FailsWithError() async throws {
        // Setup: Create an archive with no images
        let archiveURL = try createEmptyMangaArchive()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: archiveURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportFailed(mangaDTO)

        // Assert: Error message indicates no images found
        #expect(mangaDTO?.importErrorMessage?.contains("no supported image") == true)

        // Assert: Manga entity persisted for failed import
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Failed imports should remain in the library for removal")

        // Assert: Files cleaned up
        try verifyFilesCleanedUp(mangaDTO: mangaDTO)
    }

    @Test func importManga_InvalidArchive_FailsWithError() async throws {
        // Setup: Create an invalid (corrupted) archive
        let invalidURL = try createInvalidArchive()
        defer { try? FileManager.default.removeItem(at: invalidURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: invalidURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportFailed(mangaDTO)

        // Assert: Manga entity persisted for failed import
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Failed imports should remain in the library for removal")
    }

    @Test func importManga_NonArchiveFile_FailsWithError() async throws {
        // Setup: Create a non-archive file
        let textURL = try createNonArchiveFile()
        defer { try? FileManager.default.removeItem(at: textURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: textURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportFailed(mangaDTO)

        // Assert: Manga entity persisted for failed import
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Failed imports should remain in the library for removal")
    }

    @Test func importManga_MissingFile_FailsWithError() async throws {
        // Setup: Create a file URL that doesn't exist
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.cbz")

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: missingURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportFailed(mangaDTO)

        // Assert: Manga entity persisted for failed import
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Failed imports should remain in the library for removal")
    }

    @Test func cleanupInterruptedMangaImports_MarksFailedAndCleansFiles() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        guard let mangaDir = MangaArchive.mangaDirectory(),
              let coversDir = MangaArchive.coversDirectory()
        else {
            Issue.record("Failed to resolve manga or cover directories")
            return
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: mangaDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)

        let localFileName = "interrupted-\(UUID().uuidString).cbz"
        let coverFileName = "interrupted-\(UUID().uuidString).png"
        let localURL = mangaDir.appendingPathComponent(localFileName)
        let coverURL = coversDir.appendingPathComponent(coverFileName)
        try Data("manga".utf8).write(to: localURL)
        try Data("cover".utf8).write(to: coverURL)

        let importURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".cbz")
        try "source".write(to: importURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: importURL) }

        let context = persistenceController.container.newBackgroundContext()
        let mangaID = try await context.perform {
            let manga = MangaArchive(context: context)
            manga.id = UUID()
            manga.title = "Interrupted Manga"
            manga.importFile = importURL
            manga.localFileName = localFileName
            manga.coverFileName = coverFileName
            manga.importComplete = false
            manga.importErrorMessage = nil
            manga.dateAdded = Date()
            try context.save()
            return manga.objectID
        }

        await importManager.cleanupInterruptedImports()

        let viewContext = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: viewContext, mangaID: mangaID)
        verifyImportFailed(mangaDTO)
        #expect(mangaDTO?.localPath == nil)
        #expect(mangaDTO?.coverImage == nil)
        #expect(!fileManager.fileExists(atPath: localURL.path), "Manga archive should be deleted")
        #expect(!fileManager.fileExists(atPath: coverURL.path), "Cover image should be deleted")
    }

    @Test func cleanupPendingMangaDeletions_RemovesMangaAndFiles() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        let fileManager = FileManager.default
        let mangaDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Manga")
        let coversDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Covers")
        try fileManager.createDirectory(at: mangaDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)

        let localFileName = "pending-\(UUID().uuidString).cbz"
        let coverFileName = "pending-\(UUID().uuidString).png"
        let localURL = mangaDir.appendingPathComponent(localFileName)
        let coverURL = coversDir.appendingPathComponent(coverFileName)
        try Data("manga".utf8).write(to: localURL)
        try Data("cover".utf8).write(to: coverURL)

        let mangaUUID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        let mangaID = try await context.perform {
            let manga = MangaArchive(context: context)
            manga.id = mangaUUID
            manga.title = "Pending Manga"
            manga.localFileName = localFileName
            manga.coverFileName = coverFileName
            manga.importComplete = true
            manga.pendingDeletion = true
            try context.save()
            return manga.objectID
        }

        await importManager.cleanupPendingDeletions()

        let verificationContext = persistenceController.container.newBackgroundContext()
        let mangaDTO = await getMangaDTO(from: verificationContext, mangaUUID: mangaUUID)
        #expect(mangaDTO == nil, "Pending deletion manga should be removed")
        #expect(!fileManager.fileExists(atPath: localURL.path), "Archive file should be deleted")
        #expect(!fileManager.fileExists(atPath: coverURL.path), "Cover image should be deleted")
    }

    @Test func importManga_CancelDuringImport_CleansUpFiles() async throws {
        // Setup: Create a valid manga archive
        let archiveURL = try createValidMangaArchive(imageCount: 5, filename: "cancelled_manga")
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger during import
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 1 { // First cancellation check (after file copy)
                throw CancellationError()
            }
        }

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: archiveURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: mangaID)

        // Assert: Import marked as cancelled
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportCancelled(mangaDTO)

        // Assert: Cancelled manga remains in the library
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Cancelled imports should remain in the library for removal")

        // Assert: Files cleaned up
        try verifyFilesCleanedUp(mangaDTO: mangaDTO)
    }

    @Test func importManga_CancelQueuedJob_MarksAsCancelled() async throws {
        // Setup: Create a valid manga archive
        let archiveURL = try createValidMangaArchive(imageCount: 5, filename: "queued_manga")
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let mangaID = try await importManager.enqueueImport(from: archiveURL)

        // Cancel immediately (while still queued)
        await importManager.cancelImport(jobID: mangaID)

        // Wait a bit for cancellation to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert: Job marked as cancelled
        let context = persistenceController.container.viewContext
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        verifyImportCancelled(mangaDTO)

        // Assert: Cancelled manga remains in the library
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 1, "Cancelled queued imports should remain in the library for removal")
    }

    @Test func deleteManga_RemovesMangaAndFiles() async throws {
        // Setup: Import a valid manga first
        let archiveURL = try createValidMangaArchive(imageCount: 3, filename: "manga_to_delete")
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        let mangaID = try await importManager.enqueueImport(from: archiveURL)
        await importManager.waitForCompletion(jobID: mangaID)

        let context = persistenceController.container.viewContext

        // Verify manga was imported
        let mangaDTO = await getMangaDTO(from: context, mangaID: mangaID)
        #expect(mangaDTO != nil)
        try verifyArchiveCopied(mangaDTO: mangaDTO)
        try verifyCoverExtracted(mangaDTO: mangaDTO)

        // Save file paths for later verification
        let localPath = mangaDTO?.localPath
        let coverImage = mangaDTO?.coverImage

        // Action: Delete the manga
        await importManager.deleteManga(mangaID: mangaID)

        // Allow deletion to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Assert: Manga entity deleted
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.isEmpty, "No manga should remain after deletion")

        // Assert: Files cleaned up
        let fileManager = FileManager.default
        if let localPath {
            #expect(!fileManager.fileExists(atPath: localPath.path), "Archive file should be deleted")
        }
        if let coverImage {
            #expect(!fileManager.fileExists(atPath: coverImage.path), "Cover file should be deleted")
        }
    }

    @Test func importManga_MultipleImports_ProcessesSequentially() async throws {
        // Setup: Create multiple manga archives
        let archive1URL = try createValidMangaArchive(imageCount: 3, filename: "manga_1")
        let archive2URL = try createValidMangaArchive(imageCount: 4, filename: "manga_2")
        let archive3URL = try createValidMangaArchive(imageCount: 5, filename: "manga_3")
        defer {
            try? FileManager.default.removeItem(at: archive1URL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: archive2URL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: archive3URL.deletingLastPathComponent())
        }

        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)

        // Action: Enqueue multiple imports
        let manga1ID = try await importManager.enqueueImport(from: archive1URL)
        let manga2ID = try await importManager.enqueueImport(from: archive2URL)
        let manga3ID = try await importManager.enqueueImport(from: archive3URL)

        // Wait for all completions
        await importManager.waitForCompletion(jobID: manga1ID)
        await importManager.waitForCompletion(jobID: manga2ID)
        await importManager.waitForCompletion(jobID: manga3ID)

        // Assert: All imports completed successfully
        let context = persistenceController.container.viewContext
        let allManga = await fetchAllManga(from: context)
        #expect(allManga.count == 3, "All three manga should be imported")

        // Verify each manga
        let manga1DTO = await getMangaDTO(from: context, mangaID: manga1ID)
        let manga2DTO = await getMangaDTO(from: context, mangaID: manga2ID)
        let manga3DTO = await getMangaDTO(from: context, mangaID: manga3ID)

        verifyMangaPersisted(manga1DTO, expectedTitle: "manga_1", expectedPageCount: 3)
        verifyMangaPersisted(manga2DTO, expectedTitle: "manga_2", expectedPageCount: 4)
        verifyMangaPersisted(manga3DTO, expectedTitle: "manga_3", expectedPageCount: 5)
    }
}

// MARK: - DTOs for Thread-Safe Data Transfer

struct MangaArchiveDTO {
    let id: UUID?
    let title: String?
    let author: String?
    let totalPages: Int64
    let localPath: URL?
    let coverImage: URL?
    let dateAdded: Date?
    let lastReadDate: Date?
    let lastReadPage: Int64
    let readingDirection: String?
    let importComplete: Bool
    let importErrorMessage: String?

    init(from manga: MangaArchive) {
        id = manga.id
        title = manga.title
        author = manga.author
        totalPages = manga.totalPages
        localPath = manga.localPath
        coverImage = manga.coverImage
        dateAdded = manga.dateAdded
        lastReadDate = manga.lastReadDate
        lastReadPage = manga.lastReadPage
        readingDirection = manga.readingDirection
        importComplete = manga.importComplete
        importErrorMessage = manga.importErrorMessage
    }
}
