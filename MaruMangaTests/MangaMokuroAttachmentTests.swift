// MangaMokuroAttachmentTests.swift
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

/// Covers the user picking a `.mokuro` file for a manga already in the library,
/// as opposed to one packaged inside the CBZ (`MangaEmbeddedMokuroImportTests`).
///
/// Unlike the embedded flow, the user asked for this file by name, so a file that
/// does not belong to this manga is rejected with an error rather than skipped.
struct MangaMokuroAttachmentTests {
    /// A manga backed by a real CBZ in the manga directory, as it would be after a
    /// successful import — attaching validates against the archive's page images.
    private func makeImportedManga(
        persistenceController: MangaDataPersistenceController
    ) async throws -> (mangaID: NSManagedObjectID, archiveURL: URL) {
        let sourceURL = try MokuroFixture.makeArchive()
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let mangaUUID = UUID()
        let localFileName = "\(mangaUUID.uuidString).cbz"
        let mangaDir = try #require(MangaArchive.mangaDirectory())
        try FileManager.default.createDirectory(at: mangaDir, withIntermediateDirectories: true)
        let archiveURL = mangaDir.appendingPathComponent(localFileName)
        try? FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.copyItem(at: sourceURL, to: archiveURL)

        let context = persistenceController.container.newBackgroundContext()
        let mangaID = try await context.perform {
            let manga = MangaArchive(context: context)
            manga.id = mangaUUID
            manga.title = "Test Manga"
            manga.localFileName = localFileName
            manga.totalPages = Int64(MokuroFixture.defaultImageNames.count)
            manga.importComplete = true
            manga.dateAdded = Date()
            try context.save()
            return manga.objectID
        }
        return (mangaID, archiveURL)
    }

    private func writeTempFile(contents: String, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func mokuroFileName(for mangaID: NSManagedObjectID, context: NSManagedObjectContext) async -> String? {
        await context.perform {
            (try? context.existingObject(with: mangaID) as? MangaArchive)?.mokuroFileName
        }
    }

    private func mangaUUID(for mangaID: NSManagedObjectID, context: NSManagedObjectContext) async -> UUID? {
        await context.perform {
            (try? context.existingObject(with: mangaID) as? MangaArchive)?.id
        }
    }

    private func expectedDestinationURL(forMangaUUID mangaUUID: UUID) throws -> URL {
        let mangaDir = try #require(MangaArchive.mangaDirectory())
        return mangaDir.appendingPathComponent("\(mangaUUID.uuidString).mokuro")
    }

    @Test func attachMokuroFile_validFile_copiesAndSetsAttribute() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let sourceURL = try writeTempFile(contents: MokuroFixture.matchingMokuroJSON(), extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let result = try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        #expect(result == .complete)

        let context = persistenceController.container.viewContext
        let fileName = await mokuroFileName(for: mangaID, context: context)
        #expect(fileName != nil)

        let mangaDir = try #require(MangaArchive.mangaDirectory())
        let destinationURL = try mangaDir.appendingPathComponent(#require(fileName))
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test func attachMokuroFile_invalidJSON_throwsAndWritesNothing() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let sourceURL = try writeTempFile(contents: "not json", extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.invalidMokuroFile) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        let fileName = await mokuroFileName(for: mangaID, context: context)
        #expect(fileName == nil)

        let mangaUUID = try #require(await mangaUUID(for: mangaID, context: context))
        let destinationURL = try expectedDestinationURL(forMangaUUID: mangaUUID)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test func attachMokuroFile_emptyPagesArray_throws() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let sourceURL = try writeTempFile(contents: "{\"pages\": []}", extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.invalidMokuroFile) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        let mangaUUID = try #require(await mangaUUID(for: mangaID, context: context))
        let destinationURL = try expectedDestinationURL(forMangaUUID: mangaUUID)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    /// Mokuro is run over a whole volume, so a different page count means this file
    /// came from a different one.
    @Test func attachMokuroFile_wrongPageCount_throwsAndWritesNothing() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let shortMokuro = MokuroFixture.mokuroJSON(imgPaths: [MokuroFixture.archivePath("001.jpg")])
        let sourceURL = try writeTempFile(contents: shortMokuro, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.invalidMokuroFile) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        #expect(await mokuroFileName(for: mangaID, context: context) == nil)

        let mangaUUID = try #require(await mangaUUID(for: mangaID, context: context))
        let destinationURL = try expectedDestinationURL(forMangaUUID: mangaUUID)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    /// The right number of pages, but none of them are this archive's: it would
    /// pair with nothing, so it is for a different manga.
    @Test func attachMokuroFile_noMatchingPages_throwsAndWritesNothing() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let foreignMokuro = MokuroFixture.mokuroJSON(imgPaths: [
            "other_volume/001.jpg",
            "other_volume/002.jpg",
            "other_volume/003.jpg",
        ])
        let sourceURL = try writeTempFile(contents: foreignMokuro, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.invalidMokuroFile) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        #expect(await mokuroFileName(for: mangaID, context: context) == nil)

        let mangaUUID = try #require(await mangaUUID(for: mangaID, context: context))
        let destinationURL = try expectedDestinationURL(forMangaUUID: mangaUUID)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    /// Covering only some of the pages is worth attaching — those pages get real
    /// OCR — but the caller is told so it can warn.
    @Test func attachMokuroFile_partialMatch_attachesAndReportsCounts() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let partialMokuro = MokuroFixture.mokuroJSON(imgPaths: [
            MokuroFixture.archivePath("001.jpg"),
            MokuroFixture.archivePath("002.jpg"),
            "other_volume/003.jpg",
        ])
        let sourceURL = try writeTempFile(contents: partialMokuro, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let result = try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        #expect(result == .partial(matchedPages: 2, totalPages: 3))

        let context = persistenceController.container.viewContext
        #expect(await mokuroFileName(for: mangaID, context: context) != nil)
    }

    /// The archive is validated at import, so this only happens if it goes missing
    /// afterwards — but attaching a file we cannot check is worse than refusing.
    @Test func attachMokuroFile_missingArchive_throwsMissingFile() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        try FileManager.default.removeItem(at: archiveURL)

        let sourceURL = try writeTempFile(contents: MokuroFixture.matchingMokuroJSON(), extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.missingFile) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        #expect(await mokuroFileName(for: mangaID, context: context) == nil)
    }

    @Test func attachMokuroFile_replacesExistingAttachment() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let firstURL = try writeTempFile(
            contents: MokuroFixture.matchingMokuroJSON(imgWidth: 11),
            extension: "mokuro"
        )
        defer { try? FileManager.default.removeItem(at: firstURL) }
        try await importManager.attachMokuroFile(from: firstURL, to: mangaID)

        let context = persistenceController.container.viewContext
        let firstFileName = try #require(await mokuroFileName(for: mangaID, context: context))

        let secondURL = try writeTempFile(
            contents: MokuroFixture.matchingMokuroJSON(imgWidth: 22),
            extension: "mokuro"
        )
        defer { try? FileManager.default.removeItem(at: secondURL) }
        try await importManager.attachMokuroFile(from: secondURL, to: mangaID)

        let secondFileName = try #require(await mokuroFileName(for: mangaID, context: context))
        #expect(firstFileName == secondFileName, "Same manga UUID should produce the same destination filename")

        let mangaDir = try #require(MangaArchive.mangaDirectory())
        let destinationURL = mangaDir.appendingPathComponent(secondFileName)
        let contents = try String(contentsOf: destinationURL, encoding: .utf8)
        #expect(contents.contains("\"img_width\": 22"))
    }

    @Test func attachMokuroFile_unreadableFile_throwsFileAccessDenied() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        // A URL that does not exist on disk, so Data(contentsOf:) fails to read
        // rather than failing to decode.
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mokuro")

        await #expect(throws: MangaImportError.fileAccessDenied) {
            try await importManager.attachMokuroFile(from: missingURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        let fileName = await mokuroFileName(for: mangaID, context: context)
        #expect(fileName == nil)
    }

    @Test func deleteManga_RemovesMokuroFile() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let sourceURL = try writeTempFile(contents: MokuroFixture.matchingMokuroJSON(), extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)

        let context = persistenceController.container.viewContext
        let fileName = try #require(await mokuroFileName(for: mangaID, context: context))
        let mangaDir = try #require(MangaArchive.mangaDirectory())
        let destinationURL = mangaDir.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))

        await importManager.deleteManga(mangaID: mangaID)

        // Allow deletion to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        #expect(!FileManager.default.fileExists(atPath: destinationURL.path), "Mokuro file should be deleted alongside the manga")
    }

    @Test func removeMokuroFile_clearsAttributeAndDeletesFile() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let (mangaID, archiveURL) = try await makeImportedManga(persistenceController: persistenceController)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let sourceURL = try writeTempFile(contents: MokuroFixture.matchingMokuroJSON(), extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)

        let context = persistenceController.container.viewContext
        let fileName = try #require(await mokuroFileName(for: mangaID, context: context))
        let mangaDir = try #require(MangaArchive.mangaDirectory())
        let destinationURL = mangaDir.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))

        await importManager.removeMokuroFile(from: mangaID)

        let clearedFileName = await mokuroFileName(for: mangaID, context: context)
        #expect(clearedFileName == nil)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }
}
