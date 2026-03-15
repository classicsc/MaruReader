// CoreDataTestFactory.swift
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

#if DEBUG
    import CoreData
    import Foundation

    public enum CoreDataTestStoreKind: Sendable {
        case inMemory
        case temporarySQLite
    }

    public enum CoreDataTestFactory {
        private struct ModelCacheKey: Hashable {
            let name: String
            let bundleURL: URL
        }

        private final class ModelCache: @unchecked Sendable {
            let lock = NSLock()
            var models: [ModelCacheKey: NSManagedObjectModel] = [:]
        }

        private static let modelCache = ModelCache()

        public static func makePersistentContainer(
            name: String,
            bundle: Bundle,
            storeKind: CoreDataTestStoreKind = .inMemory,
            storeURL: URL? = nil
        ) -> NSPersistentContainer {
            let model = managedObjectModel(name: name, bundle: bundle)
            let container = NSPersistentContainer(name: name, managedObjectModel: model)
            container.persistentStoreDescriptions = [
                persistentStoreDescription(name: name, storeKind: storeKind, storeURL: storeURL),
            ]
            loadPersistentStores(for: container)
            return container
        }

        public static func managedObjectModel(name: String, bundle: Bundle) -> NSManagedObjectModel {
            let key = ModelCacheKey(name: name, bundleURL: bundle.bundleURL)

            modelCache.lock.lock()
            defer { modelCache.lock.unlock() }

            if let cachedModel = modelCache.models[key] {
                return cachedModel
            }

            guard let modelURL = bundle.url(forResource: name, withExtension: "momd") else {
                fatalError("Failed to locate momd file for \(name) in bundle: \(bundle.bundleURL.path)")
            }
            guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to load model from: \(modelURL)")
            }

            modelCache.models[key] = model
            return model
        }

        private static func persistentStoreDescription(
            name: String,
            storeKind: CoreDataTestStoreKind,
            storeURL: URL?
        ) -> NSPersistentStoreDescription {
            let description = NSPersistentStoreDescription()
            description.shouldAddStoreAsynchronously = false
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true

            switch storeKind {
            case .inMemory:
                description.type = NSInMemoryStoreType
                description.url = nil
            case .temporarySQLite:
                description.type = NSSQLiteStoreType
                description.url = storeURL ?? makeTemporarySQLiteURL(name: name)
            }

            return description
        }

        private static func loadPersistentStores(for container: NSPersistentContainer) {
            var loadFailure: (error: Error, url: URL?)?
            container.loadPersistentStores { description, error in
                if let error {
                    loadFailure = (error, description.url)
                }
            }

            if let loadFailure {
                let nsError = loadFailure.error as NSError
                fatalError(
                    "Unresolved error loading persistent store at "
                        + "\(loadFailure.url?.path ?? "unknown"): \(nsError), \(nsError.userInfo)"
                )
            }
        }

        private static func makeTemporarySQLiteURL(name: String) -> URL {
            let directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("CoreDataTests", isDirectory: true)
                .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                fatalError("Failed to create temporary Core Data directory at \(directoryURL.path): \(error)")
            }

            return directoryURL.appendingPathComponent("\(name).sqlite")
        }
    }
#endif
