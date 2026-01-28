// CoreDataModel.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData

// MARK: - PersistenceController

/// Manages the Core Data stack with support for app groups and extensions
public final class DictionaryPersistenceController: Sendable {
    public static let shared = DictionaryPersistenceController()

    // MARK: - App Group Configuration

    /// App group identifier for sharing data between app and extensions
    public static let appGroupIdentifier = "group.net.undefinedstar.MaruReader"

    // MARK: - Properties

    public let container: NSPersistentContainer

    /// Base directory for media and other files. Defaults to the app group container.
    public let baseDirectory: URL?

    /// Media directory URL derived from the base directory.
    public var mediaDirectory: URL? {
        baseDirectory?.appendingPathComponent("Media")
    }

    // MARK: - Initialization

    /// Initialize persistence controller with a pre-configured container and base directory.
    /// Used by the seeder tool to avoid app group requirements.
    /// - Parameters:
    ///   - container: A pre-configured NSPersistentContainer.
    ///   - baseDirectory: The base directory for media files.
    public init(container: NSPersistentContainer, baseDirectory: URL?) {
        self.container = container
        self.baseDirectory = baseDirectory
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// Initialize persistence controller
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing)
    ///   - storeURL: Custom store URL (if nil, uses app group default)
    public init(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: DictionaryPersistenceController.self)
        guard let modelURL = bundle.url(forResource: "MaruDictionary", withExtension: "momd") else {
            fatalError("Failed to locate momd file for MaruDictionary in framework bundle")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load model from: \(modelURL)")
        }

        // Create container
        container = NSPersistentContainer(name: "MaruDictionary", managedObjectModel: model)

        // Set base directory from app group
        baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        )

        // Configure store location
        if inMemory {
            // In-memory store for testing
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let customURL = storeURL {
            // Custom URL provided
            container.persistentStoreDescriptions.first?.url = customURL
        } else {
            // Use app group container (default)
            if let baseDirectory {
                let storeURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
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
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
}

// MARK: - Preview Support

#if DEBUG
    public extension DictionaryPersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: DictionaryPersistenceController = .init(inMemory: true)
    }
#endif
