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
import MaruDictionaryManagement
import MaruReaderCore

enum SeederError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidGlossaryCodec(String)
    case invalidGlossaryTrainingProfile(String)
    case modelNotFound
    case storeLoadFailed(Error)
    case importFailed(String)
    case missingCompressionDictionary(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message):
            message
        case let .invalidGlossaryCodec(message):
            "Invalid glossary codec: \(message)"
        case let .invalidGlossaryTrainingProfile(message):
            "Invalid glossary training profile: \(message)"
        case .modelNotFound:
            "Failed to locate MaruDictionary model in framework bundle"
        case let .storeLoadFailed(error):
            "Failed to load persistent store: \(error.localizedDescription)"
        case let .importFailed(message):
            "Import failed: \(message)"
        case let .missingCompressionDictionary(message):
            "Missing compression dictionary: \(message)"
        }
    }
}

struct ImportResult {
    let id: UUID?
    let name: String
    let terms: Int64
    let kanji: Int64
    let status: String
}

struct AudioSourceResult {
    let name: String
    let status: String
}

struct TokenizerDictionaryResult {
    let name: String
    let version: String?
    let status: String
}

enum PendingSeedArgument {
    case audio
    case tokenizer
    case glossaryCodec
    case glossaryTrainingProfile

    var flagName: String {
        switch self {
        case .audio:
            "--audio"
        case .tokenizer:
            "--tokenizer"
        case .glossaryCodec:
            "--glossary-codec"
        case .glossaryTrainingProfile:
            "--glossary-training-profile"
        }
    }
}

struct SeedArguments {
    let outputDir: URL
    let dictionaryPaths: [URL]
    let audioSourcePaths: [URL]
    let tokenizerDictionaryPaths: [URL]
    let glossaryCompressionVersion: GlossaryCompressionCodecVersion
    let glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile
}

@main
struct DictionarySeeder {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard !args.isEmpty else {
            printUsage()
            exit(1)
        }

        do {
            let arguments = try parseArguments(args)
            try await runSeedCommand(arguments)
        } catch {
            print("Error: \(describe(error))")
            exit(1)
        }
    }

    static func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty
        {
            return description
        }

        return String(reflecting: error)
    }

    static func printUsage() {
        let supportedCodecs = GlossaryCompressionCodecVersion.allCases.map(\.rawValue).joined(separator: ", ")

        print(
            """
            Usage:
              DictionarySeeder <output-dir> <dictionary1.zip> [dictionary2.zip ...] [options]

            Imports Yomitan dictionaries, audio sources, and tokenizer dictionaries into a SQLite database suitable for bundling.

            Seed mode arguments:
              output-dir                    Directory to write the database and media files
              dictionary.zip                One or more Yomitan dictionary ZIP files to import
              --audio <file>                Specify the next ZIP file as an indexed audio source
              --tokenizer <file>            Specify the next ZIP file as a tokenizer dictionary package
              --glossary-codec <version>    Supported codecs: \(supportedCodecs)
                                            Default: \(GlossaryCompressionCodec.defaultImportVersion.rawValue)
              --glossary-training-profile   Supported profiles: \(GlossaryCompressionTrainingProfile.allCases.map(\.rawValue).joined(separator: ", "))
                                            Default: \(GlossaryCompressionTrainingProfile.runtime.rawValue)

            Seed output structure:
              output-dir/
                MaruDictionary.sqlite
                CompressionDictionaries/
                  <dictionary>.zdict
                Media/
                  {dictionaryUUID}/
                    [media files...]
                AudioMedia/
                  {audioSourceUUID}/
                    [audio files...]
                TokenizerDictionary/
                  index.json
                  [Sudachi resource files...]

            Examples:
              DictionarySeeder ./StarterDictionary jitendex.zip --audio kanjialive.zip --glossary-codec zstd-runtime-v1 --glossary-training-profile starterdict
            """
        )
    }

    static func parseArguments(_ args: [String]) throws -> SeedArguments {
        guard args.count >= 2 else {
            throw SeederError.invalidArguments(
                "Seed mode requires an output directory and at least one dictionary ZIP."
            )
        }

        let outputDir = URL(fileURLWithPath: args[0], isDirectory: true)

        var dictionaryPaths: [URL] = []
        var audioSourcePaths: [URL] = []
        var tokenizerDictionaryPaths: [URL] = []
        var glossaryCompressionVersion = GlossaryCompressionCodec.defaultImportVersion
        var glossaryCompressionTrainingProfile = GlossaryCompressionTrainingProfile.runtime
        var pendingArgument: PendingSeedArgument?

        for arg in args.dropFirst() {
            if let activePendingArgument = pendingArgument {
                switch activePendingArgument {
                case .audio:
                    audioSourcePaths.append(URL(fileURLWithPath: arg))
                case .tokenizer:
                    tokenizerDictionaryPaths.append(URL(fileURLWithPath: arg))
                case .glossaryCodec:
                    glossaryCompressionVersion = try parseGlossaryCompressionVersion(arg)
                case .glossaryTrainingProfile:
                    glossaryCompressionTrainingProfile = try parseGlossaryCompressionTrainingProfile(arg)
                }
                pendingArgument = nil
                continue
            }

            switch arg {
            case "--audio":
                pendingArgument = .audio
            case "--tokenizer":
                pendingArgument = .tokenizer
            case "--glossary-codec":
                pendingArgument = .glossaryCodec
            case "--glossary-training-profile":
                pendingArgument = .glossaryTrainingProfile
            default:
                if arg.hasPrefix("--") {
                    throw SeederError.invalidArguments("Unknown option: \(arg)")
                }
                dictionaryPaths.append(URL(fileURLWithPath: arg))
            }
        }

        if let pendingArgument {
            throw SeederError.invalidArguments("Missing value for \(pendingArgument.flagName)")
        }

        if dictionaryPaths.isEmpty {
            throw SeederError.invalidArguments("At least one dictionary ZIP is required.")
        }

        return SeedArguments(
            outputDir: outputDir,
            dictionaryPaths: dictionaryPaths,
            audioSourcePaths: audioSourcePaths,
            tokenizerDictionaryPaths: tokenizerDictionaryPaths,
            glossaryCompressionVersion: glossaryCompressionVersion,
            glossaryCompressionTrainingProfile: glossaryCompressionTrainingProfile
        )
    }

    static func parseGlossaryCompressionVersion(_ rawValue: String) throws -> GlossaryCompressionCodecVersion {
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let version = GlossaryCompressionCodecVersion(rawValue: normalizedValue) else {
            throw SeederError.invalidGlossaryCodec(rawValue)
        }
        return version
    }

    static func parseGlossaryCompressionTrainingProfile(_ rawValue: String) throws -> GlossaryCompressionTrainingProfile {
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let profile = GlossaryCompressionTrainingProfile(rawValue: normalizedValue) else {
            throw SeederError.invalidGlossaryTrainingProfile(rawValue)
        }
        return profile
    }

    static func runSeedCommand(_ arguments: SeedArguments) async throws {
        try validateInputFiles(arguments.dictionaryPaths + arguments.audioSourcePaths + arguments.tokenizerDictionaryPaths)

        try FileManager.default.createDirectory(at: arguments.outputDir, withIntermediateDirectories: true)

        let storeURL = arguments.outputDir.appendingPathComponent("MaruDictionary.sqlite")

        for suffix in ["", "-wal", "-shm"] {
            let fileURL = storeURL.deletingLastPathComponent()
                .appendingPathComponent(storeURL.lastPathComponent + suffix)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }

        let container = try createContainer(storeURL: storeURL)
        var dictionaryResults: [ImportResult] = []
        var audioResults: [AudioSourceResult] = []
        var tokenizerResults: [TokenizerDictionaryResult] = []

        print("Glossary codec: \(arguments.glossaryCompressionVersion.rawValue)")
        print("Glossary training profile: \(arguments.glossaryCompressionTrainingProfile.rawValue)")

        if !arguments.dictionaryPaths.isEmpty {
            let importManager = ImportManager(
                container: container,
                baseDirectory: arguments.outputDir,
                glossaryCompressionVersion: arguments.glossaryCompressionVersion,
                glossaryCompressionTrainingProfile: arguments.glossaryCompressionTrainingProfile
            )

            for zipURL in arguments.dictionaryPaths {
                print("Importing dictionary: \(zipURL.lastPathComponent)...")

                let jobID = try await importManager.enqueueDictionaryImport(from: zipURL)
                await importManager.waitForCompletion(jobID: jobID)

                let result = try await getDictionaryResult(container: container, jobID: jobID)
                dictionaryResults.append(result)
                print("  \(result.status): \(result.name) (\(result.terms) terms, \(result.kanji) kanji)")

                if result.status != "Completed" {
                    throw SeederError.importFailed("\(result.name): \(result.status)")
                }
            }
        }

        if !arguments.audioSourcePaths.isEmpty {
            let audioImportManager = ImportManager(
                container: container,
                baseDirectory: arguments.outputDir
            )

            for zipURL in arguments.audioSourcePaths {
                print("Importing audio source: \(zipURL.lastPathComponent)...")

                let jobID = try await audioImportManager.enqueueAudioSourceImport(from: zipURL)
                await audioImportManager.waitForCompletion(jobID: jobID)

                let result = try await getAudioSourceResult(container: container, jobID: jobID)
                audioResults.append(result)
                print("  \(result.status): \(result.name)")
            }
        }

        if !arguments.tokenizerDictionaryPaths.isEmpty {
            let tokenizerImportManager = ImportManager(
                container: container,
                baseDirectory: arguments.outputDir
            )

            for zipURL in arguments.tokenizerDictionaryPaths {
                print("Importing tokenizer dictionary: \(zipURL.lastPathComponent)...")

                let jobID = try await tokenizerImportManager.enqueueTokenizerDictionaryImport(from: zipURL)
                await tokenizerImportManager.waitForCompletion(jobID: jobID)

                let result = try await getTokenizerDictionaryResult(container: container, jobID: jobID)
                tokenizerResults.append(result)
                print("  \(result.status): \(result.name)\(result.version.map { " (\($0))" } ?? "")")

                if result.status != "Completed" {
                    throw SeederError.importFailed("\(result.name): \(result.status)")
                }
            }
        }

        if arguments.glossaryCompressionVersion == .zstdRuntimeV1 {
            try validateCompressionDictionaries(for: dictionaryResults, in: arguments.outputDir)
        }
        printSummary(dictionaryResults: dictionaryResults, audioResults: audioResults, tokenizerResults: tokenizerResults)
        try verifyNoWAL(at: storeURL)

        print("\nOutput written to: \(arguments.outputDir.path)")
    }

    static func validateInputFiles(_ inputURLs: [URL]) throws {
        for inputURL in inputURLs {
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                throw SeederError.invalidArguments("File not found: \(inputURL.path)")
            }
        }
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
                id: dictionary.id,
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

    static func getTokenizerDictionaryResult(container: NSPersistentContainer, jobID: NSManagedObjectID) async throws -> TokenizerDictionaryResult {
        let context = container.newBackgroundContext()
        return try await context.perform {
            guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                throw SeederError.importFailed("Could not fetch tokenizer dictionary record")
            }

            let status = if tokenizerDictionary.isComplete {
                "Completed"
            } else if tokenizerDictionary.isFailed {
                "Failed: \(tokenizerDictionary.errorMessage ?? "Unknown error")"
            } else if tokenizerDictionary.isCancelled {
                "Cancelled"
            } else {
                "Unknown"
            }

            return TokenizerDictionaryResult(
                name: tokenizerDictionary.name ?? "Unknown",
                version: tokenizerDictionary.version,
                status: status
            )
        }
    }

    static func validateCompressionDictionaries(for dictionaryResults: [ImportResult], in outputDir: URL) throws {
        let termDictionaries = dictionaryResults.filter { $0.status == "Completed" && $0.terms > 0 }
        guard !termDictionaries.isEmpty else {
            return
        }

        for result in termDictionaries {
            guard let dictionaryID = result.id else {
                throw SeederError.missingCompressionDictionary("\(result.name) is missing its UUID")
            }

            let dictionaryURL = GlossaryCompressionCodec.zstdDictionaryURL(dictionaryID: dictionaryID, in: outputDir)

            guard FileManager.default.fileExists(atPath: dictionaryURL.path) else {
                throw SeederError.missingCompressionDictionary("\(result.name) -> \(dictionaryURL.lastPathComponent)")
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: dictionaryURL.path)
            let size = attributes[.size] as? NSNumber
            guard let size, size.intValue > 0 else {
                throw SeederError.missingCompressionDictionary("\(result.name) -> \(dictionaryURL.lastPathComponent) is empty")
            }
        }
    }

    static func printSummary(
        dictionaryResults: [ImportResult],
        audioResults: [AudioSourceResult],
        tokenizerResults: [TokenizerDictionaryResult]
    ) {
        print("\n--- Summary ---")

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

        if !tokenizerResults.isEmpty {
            let completed = tokenizerResults.filter { $0.status == "Completed" }
            let failed = tokenizerResults.filter { $0.status != "Completed" }

            print("Tokenizer dictionaries: \(completed.count)/\(tokenizerResults.count) imported")

            if !failed.isEmpty {
                print("\nFailed tokenizer dictionary imports:")
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
