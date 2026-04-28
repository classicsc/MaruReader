// PersistenceController.swift
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
import os

// MARK: - PersistenceController

/// Manages the Core Data stack with support for app groups and extensions
public final class AnkiPersistenceController: Sendable {
    public static let shared = AnkiPersistenceController()
    private static let logger = Logger.maru(category: "AnkiPersistenceController")

    // MARK: - App Group Configuration

    /// App group identifier for sharing data between app and extensions
    public static let appGroupIdentifier = "group.net.undefinedstar.MaruReader"

    // MARK: - Properties

    public let container: NSPersistentContainer

    // MARK: - Initialization

    public init(container: NSPersistentContainer) {
        self.container = container
        Self.configureViewContext(container.viewContext)
    }

    /// Initialize persistence controller
    /// - Parameters:
    ///   - storeURL: Custom store URL (if nil, uses app group default)
    public init(
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: AnkiPersistenceController.self)
        let model: NSManagedObjectModel
        #if DEBUG
            model = CoreDataTestFactory.managedObjectModel(name: "MaruAnki", bundle: bundle)
        #else
            guard let modelURL = bundle.url(forResource: "MaruAnki", withExtension: "momd") else {
                fatalError("Failed to locate momd file for MaruAnki in framework bundle")
            }
            guard let loadedModel = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to load model from: \(modelURL)")
            }
            model = loadedModel
        #endif

        // Create container
        container = NSPersistentContainer(name: "MaruAnki", managedObjectModel: model)

        // Configure store location
        if let customURL = storeURL {
            // Custom URL provided
            container.persistentStoreDescriptions.first?.url = customURL
        } else {
            // Use app group container (default)
            if let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            ) {
                let storeURL = appGroupURL.appendingPathComponent("MaruAnki.sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
            } else {
                // Fallback to default location if app group not configured
                Self.logger.warning("App group '\(Self.appGroupIdentifier, privacy: .public)' not found. Using default location.")
            }
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
    public static func warmShared() async {
        await Task.detached(priority: .userInitiated) {
            _ = AnkiPersistenceController.shared
        }.value
    }

    /// Create a new background context for batch operations
    /// - Returns: A configured background context
    public func newBackgroundContext() -> NSManagedObjectContext {
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
}

// MARK: - Preview Support

#if DEBUG
    public extension AnkiPersistenceController {
        /// SQLite-backed controller for SwiftUI previews because composite attributes
        /// are not supported by Core Data's atomic/in-memory stores.
        @MainActor static let preview: AnkiPersistenceController = .init(
            container: CoreDataTestFactory.makePersistentContainer(
                name: "MaruAnki",
                bundle: Bundle(for: AnkiPersistenceController.self),
                storeKind: .temporarySQLite
            )
        )
    }
#endif
