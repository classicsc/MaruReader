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

// MARK: - PersistenceController

/// Manages the Core Data stack with support for app groups and extensions
final class BookDataPersistenceController: Sendable {
    static let shared = BookDataPersistenceController()

    // MARK: - App Group Configuration

    /// App group identifier for sharing data between app and extensions
    static let appGroupIdentifier = "group.net.undefinedstar.MaruReader"

    // MARK: - Properties

    let container: NSPersistentContainer

    // MARK: - Initialization

    /// Initialize persistence controller
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing)
    ///   - storeURL: Custom store URL (if nil, uses app group default)
    init(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) {
        CoreDataTransformers.register()
        let bundle = Bundle(for: BookDataPersistenceController.self)
        guard let modelURL = bundle.url(forResource: "MaruBookData", withExtension: "momd") else {
            fatalError("Failed to locate momd file for MaruBookData in framework bundle")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load model from: \(modelURL)")
        }

        // Create container
        container = NSPersistentContainer(name: "MaruBookData", managedObjectModel: model)

        // Configure store location
        if inMemory {
            // In-memory store for testing
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let customURL = storeURL {
            // Custom URL provided
            container.persistentStoreDescriptions.first?.url = customURL
        } else {
            // Use app group container (default)
            if let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            ) {
                let storeURL = appGroupURL.appendingPathComponent("MaruBookData.sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
            } else {
                // Fallback to default location if app group not configured
                print("Warning: App group '\(Self.appGroupIdentifier)' not found. Using default location.")
            }
        }

        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error {
                let nsError = error as NSError
                fatalError("Unresolved error loading store at \(description.url?.path ?? "unknown"): \(nsError), \(nsError.userInfo)")
            }
        }

        // Configure container
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
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
}

// MARK: - Preview Support

#if DEBUG
    extension BookDataPersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: BookDataPersistenceController = .init(inMemory: true)
    }
#endif
