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

/// Covers the import-time pickup of a `.mokuro` file packaged inside the CBZ,
/// as opposed to the user attaching one by hand (`MangaMokuroAttachmentTests`).
///
/// Nothing here fails the import: the user asked for a manga, not for the mokuro
/// file, so an unusable one is skipped and the manga still arrives.
struct MangaEmbeddedMokuroImportTests {
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
        let archiveURL = try MokuroFixture.makeArchive(
            extraFiles: ["volume.mokuro": MokuroFixture.matchingMokuroJSON()]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName != nil)

        let mokuroFile = try #require(state.mokuroFile)
        #expect(FileManager.default.fileExists(atPath: mokuroFile.path))

        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(contentsOf: mokuroFile))
        #expect(volume.pages.map(\.imgPath) == MokuroFixture.defaultImageNames.map(MokuroFixture.archivePath))
    }

    @Test func import_archiveWithoutMokuro_leavesNothingAttached() async throws {
        let archiveURL = try MokuroFixture.makeArchive()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithUndecodableMokuro_stillImportsWithoutAttaching() async throws {
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: ["volume.mokuro": "not json at all"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithEmptyPagesMokuro_stillImportsWithoutAttaching() async throws {
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: ["volume.mokuro": "{\"pages\": []}"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    /// A mokuro file covering a different number of pages was generated from a
    /// different volume, so the import skips it rather than attaching OCR from
    /// another manga.
    @Test func import_archiveWithWrongPageCountMokuro_stillImportsWithoutAttaching() async throws {
        let shortMokuro = MokuroFixture.mokuroJSON(imgPaths: [MokuroFixture.archivePath("001.jpg")])
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: ["volume.mokuro": shortMokuro])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    /// Right page count, but every page names a file this archive does not have:
    /// it would pair with nothing, so it is skipped.
    @Test func import_archiveWithMokuroForDifferentVolume_stillImportsWithoutAttaching() async throws {
        let foreignMokuro = MokuroFixture.mokuroJSON(imgPaths: [
            "other_volume/001.jpg",
            "other_volume/002.jpg",
            "other_volume/003.jpg",
        ])
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: ["volume.mokuro": foreignMokuro])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    /// Covering only some of the pages is still worth attaching — those pages get
    /// real OCR — and the import says nothing, since the user did not pick the file.
    @Test func import_archiveWithPartiallyMatchingMokuro_attachesIt() async throws {
        let partialMokuro = MokuroFixture.mokuroJSON(imgPaths: [
            MokuroFixture.archivePath("001.jpg"),
            MokuroFixture.archivePath("002.jpg"),
            "other_volume/003.jpg",
        ])
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: ["volume.mokuro": partialMokuro])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName != nil)
    }

    @Test func import_archiveWithMultipleMokuroFiles_attachesFirstBySortedPath() async throws {
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: [
            "b_second.mokuro": MokuroFixture.matchingMokuroJSON(imgWidth: 22),
            "a_first.mokuro": MokuroFixture.matchingMokuroJSON(imgWidth: 11),
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        let mokuroFile = try #require(state.mokuroFile)
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(contentsOf: mokuroFile))
        #expect(volume.pages.first?.imgWidth == 11)
    }

    @Test func import_archiveWithOnlyAppleDoubleMokuro_attachesNothing() async throws {
        let archiveURL = try MokuroFixture.makeArchive(extraFiles: [
            "__MACOSX/._volume.mokuro": "AppleDouble metadata",
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.importComplete)
        #expect(state.mokuroFileName == nil)
    }

    @Test func import_archiveWithUppercaseMokuroExtension_attachesIt() async throws {
        let archiveURL = try MokuroFixture.makeArchive(
            extraFiles: ["VOLUME.MOKURO": MokuroFixture.matchingMokuroJSON()]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (_, context, mangaID) = try await runImport(of: archiveURL)
        let state = await mangaState(mangaID, in: context)

        #expect(state.mokuroFileName != nil)
    }

    @Test func deleteManga_removesAutomaticallyAttachedMokuroFile() async throws {
        let archiveURL = try MokuroFixture.makeArchive(
            extraFiles: ["volume.mokuro": MokuroFixture.matchingMokuroJSON()]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let (importManager, context, mangaID) = try await runImport(of: archiveURL)
        let mokuroFile = try #require(await mangaState(mangaID, in: context).mokuroFile)
        #expect(FileManager.default.fileExists(atPath: mokuroFile.path))

        await importManager.removeMokuroFile(from: mangaID)

        #expect(!FileManager.default.fileExists(atPath: mokuroFile.path))
        #expect(await mangaState(mangaID, in: context).mokuroFileName == nil)
    }
}
