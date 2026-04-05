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
    private static let bundledDatabaseSeedCompletionMarkerFileName = ".bundled-dictionary-seed-complete"
    #if DEBUG
        private static let suppressBundledStarterDictionaryLaunchArgument = "--disableBundledStarterDictionaryFallback"
    #endif

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

    /// Returns the completion marker used to determine whether bundled seeding finished.
    static func bundledDatabaseSeedCompletionMarkerURL(in baseDirectory: URL) -> URL {
        baseDirectory.appendingPathComponent(bundledDatabaseSeedCompletionMarkerFileName)
    }

    /// Check whether the bundled dictionary still needs to be seeded.
    /// The completion marker is the only signal that bundled seeding finished.
    /// - Parameter baseDirectory: The app group container URL to seed into.
    /// - Returns: True when the bundled seed completion marker isn't present yet.
    public static func isBundledDatabaseSeedingNeeded(at baseDirectory: URL?) -> Bool {
        guard let baseDirectory else { return false }
        let markerURL = bundledDatabaseSeedCompletionMarkerURL(in: baseDirectory)
        return !FileManager.default.fileExists(atPath: markerURL.path)
    }

    /// Copy bundled starter dictionary to app group container if seeding has not completed yet.
    /// The completion marker is written only after all copy work succeeds.
    /// - Parameter baseDirectory: The app group container URL to seed into.
    public static func seedBundledDatabaseIfNeeded(to baseDirectory: URL?) async {
        guard isBundledDatabaseSeedingNeeded(at: baseDirectory) else { return }

        await Task.detached(priority: .utility) {
            guard let baseDirectory else { return }

            let fileManager = FileManager.default

            let completionMarkerURL = bundledDatabaseSeedCompletionMarkerURL(in: baseDirectory)
            guard !fileManager.fileExists(atPath: completionMarkerURL.path) else { return }

            let starterDictionaryDirectory: URL
            var shouldRemoveAssetPack = false

            #if DEBUG
                if let bundledStarterDictionaryDirectory = bundledStarterDictionaryDirectory() {
                    starterDictionaryDirectory = bundledStarterDictionaryDirectory
                } else {
                    do {
                        let assetPackManager = AssetPackManager.shared
                        let assetPack = try await assetPackManager.assetPack(withID: "StarterDict")
                        try await assetPackManager.ensureLocalAvailability(of: assetPack)
                        starterDictionaryDirectory = try assetPackManager.url(for: System.FilePath("build/StarterDictionary"))
                        shouldRemoveAssetPack = true
                    } catch {
                        Self.logger.warning("Failed to prepare StarterDict asset contents: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                }
            #else
                do {
                    let assetPackManager = AssetPackManager.shared
                    let assetPack = try await assetPackManager.assetPack(withID: "StarterDict")
                    try await assetPackManager.ensureLocalAvailability(of: assetPack)
                    starterDictionaryDirectory = try assetPackManager.url(for: System.FilePath("build/StarterDictionary"))
                    shouldRemoveAssetPack = true
                } catch {
                    Self.logger.warning("Failed to prepare StarterDict asset contents: \(error.localizedDescription, privacy: .public)")
                    return
                }
            #endif

            defer {
                if shouldRemoveAssetPack {
                    Task {
                        do {
                            try await AssetPackManager.shared.remove(assetPackWithID: "StarterDict")
                        } catch {
                            Self.logger.warning("Failed to clean StarterDict asset: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }

            do {
                try performBundledSeedCopy(from: starterDictionaryDirectory, to: baseDirectory, fileManager: fileManager)
            } catch {
                // Seeding is best-effort; log but don't crash
                Self.logger.warning("Failed to seed bundled dictionary: \(error.localizedDescription, privacy: .public)")
            }
        }.value
    }

    static func performBundledSeedCopy(from starterDictionaryDirectory: URL, to baseDirectory: URL, fileManager: FileManager = .default) throws {
        try removeBundledSeedContents(at: baseDirectory, fileManager: fileManager)

        do {
            try copyStarterDictionaryContents(from: starterDictionaryDirectory, to: baseDirectory, fileManager: fileManager)
            try writeBundledDatabaseSeedCompletionMarker(at: baseDirectory, fileManager: fileManager)
        } catch {
            try? removeBundledSeedContents(at: baseDirectory, fileManager: fileManager)
            throw error
        }
    }

    static func copyStarterDictionaryContents(from starterDictionaryDirectory: URL, to baseDirectory: URL, fileManager: FileManager = .default) throws {
        let sourceDB = starterDictionaryDirectory.appendingPathComponent("MaruDictionary.sqlite")
        guard fileManager.fileExists(atPath: sourceDB.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: sourceDB.path])
        }

        let destinationDB = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
        try fileManager.copyItem(at: sourceDB, to: destinationDB)

        let sourceMediaDir = starterDictionaryDirectory.appendingPathComponent("Media")
        let destinationMediaDir = baseDirectory.appendingPathComponent("Media")
        if fileManager.fileExists(atPath: sourceMediaDir.path) {
            try fileManager.copyItem(at: sourceMediaDir, to: destinationMediaDir)
        }

        let sourceAudioMediaDir = starterDictionaryDirectory.appendingPathComponent("AudioMedia")
        let destinationAudioMediaDir = baseDirectory.appendingPathComponent("AudioMedia")
        if fileManager.fileExists(atPath: sourceAudioMediaDir.path) {
            try fileManager.copyItem(at: sourceAudioMediaDir, to: destinationAudioMediaDir)
        }

        let sourceCompressionDictionaryDir = starterDictionaryDirectory.appendingPathComponent(
            GlossaryCompressionCodec.zstdDictionaryDirectoryName
        )
        let destinationCompressionDictionaryDir = baseDirectory.appendingPathComponent(
            GlossaryCompressionCodec.zstdDictionaryDirectoryName
        )
        if fileManager.fileExists(atPath: sourceCompressionDictionaryDir.path) {
            try fileManager.copyItem(at: sourceCompressionDictionaryDir, to: destinationCompressionDictionaryDir)
        }
    }

    static func writeBundledDatabaseSeedCompletionMarker(at baseDirectory: URL, fileManager: FileManager = .default) throws {
        let markerURL = bundledDatabaseSeedCompletionMarkerURL(in: baseDirectory)
        if fileManager.fileExists(atPath: markerURL.path) {
            try fileManager.removeItem(at: markerURL)
        }

        try Data().write(to: markerURL, options: .atomic)
    }

    static func removeBundledSeedContents(at baseDirectory: URL, fileManager: FileManager = .default) throws {
        removeStoreFiles(at: baseDirectory.appendingPathComponent("MaruDictionary.sqlite"))

        for directoryName in [
            "Media",
            "AudioMedia",
            GlossaryCompressionCodec.zstdDictionaryDirectoryName,
        ] {
            let directoryURL = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.removeItem(at: directoryURL)
            }
        }

        let markerURL = bundledDatabaseSeedCompletionMarkerURL(in: baseDirectory)
        if fileManager.fileExists(atPath: markerURL.path) {
            try fileManager.removeItem(at: markerURL)
        }
    }

    #if DEBUG
        private static func bundledStarterDictionaryDirectory(
            processArguments: [String] = ProcessInfo.processInfo.arguments,
            mainBundle: Bundle = .main
        ) -> URL? {
            guard !processArguments.contains(suppressBundledStarterDictionaryLaunchArgument) else {
                return nil
            }
            return mainBundle.url(forResource: "StarterDictionary", withExtension: nil)
        }
    #endif
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
