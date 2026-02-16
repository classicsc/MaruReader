// app.swift
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

struct AudioSourceResult {
    let name: String
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

        // Parse remaining arguments, separating dictionaries from audio sources
        var dictionaryPaths: [URL] = []
        var audioSourcePaths: [URL] = []
        var expectAudio = false

        for arg in args.dropFirst() {
            if arg == "--audio" {
                expectAudio = true
            } else {
                let url = URL(fileURLWithPath: arg)
                if expectAudio {
                    audioSourcePaths.append(url)
                    expectAudio = false
                } else {
                    dictionaryPaths.append(url)
                }
            }
        }

        // Validate input files exist
        for zipURL in dictionaryPaths + audioSourcePaths {
            guard FileManager.default.fileExists(atPath: zipURL.path) else {
                print("Error: File not found: \(zipURL.path)")
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

            var dictionaryResults: [ImportResult] = []
            var audioResults: [AudioSourceResult] = []

            // Import dictionaries
            if !dictionaryPaths.isEmpty {
                let importManager = DictionaryImportManager(
                    container: container,
                    baseDirectory: outputDir
                )

                for zipURL in dictionaryPaths {
                    print("Importing dictionary: \(zipURL.lastPathComponent)...")

                    let jobID = try await importManager.enqueueImport(from: zipURL)
                    await importManager.waitForCompletion(jobID: jobID)

                    let result = try await getDictionaryResult(container: container, jobID: jobID)
                    dictionaryResults.append(result)
                    print("  \(result.status): \(result.name) (\(result.terms) terms, \(result.kanji) kanji)")
                }
            }

            // Import audio sources
            if !audioSourcePaths.isEmpty {
                let audioImportManager = AudioSourceImportManager(
                    container: container,
                    baseDirectory: outputDir
                )

                for zipURL in audioSourcePaths {
                    print("Importing audio source: \(zipURL.lastPathComponent)...")

                    let jobID = try await audioImportManager.enqueueImport(from: zipURL)
                    await audioImportManager.waitForCompletion(jobID: jobID)

                    let result = try await getAudioSourceResult(container: container, jobID: jobID)
                    audioResults.append(result)
                    print("  \(result.status): \(result.name)")
                }
            }

            printSummary(dictionaryResults: dictionaryResults, audioResults: audioResults)
            try verifyNoWAL(at: storeURL)

            print("\nOutput written to: \(outputDir.path)")

        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: DictionarySeeder <output-dir> <dictionary1.zip> [dictionary2.zip ...] [--audio <audio.zip>] ...

        Imports Yomitan dictionaries and audio sources into a SQLite database suitable for bundling.

        Arguments:
          output-dir       Directory to write the database and media files
          dictionary.zip   One or more Yomitan dictionary ZIP files to import
          --audio <file>   Specify the next ZIP file as an indexed audio source

        Output structure:
          output-dir/
            MaruDictionary.sqlite
            Media/
              {dictionaryUUID}/
                [media files...]
            AudioMedia/
              {audioSourceUUID}/
                [audio files...]

        Example:
          DictionarySeeder ./StarterDictionary jmdict.zip --audio kanjialive.zip
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

    static func getDictionaryResult(container: NSPersistentContainer, jobID: NSManagedObjectID) async throws -> ImportResult {
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

    static func getAudioSourceResult(container: NSPersistentContainer, jobID: NSManagedObjectID) async throws -> AudioSourceResult {
        let context = container.newBackgroundContext()
        return try await context.perform {
            guard let audioSource = try? context.existingObject(with: jobID) as? AudioSource else {
                throw SeederError.importFailed("Could not fetch audio source record")
            }

            let status = if audioSource.isComplete {
                "Completed"
            } else if audioSource.isFailed {
                "Failed: \(audioSource.displayProgressMessage ?? "Unknown error")"
            } else if audioSource.isCancelled {
                "Cancelled"
            } else {
                "Unknown"
            }

            return AudioSourceResult(
                name: audioSource.name ?? "Unknown",
                status: status
            )
        }
    }

    static func printSummary(dictionaryResults: [ImportResult], audioResults: [AudioSourceResult]) {
        print("\n--- Summary ---")

        // Dictionary summary
        if !dictionaryResults.isEmpty {
            let completed = dictionaryResults.filter { $0.status == "Completed" }
            let failed = dictionaryResults.filter { $0.status != "Completed" }

            print("Dictionaries: \(completed.count)/\(dictionaryResults.count) imported")

            if !failed.isEmpty {
                print("\nFailed dictionary imports:")
                for result in failed {
                    print("  - \(result.name): \(result.status)")
                }
            }

            let totalTerms = completed.reduce(0) { $0 + $1.terms }
            let totalKanji = completed.reduce(0) { $0 + $1.kanji }
            print("Total dictionary entries: \(totalTerms) terms, \(totalKanji) kanji")
        }

        // Audio source summary
        if !audioResults.isEmpty {
            let completed = audioResults.filter { $0.status == "Completed" }
            let failed = audioResults.filter { $0.status != "Completed" }

            print("Audio sources: \(completed.count)/\(audioResults.count) imported")

            if !failed.isEmpty {
                print("\nFailed audio source imports:")
                for result in failed {
                    print("  - \(result.name): \(result.status)")
                }
            }
        }
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
