// app.swift
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
import Foundation
import MaruReaderCore

enum SeederError: Error, LocalizedError {
    case modelNotFound
    case storeLoadFailed(Error)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            "Failed to locate MaruDictionary model in framework bundle"
        case let .storeLoadFailed(error):
            "Failed to load persistent store: \(error.localizedDescription)"
        case let .importFailed(message):
            "Import failed: \(message)"
        }
    }
}

struct ImportResult {
    let name: String
    let terms: Int64
    let kanji: Int64
    let status: String
}

@main
struct DictionarySeeder {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let outputDir = URL(fileURLWithPath: args[0], isDirectory: true)
        let zipPaths = args.dropFirst().map { URL(fileURLWithPath: $0) }

        // Validate input files exist
        for zipURL in zipPaths {
            guard FileManager.default.fileExists(atPath: zipURL.path) else {
                print("Error: Dictionary file not found: \(zipURL.path)")
                exit(1)
            }
        }

        do {
            // Create output directory structure
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let storeURL = outputDir.appendingPathComponent("MaruDictionary.sqlite")

            // Remove existing database if present
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = storeURL.deletingLastPathComponent()
                    .appendingPathComponent(storeURL.lastPathComponent + suffix)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }

            // Create container with WAL disabled
            let container = try createContainer(storeURL: storeURL)

            // Create import manager with custom base directory
            let importManager = DictionaryImportManager(
                container: container,
                baseDirectory: outputDir
            )

            var results: [ImportResult] = []

            for zipURL in zipPaths {
                print("Importing: \(zipURL.lastPathComponent)...")

                let jobID = try await importManager.enqueueImport(from: zipURL)
                await importManager.waitForCompletion(jobID: jobID)

                let result = try await getResult(container: container, jobID: jobID)
                results.append(result)
                print("  \(result.status): \(result.name) (\(result.terms) terms, \(result.kanji) kanji)")
            }

            printSummary(results: results)
            try verifyNoWAL(at: storeURL)

            print("\nOutput written to: \(outputDir.path)")

        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: DictionarySeeder <output-dir> <dictionary1.zip> [dictionary2.zip ...]

        Imports Yomitan dictionaries into a SQLite database suitable for bundling.

        Arguments:
          output-dir       Directory to write the database and media files
          dictionary.zip   One or more Yomitan dictionary ZIP files to import

        Output structure:
          output-dir/
            MaruDictionary.sqlite
            Media/
              {dictionaryUUID}/
                [media files...]
        """)
    }

    static func createContainer(storeURL: URL) throws -> NSPersistentContainer {
        let bundle = Bundle(for: DictionaryPersistenceController.self)
        guard let modelURL = bundle.url(forResource: "MaruDictionary", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw SeederError.modelNotFound
        }

        let container = NSPersistentContainer(name: "MaruDictionary", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)

        // Disable WAL mode so we get a single SQLite file
        description.setOption(
            ["journal_mode": "DELETE"] as NSDictionary,
            forKey: NSSQLitePragmasOption
        )

        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            throw SeederError.storeLoadFailed(error)
        }

        return container
    }

    static func getResult(container: NSPersistentContainer, jobID: NSManagedObjectID) async throws -> ImportResult {
        let context = container.newBackgroundContext()
        return try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw SeederError.importFailed("Could not fetch dictionary record")
            }

            let status = if dictionary.isComplete {
                "Completed"
            } else if dictionary.isFailed {
                "Failed: \(dictionary.errorMessage ?? "Unknown error")"
            } else if dictionary.isCancelled {
                "Cancelled"
            } else {
                "Unknown"
            }

            return ImportResult(
                name: dictionary.title ?? "Unknown",
                terms: dictionary.termCount,
                kanji: dictionary.kanjiCount,
                status: status
            )
        }
    }

    static func printSummary(results: [ImportResult]) {
        print("\n--- Summary ---")

        let completed = results.filter { $0.status == "Completed" }
        let failed = results.filter { $0.status != "Completed" }

        print("Imported: \(completed.count)/\(results.count) dictionaries")

        if !failed.isEmpty {
            print("\nFailed imports:")
            for result in failed {
                print("  - \(result.name): \(result.status)")
            }
        }

        let totalTerms = completed.reduce(0) { $0 + $1.terms }
        let totalKanji = completed.reduce(0) { $0 + $1.kanji }
        print("\nTotal entries: \(totalTerms) terms, \(totalKanji) kanji")
    }

    static func verifyNoWAL(at storeURL: URL) throws {
        let walURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent(storeURL.lastPathComponent + "-wal")
        let shmURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent(storeURL.lastPathComponent + "-shm")

        if FileManager.default.fileExists(atPath: walURL.path) ||
            FileManager.default.fileExists(atPath: shmURL.path)
        {
            print("Warning: WAL files exist. Database may not be fully consolidated.")
        } else {
            print("Database verified: No WAL files present.")
        }
    }
}
