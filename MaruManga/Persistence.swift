// Persistence.swift
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
import MaruReaderCore

// MARK: - PersistenceController

/// Manages the app-only Core Data stack for the manga subsystem.
public final class MangaDataPersistenceController: Sendable {
    public static let shared = MangaDataPersistenceController()

    // MARK: - Properties

    public let container: NSPersistentContainer

    // MARK: - Initialization

    public init(container: NSPersistentContainer) {
        self.container = container
        Self.configureViewContext(container.viewContext)
    }

    /// Initialize persistence controller
    /// - Parameters:
    ///   - storeURL: Custom store URL (if nil, uses the app container default)
    init(
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: MangaDataPersistenceController.self)
        let model: NSManagedObjectModel
        #if DEBUG
            model = CoreDataTestFactory.managedObjectModel(name: "MaruMangaData", bundle: bundle)
        #else
            guard let modelURL = bundle.url(forResource: "MaruMangaData", withExtension: "momd") else {
                fatalError("Failed to locate momd file for MaruMangaData in framework bundle")
            }
            guard let loadedModel = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to load model from: \(modelURL)")
            }
            model = loadedModel
        #endif

        // Create container
        container = NSPersistentContainer(name: "MaruMangaData", managedObjectModel: model)

        // Configure store location
        if let customURL = storeURL {
            // Custom URL provided
            container.persistentStoreDescriptions.first?.url = customURL
        } else {
            container.persistentStoreDescriptions.first?.url = Self.defaultStoreURL()
        }

        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error {
                let nsError = error as NSError
                fatalError("Unresolved error loading store at \(description.url?.path ?? "unknown"): \(nsError), \(nsError.userInfo)")
            }
        }

        Self.configureViewContext(container.viewContext)
    }

    // MARK: - Context Creation

    /// Create a new background context for batch operations
    /// - Returns: A configured background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }

    private static func configureViewContext(_ context: NSManagedObjectContext) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    private static func defaultStoreURL() -> URL {
        do {
            let appSupportDir = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupportDir.appendingPathComponent("MaruMangaData.sqlite")
        } catch {
            fatalError("Failed to resolve Application Support directory for MaruMangaData: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension MangaDataPersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: MangaDataPersistenceController = .init(
            container: CoreDataTestFactory.makePersistentContainer(
                name: "MaruMangaData",
                bundle: Bundle(for: MangaDataPersistenceController.self),
                storeKind: .inMemory
            )
        )
    }
#endif
