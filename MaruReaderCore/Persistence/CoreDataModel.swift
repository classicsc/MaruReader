//
//  CoreDataModel.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/23/25.
//

import CoreData

// MARK: - PersistenceController

/// Manages the Core Data stack with support for app groups and extensions
public final class PersistenceController: Sendable {
    public static let shared = PersistenceController()

    // MARK: - App Group Configuration

    /// App group identifier for sharing data between app and extensions
    public static let appGroupIdentifier = "group.net.undefinedstar.MaruReader"

    // MARK: - Properties

    public let container: NSPersistentContainer

    // MARK: - Initialization

    /// Initialize persistence controller
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing)
    ///   - storeURL: Custom store URL (if nil, uses app group default)
    public init(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: PersistenceController.self)
        guard let modelURL = bundle.url(forResource: "MaruReader", withExtension: "momd") else {
            fatalError("Failed to locate momd file for MaruReader in framework bundle")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load model from: \(modelURL)")
        }

        // Create container
        container = NSPersistentContainer(name: "MaruReader", managedObjectModel: model)

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
                let storeURL = appGroupURL.appendingPathComponent("MaruReader.sqlite")
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
    public extension PersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: PersistenceController = .init(inMemory: true)
    }
#endif
