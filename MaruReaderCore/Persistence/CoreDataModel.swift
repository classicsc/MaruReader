// CoreDataModel.swift
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

import BackgroundAssets
import CoreData
import os
import System

// MARK: - PersistenceController

/// Manages the Core Data stack with support for app groups and extensions
public final class DictionaryPersistenceController: Sendable {
    public static let shared = DictionaryPersistenceController()
    private static let logger = Logger.maru(category: "DictionaryPersistenceController")

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
        Self.configureViewContext(container.viewContext)
    }

    /// Initialize persistence controller
    /// - Parameters:
    ///   - storeURL: Custom store URL (if nil, uses app group default)
    public init(
        storeURL: URL? = nil
    ) {
        let bundle = Bundle(for: DictionaryPersistenceController.self)
        let model: NSManagedObjectModel
        #if DEBUG
            model = CoreDataTestFactory.managedObjectModel(name: "MaruDictionary", bundle: bundle)
        #else
            guard let modelURL = bundle.url(forResource: "MaruDictionary", withExtension: "momd") else {
                fatalError("Failed to locate momd file for MaruDictionary in framework bundle")
            }
            guard let loadedModel = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to load model from: \(modelURL)")
            }
            model = loadedModel
        #endif

        // Create container
        container = NSPersistentContainer(name: "MaruDictionary", managedObjectModel: model)

        // Set base directory from app group
        baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        )

        // Configure store location
        if let customURL = storeURL {
            // Custom URL provided
            container.persistentStoreDescriptions.first?.url = customURL
        } else {
            // Use app group container (default)
            if let baseDirectory {
                let storeURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
            } else {
                // Fallback to default location if app group not configured
                Self.logger.warning("App group '\(Self.appGroupIdentifier, privacy: .public)' not found. Using default location.")
            }
        }

        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

        let loadResult = Self.loadPersistentStores(for: container)
        if let loadFailure = loadResult.failure {
            let nsError = loadFailure.error as NSError
            fatalError(
                "Unresolved error loading persistent store at "
                    + "\(loadFailure.url?.path ?? "unknown"): \(nsError), \(nsError.userInfo)"
            )
        }

        Self.configureViewContext(container.viewContext)
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

    private struct PersistentStoreLoadFailure {
        let error: Error
        let url: URL?
    }

    private struct PersistentStoreLoadResult {
        let failure: PersistentStoreLoadFailure?
    }

    private static func loadPersistentStores(for container: NSPersistentContainer) -> PersistentStoreLoadResult {
        var failure: PersistentStoreLoadFailure?
        container.loadPersistentStores { description, error in
            if let error {
                failure = PersistentStoreLoadFailure(error: error, url: description.url)
            }
        }
        return PersistentStoreLoadResult(failure: failure)
    }

    private static func configureViewContext(_ context: NSManagedObjectContext) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    public static func removeStoreFiles(at storeURL: URL) {
        guard storeURL.isFileURL, storeURL.path != "/dev/null" else {
            return
        }

        let fileManager = FileManager.default
        let basePath = storeURL.path
        for suffix in ["", "-wal", "-shm"] {
            let filePath = basePath + suffix
            if fileManager.fileExists(atPath: filePath) {
                try? fileManager.removeItem(atPath: filePath)
            }
        }
    }

    // MARK: - Bundled Database Seeding

    /// Check whether the bundled dictionary still needs to be seeded.
    /// - Parameter baseDirectory: The app group container URL to seed into.
    /// - Returns: True when the starter database isn't present yet.
    public static func isBundledDatabaseSeedingNeeded(at baseDirectory: URL?) -> Bool {
        guard let baseDirectory else { return false }
        let destinationDB = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
        return !FileManager.default.fileExists(atPath: destinationDB.path)
    }

    /// Copy bundled starter dictionary to app group container if no database exists yet.
    /// - Parameter baseDirectory: The app group container URL to seed into.
    public static func seedBundledDatabaseIfNeeded(to baseDirectory: URL?) async {
        guard isBundledDatabaseSeedingNeeded(at: baseDirectory) else { return }

        await Task.detached(priority: .utility) {
            guard let baseDirectory else { return }

            let destinationDB = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
            let fileManager = FileManager.default

            // Skip if database already exists
            guard !fileManager.fileExists(atPath: destinationDB.path) else { return }

            let starterDictionaryDirectory: URL

            do {
                let assetPackManager = AssetPackManager.shared
                let assetPack = try await assetPackManager.assetPack(withID: "StarterDict")
                try await assetPackManager.ensureLocalAvailability(of: assetPack)
                starterDictionaryDirectory = try assetPackManager.url(for: System.FilePath("build/StarterDictionary"))
            } catch {
                Self.logger.warning("Failed to prepare StarterDict asset contents: \(error.localizedDescription, privacy: .public)")
                return
            }
            defer {
                Task {
                    do {
                        try await AssetPackManager.shared.remove(assetPackWithID: "StarterDict")
                    } catch {
                        Self.logger.warning("Failed to clean StarterDict asset: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }

            let assetPackDB = starterDictionaryDirectory.appendingPathComponent("MaruDictionary.sqlite")
            guard fileManager.fileExists(atPath: assetPackDB.path) else {
                Self.logger.warning("StarterDict asset is missing MaruDictionary.sqlite at \(assetPackDB.path, privacy: .public)")
                return
            }

            do {
                // Copy database file
                try fileManager.copyItem(at: assetPackDB, to: destinationDB)

                // Copy media directory if present (dictionary media)
                let bundleMediaDir = starterDictionaryDirectory.appendingPathComponent("Media")
                let destinationMediaDir = baseDirectory.appendingPathComponent("Media")

                if fileManager.fileExists(atPath: bundleMediaDir.path) {
                    try fileManager.copyItem(at: bundleMediaDir, to: destinationMediaDir)
                }

                // Copy audio media directory if present (audio source media)
                let bundleAudioMediaDir = starterDictionaryDirectory.appendingPathComponent("AudioMedia")
                let destinationAudioMediaDir = baseDirectory.appendingPathComponent("AudioMedia")

                if fileManager.fileExists(atPath: bundleAudioMediaDir.path) {
                    try fileManager.copyItem(at: bundleAudioMediaDir, to: destinationAudioMediaDir)
                }
            } catch {
                // Seeding is best-effort; log but don't crash
                Self.logger.warning("Failed to seed bundled dictionary: \(error.localizedDescription, privacy: .public)")
                // Clean up partial copy
                try? fileManager.removeItem(at: destinationDB)
            }
        }.value
    }
}

// MARK: - Preview Support

#if DEBUG
    public extension DictionaryPersistenceController {
        /// In-memory controller for SwiftUI previews
        @MainActor static let preview: DictionaryPersistenceController = .init(
            container: CoreDataTestFactory.makePersistentContainer(
                name: "MaruDictionary",
                bundle: Bundle(for: DictionaryPersistenceController.self),
                storeKind: .inMemory
            ),
            baseDirectory: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
            )
        )
    }
#endif
