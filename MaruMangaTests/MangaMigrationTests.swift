// MangaMigrationTests.swift
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
import MaruReaderCore
import Testing

/// Verifies that a store created under the V2 `MaruMangaData` model
/// lightweight-migrates cleanly to the current (V3) model. `Persistence.swift`
/// calls `fatalError` if `loadPersistentStores` reports an error, so a broken
/// migration path is a hard launch crash on upgrade with no recovery -- this
/// is the highest-consequence untested risk on this branch.
struct MangaMigrationTests {
    private func loadV2Model() throws -> NSManagedObjectModel {
        let bundle = Bundle(for: MangaDataPersistenceController.self)
        let momdURL = try #require(
            bundle.url(forResource: "MaruMangaData", withExtension: "momd"),
            "Failed to locate MaruMangaData.momd in the MaruManga bundle"
        )
        let v2MomURL = momdURL.appendingPathComponent("MaruMangaDataV2.mom")
        return try #require(
            NSManagedObjectModel(contentsOf: v2MomURL),
            "Failed to load MaruMangaDataV2.mom from \(v2MomURL.path)"
        )
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaMigrationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("MaruMangaData.sqlite")
    }

    private func loadContainer(
        model: NSManagedObjectModel,
        storeURL: URL,
        migrate: Bool
    ) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "MaruMangaData", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = migrate
        description.shouldInferMappingModelAutomatically = migrate
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    @Test func v2Store_migratesToV3_preservingRowsAndDefaultingMokuroFileName() async throws {
        let v2Model = try loadV2Model()
        let storeURL = try makeTemporaryStoreURL()

        let mangaUUID = UUID()
        let title = "Migration Test Manga"
        let localFileName = "migration-test.cbz"

        // 1 & 2: create a V2-model store and insert a row.
        do {
            let v2Container = try loadContainer(model: v2Model, storeURL: storeURL, migrate: false)
            let context = v2Container.newBackgroundContext()
            try await context.perform {
                let entity = try #require(
                    NSEntityDescription.entity(forEntityName: "MangaArchive", in: context)
                )
                let manga = NSManagedObject(entity: entity, insertInto: context)
                manga.setValue(mangaUUID, forKey: "id")
                manga.setValue(title, forKey: "title")
                manga.setValue(localFileName, forKey: "localFileName")
                manga.setValue(true, forKey: "importComplete")
                try context.save()
            }

            // Tear down the V2 container's store connection before reopening
            // under the current model.
            for store in v2Container.persistentStoreCoordinator.persistentStores {
                try v2Container.persistentStoreCoordinator.remove(store)
            }
        }

        // 3: open the CURRENT (V3) model at the same URL with automatic
        // lightweight migration enabled.
        let currentModel = CoreDataTestFactory.managedObjectModel(
            name: "MaruMangaData",
            bundle: Bundle(for: MangaDataPersistenceController.self)
        )
        let v3Container = try loadContainer(model: currentModel, storeURL: storeURL, migrate: true)

        // 4: assert the store loaded without error (implicit: loadContainer
        // above would have thrown), the row survived, and mokuroFileName
        // defaulted to nil on the migrated row.
        let viewContext = v3Container.viewContext
        let fetched: (id: UUID?, title: String?, localFileName: String?, importComplete: Bool, mokuroFileName: String?)? =
            try await viewContext.perform {
                let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", mangaUUID as CVarArg)
                request.fetchLimit = 1
                guard let manga = try viewContext.fetch(request).first else { return nil }
                return (manga.id, manga.title, manga.localFileName, manga.importComplete, manga.mokuroFileName)
            }

        let manga = try #require(fetched, "Migrated MangaArchive row should be present after migration")
        #expect(manga.id == mangaUUID)
        #expect(manga.title == title)
        #expect(manga.localFileName == localFileName)
        #expect(manga.importComplete == true)
        #expect(manga.mokuroFileName == nil, "New V3 attribute should default to nil on a migrated row")
    }
}
