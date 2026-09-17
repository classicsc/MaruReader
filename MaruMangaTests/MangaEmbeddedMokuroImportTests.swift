// MangaEmbeddedMokuroImportTests.swift
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
import MaruVision
import Testing
import UIKit
import Zip

/// Covers the import-time pickup of a `.mokuro` file packaged inside the CBZ,
/// as opposed to the user attaching one by hand (`MangaMokuroAttachmentTests`).
struct MangaEmbeddedMokuroImportTests {
    enum FixtureError: Error {
        case imageEncodingFailed
        case archiveNotWritten
    }

    // MARK: - Fixtures

    private func mokuroJSON(imgPath: String) -> String {
        """
        {"pages": [{"img_width": 10, "img_height": 10, "blocks": [], "img_path": "\(imgPath)"}]}
        """
    }

    private func imageData(hue: CGFloat) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw FixtureError.imageEncodingFailed
        }
        return data
    }

    /// Builds a CBZ containing three page images plus whichever extra files are
    /// given as `path relative to the archive root` -> `contents`.
    private func makeArchive(
        named name: String = "Embedded Manga",
        imageNames: [String] = ["001.jpg", "002.jpg", "003.jpg"],
        extraFiles: [String: String] = [:]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        for (index, imageName) in imageNames.enumerated() {
            let data = try imageData(hue: CGFloat(index) / CGFloat(max(imageNames.count, 1)))
            try data.write(to: contentsDir.appendingPathComponent(imageName))
        }

        for (relativePath, contents) in extraFiles {
            let fileURL = contentsDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let archiveURL = tempDir.appendingPathComponent("\(name).cbz")
        try Zip.zipFiles(paths: [contentsDir], zipFilePath: archiveURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw FixtureError.archiveNotWritten
        }
        return archiveURL
    }

    // MARK: - Helpers

    private func runImport(of archiveURL: URL) async throws -> (MangaImportManager, NSManagedObjectContext, NSManagedObjectID) {
        let persistenceController = makeMangaPersistenceController()
        let importManager = MangaImportManager(container: persistenceController.container)
        let mangaID = try await importManager.enqueueImport(from: archiveURL)
        await importManager.waitForCompletion(jobID: mangaID)
        return (importManager, persistenceController.container.viewContext, mangaID)
    }

    private func mangaState(
        _ mangaID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) async -> (importComplete: Bool, mokuroFileName: String?, mokuroFile: URL?) {
        await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return (false, nil, nil)
            }
            return (manga.importComplete, manga.mokuroFileName, manga.mokuroFile)
        }
    }

    // MARK: - Tests

    @Test func import_archiveWithEmbeddedMokuro_attachesItAutomatically() async throws {
        let archiveURL = try makeArchive(extraFiles: ["volume.mokuro": mokuroJSON(imgPath: "001.jpg")])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName != nil)

        let mokuroFile = try #require(state.mokuroFile)
        #expect(FileManager.default.fileExists(atPath: mokuroFile.path))

        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(contentsOf: mokuroFile))
        #expect(volume.pages.map(\.imgPath) == ["001.jpg"])
    }

    @Test func import_archiveWithoutMokuro_leavesNothingAttached() async throws {
        let archiveURL = try makeArchive()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithUndecodableMokuro_stillImportsWithoutAttaching() async throws {
        let archiveURL = try makeArchive(extraFiles: ["volume.mokuro": "not json at all"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithEmptyPagesMokuro_stillImportsWithoutAttaching() async throws {
        let archiveURL = try makeArchive(extraFiles: ["volume.mokuro": "{\"pages\": []}"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithMultipleMokuroFiles_attachesFirstBySortedPath() async throws {
        let archiveURL = try makeArchive(extraFiles: [
            "b_second.mokuro": mokuroJSON(imgPath: "second.jpg"),
            "a_first.mokuro": mokuroJSON(imgPath: "first.jpg"),
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        let mokuroFile = try #require(state.mokuroFile)
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(contentsOf: mokuroFile))
        #expect(volume.pages.map(\.imgPath) == ["first.jpg"])
    }

    @Test func import_archiveWithOnlyAppleDoubleMokuro_attachesNothing() async throws {
        let archiveURL = try makeArchive(extraFiles: [
            "__MACOSX/._volume.mokuro": "AppleDouble metadata",
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithUppercaseMokuroExtension_attachesIt() async throws {
        let archiveURL = try makeArchive(extraFiles: ["VOLUME.MOKURO": mokuroJSON(imgPath: "001.jpg")])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.mokuroFileName != nil)
    }

    @Test func deleteManga_removesAutomaticallyAttachedMokuroFile() async throws {
        let archiveURL = try makeArchive(extraFiles: ["volume.mokuro": mokuroJSON(imgPath: "001.jpg")])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (importManager, context, mangaID) = try await runImport(of: archiveURL)
        let mokuroFile = try #require(await mangaState(mangaID, in: context).mokuroFile)
        #expect(FileManager.default.fileExists(atPath: mokuroFile.path))

        await importManager.removeMokuroFile(from: mangaID)

        #expect(!FileManager.default.fileExists(atPath: mokuroFile.path))
        #expect(await mangaState(mangaID, in: context).mokuroFileName == nil)
    }
}
