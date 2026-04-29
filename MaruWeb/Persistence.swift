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

// MARK: - Public Async Warmup

/// Force MaruWeb's persistent store to load on a background thread.
///
/// MaruReader calls this from its startup pipeline so that the synchronous
/// `loadPersistentStores` call in `WebDataPersistenceController` (and any
/// migration it triggers) does not block the main thread on launch.
public enum MaruWebPersistenceWarmup {
    public static func warmShared() async {
        await WebDataPersistenceController.warmShared()
    }
}

// MARK: - PersistenceController

/// Manages the app-only Core Data stack for web content.
final class WebDataPersistenceController: Sendable {
    static let shared = WebDataPersistenceController()

    // MARK: - Properties

    let container: NSPersistentContainer

    // MARK: - Initialization

    init(container: NSPersistentContainer) {
        self.container = container
        Self.configureViewContext(container.viewContext)
    }

    /// Initialize persistence controller
    /// - Parameters:
    ///   - storeURL: Custom store URL (if nil, uses the app container default)
    init(
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: WebDataPersistenceController.self)
        let model: NSManagedObjectModel
        #if DEBUG
            model = CoreDataTestFactory.managedObjectModel(name: "MaruWebData", bundle: bundle)
        #else
            guard let modelURL = bundle.url(forResource: "MaruWebData", withExtension: "momd") else {
                fatalError("Failed to locate momd file for MaruWebData in framework bundle")
            }
            guard let loadedModel = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to load model from: \(modelURL)")
            }
            model = loadedModel
        #endif

        // Create container
        container = NSPersistentContainer(name: "MaruWebData", managedObjectModel: model)

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

    /// Force the lazy `shared` initializer (and its synchronous Core Data store
    /// loading, which may include a migration) to run off the main thread.
    ///
    /// Call this from an async startup pipeline before any UI or main-thread
    /// caller touches `shared`, to avoid a launch watchdog kill on first
    /// launch after a migration.
    static func warmShared() async {
        await Task.detached(priority: .userInitiated) {
            _ = WebDataPersistenceController.shared
        }.value
    }

    /// Create a new background context for batch operations
    /// - Returns: A configured background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }

    private static func configureViewContext(_ context: NSManagedObjectContext) {
        context.performAndWait {
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        }
    }

    private static func defaultStoreURL() -> URL {
        do {
            let appSupportDir = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupportDir.appendingPathComponent("MaruWebData.sqlite")
        } catch {
            fatalError("Failed to resolve Application Support directory for MaruWebData: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension WebDataPersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: WebDataPersistenceController = .init(
            container: CoreDataTestFactory.makePersistentContainer(
                name: "MaruWebData",
                bundle: Bundle(for: WebDataPersistenceController.self),
                storeKind: .inMemory
            )
        )
    }
#endif
