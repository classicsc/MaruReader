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

struct MangaMokuroAttachmentTests {
    private let validMokuroJSON = """
    {"pages": [{"img_width": 10, "img_height": 10, "blocks": [], "img_path": "001.jpg"}]}
    """

    private func makeImportedManga(
        persistenceController: MangaDataPersistenceController
    ) async throws -> NSManagedObjectID {
        let context = persistenceController.container.newBackgroundContext()
        return try await context.perform {
            let manga = MangaArchive(context: context)
            manga.id = UUID()
            manga.title = "Test Manga"
            manga.localFileName = "test.cbz"
            manga.importComplete = true
            manga.dateAdded = Date()
            try context.save()
            return manga.objectID
        }
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
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let sourceURL = try writeTempFile(contents: validMokuroJSON, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)

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
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let sourceURL = try writeTempFile(contents: "not json", extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.self) {
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
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let sourceURL = try writeTempFile(contents: "{\"pages\": []}", extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        await #expect(throws: MangaImportError.self) {
            try await importManager.attachMokuroFile(from: sourceURL, to: mangaID)
        }

        let context = persistenceController.container.viewContext
        let mangaUUID = try #require(await mangaUUID(for: mangaID, context: context))
        let destinationURL = try expectedDestinationURL(forMangaUUID: mangaUUID)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test func attachMokuroFile_replacesExistingAttachment() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let firstURL = try writeTempFile(contents: validMokuroJSON, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: firstURL) }
        try await importManager.attachMokuroFile(from: firstURL, to: mangaID)

        let context = persistenceController.container.viewContext
        let firstFileName = try #require(await mokuroFileName(for: mangaID, context: context))

        let secondJSON = """
        {"pages": [{"img_width": 20, "img_height": 20, "blocks": [], "img_path": "002.jpg"}]}
        """
        let secondURL = try writeTempFile(contents: secondJSON, extension: "mokuro")
        defer { try? FileManager.default.removeItem(at: secondURL) }
        try await importManager.attachMokuroFile(from: secondURL, to: mangaID)

        let secondFileName = try #require(await mokuroFileName(for: mangaID, context: context))
        #expect(firstFileName == secondFileName, "Same manga UUID should produce the same destination filename")

        let mangaDir = try #require(MangaArchive.mangaDirectory())
        let destinationURL = mangaDir.appendingPathComponent(secondFileName)
        let contents = try String(contentsOf: destinationURL, encoding: .utf8)
        #expect(contents.contains("002.jpg"))
    }

    @Test func attachMokuroFile_unreadableFile_throwsFileAccessDenied() async throws {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

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
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let sourceURL = try writeTempFile(contents: validMokuroJSON, extension: "mokuro")
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
        let mangaID = try await makeImportedManga(persistenceController: persistenceController)

        let sourceURL = try writeTempFile(contents: validMokuroJSON, extension: "mokuro")
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
