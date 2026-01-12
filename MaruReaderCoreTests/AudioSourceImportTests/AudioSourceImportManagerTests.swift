// AudioSourceImportManagerTests.swift
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
@testable import MaruReaderCore
import Testing
internal import ReadiumZIPFoundation

struct AudioSourceImportManagerTests {
    // Custom errors for diagnostics
    enum MockZipError: Error {
        case invalidJSON(String)
        case fileWriteFailed(URL)
        case fileNotFound(URL)
    }

    // MARK: - Helper Methods

    /// Create a mock audio source ZIP file with the given JSON index and optional audio files.
    private func createMockAudioSourceZIP(
        indexJSON: String,
        indexFilename: String = "index.json",
        audioFiles: [String]? = nil,
        mediaDir: String = "media"
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        // Write index JSON file
        let indexURL = contentsDir.appendingPathComponent(indexFilename)
        guard let indexData = indexJSON.data(using: .utf8) else {
            throw MockZipError.invalidJSON("Failed to convert JSON to data")
        }
        try indexData.write(to: indexURL)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw MockZipError.fileWriteFailed(indexURL)
        }

        // Create audio files if provided
        if let audioFiles {
            for audioPath in audioFiles {
                let fullPath = contentsDir.appendingPathComponent(mediaDir).appendingPathComponent(audioPath)
                let parentDir = fullPath.deletingLastPathComponent()

                if !FileManager.default.fileExists(atPath: parentDir.path) {
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }

                // Create mock audio file with some binary content (OGG header-like)
                let mockAudioData = Data([
                    0x4F, 0x67, 0x67, 0x53, // "OggS" magic number
                    0x00, 0x02, 0x00, 0x00,
                    0x00, 0x00, 0x00, 0x00,
                    0x00, 0x00, 0x00, 0x00,
                ])
                try mockAudioData.write(to: fullPath)
                guard FileManager.default.fileExists(atPath: fullPath.path) else {
                    throw MockZipError.fileWriteFailed(fullPath)
                }
            }
        }

        // Create ZIP
        let zipURL = tempDir.appendingPathComponent("audio_source.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)

        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw MockZipError.fileNotFound(zipURL)
        }

        return zipURL
    }

    private func createArchive(from rootURL: URL, zipURL: URL) async throws {
        let archive = try await Archive(url: zipURL, accessMode: .create)
        let rootPath = rootURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath {
                continue
            }
            let relativePath = fileURL.path.replacingOccurrences(of: rootPrefix, with: "")
            try await archive.addEntry(with: relativePath, relativeTo: rootURL)
        }
    }

    /// Create a corrupted ZIP file for testing error handling.
    private func createCorruptedZIP() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let zipURL = tempDir.appendingPathComponent("corrupted.zip")
        let corruptedData = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF]) // Invalid ZIP header
        try corruptedData.write(to: zipURL)

        return zipURL
    }

    /// Create ZIP without any JSON file.
    private func createZIPWithoutIndex() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let dummyURL = contentsDir.appendingPathComponent("dummy.txt")
        try "dummy content".write(to: dummyURL, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("no_index.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)

        return zipURL
    }

    // MARK: - Job Verification Helpers

    @MainActor
    private func verifyJobCancelled(_ job: AudioSource?) {
        #expect(job != nil)
        #expect(job?.isCancelled == true)
        #expect(job?.isFailed == false)
        #expect(job?.isComplete == false)
        #expect(job?.timeCancelled != nil)
    }

    @MainActor
    private func verifyJobFailed(_ job: AudioSource?) {
        #expect(job != nil)
        #expect(job?.isFailed == true)
        #expect(job?.isCancelled == false)
        #expect(job?.isComplete == false)
        #expect(job?.timeFailed != nil)
        #expect(job?.displayProgressMessage?.isEmpty == false)
    }

    @MainActor
    private func getJob(from context: NSManagedObjectContext, importID: NSManagedObjectID) -> AudioSource? {
        try? context.existingObject(with: importID) as? AudioSource
    }

    // MARK: - Fetch Helpers

    @MainActor
    private func fetchAudioSources(from context: NSManagedObjectContext) -> [AudioSource] {
        let request: NSFetchRequest<AudioSource> = AudioSource.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    @MainActor
    private func fetchAudioHeadwords(from context: NSManagedObjectContext) -> [AudioHeadword] {
        let request: NSFetchRequest<AudioHeadword> = AudioHeadword.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    @MainActor
    private func fetchAudioFiles(from context: NSManagedObjectContext) -> [AudioFile] {
        let request: NSFetchRequest<AudioFile> = AudioFile.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    @MainActor
    private func waitForSourceDeletion(in context: NSManagedObjectContext, timeout: TimeInterval = 5.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if fetchAudioSources(from: context).isEmpty {
                return
            }
            context.refreshAllObjects()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // MARK: - Success Tests

    @Test @MainActor func importAudioSource_ValidLocalSource_ImportsSuccessfully() async throws {
        // Test: Local source with audio files
        let indexJSON = """
        {
            "meta": {
                "name": "Test Audio Source",
                "year": 2024,
                "version": 3,
                "media_dir": "media"
            },
            "headwords": {
                "私": ["watashi_01.ogg", "watashi_02.ogg"],
                "僕": ["boku_01.ogg"],
                "彼": ["kare_01.ogg", "kare_02.ogg", "kare_03.ogg"]
            },
            "files": {
                "watashi_01.ogg": {
                    "kana_reading": "わたし",
                    "pitch_number": "0"
                },
                "watashi_02.ogg": {
                    "kana_reading": "わたくし",
                    "pitch_pattern": "わたくし━"
                },
                "boku_01.ogg": {
                    "kana_reading": "ぼく",
                    "pitch_number": "1"
                },
                "kare_01.ogg": {
                    "kana_reading": "かれ"
                },
                "kare_02.ogg": {
                    "kana_reading": "かれ",
                    "pitch_number": "1"
                },
                "kare_03.ogg": {
                    "kana_reading": "カレ"
                }
            }
        }
        """

        let audioFiles = [
            "watashi_01.ogg",
            "watashi_02.ogg",
            "boku_01.ogg",
            "kare_01.ogg",
            "kare_02.ogg",
            "kare_03.ogg",
        ]

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: audioFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        // Verify job completed successfully
        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        #expect(job != nil)
        #expect(job?.isCancelled == false)
        #expect(job?.isFailed == false)
        #expect(job?.isComplete == true)
        #expect(job?.displayProgressMessage == "Import complete.")

        // Verify AudioSource entity
        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let source = sources.first
        #expect(source?.name == "Test Audio Source")
        #expect(source?.year == 2024)
        #expect(source?.version == 3)
        #expect(source?.isLocal == true)
        #expect(source?.baseRemoteURL == nil)
        #expect(source?.indexedByHeadword == true)
        #expect(source?.enabled == true)

        // Verify file extensions detected
        let extensions = source?.audioFileExtensions?.split(separator: ",").map { String($0) } ?? []
        #expect(extensions.contains("ogg"))

        // Verify AudioHeadword entities
        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.count == 3)

        let watashiHeadword = headwords.first { $0.expression == "私" }
        #expect(watashiHeadword != nil)
        #expect(watashiHeadword?.sourceID == source?.id)

        // Verify files JSON in headword
        if let filesJSON = watashiHeadword?.files,
           let filesData = filesJSON.data(using: .utf8),
           let files = try? JSONDecoder().decode([String].self, from: filesData)
        {
            #expect(files.count == 2)
            #expect(files.contains("watashi_01.ogg"))
            #expect(files.contains("watashi_02.ogg"))
        } else {
            Issue.record("Failed to decode files JSON for watashi headword")
        }

        let bokuHeadword = headwords.first { $0.expression == "僕" }
        #expect(bokuHeadword != nil)

        let kareHeadword = headwords.first { $0.expression == "彼" }
        #expect(kareHeadword != nil)
        if let filesJSON = kareHeadword?.files,
           let filesData = filesJSON.data(using: .utf8),
           let files = try? JSONDecoder().decode([String].self, from: filesData)
        {
            #expect(files.count == 3)
        }

        // Verify AudioFile entities
        let audioFileEntities = fetchAudioFiles(from: context)
        #expect(audioFileEntities.count == 6)

        let watashi01 = audioFileEntities.filter { $0.name == "watashi_01.ogg" }.first
        #expect(watashi01 != nil)
        #expect(watashi01?.kanaReading == "わたし")
        #expect(watashi01?.pitchNumber == "0")
        #expect(watashi01?.normalizedReading == "わたし") // Already hiragana
        #expect(watashi01?.sourceID == source?.id)

        let watashi02 = audioFileEntities.filter { $0.name == "watashi_02.ogg" }.first
        #expect(watashi02?.kanaReading == "わたくし")
        #expect(watashi02?.pitchPattern == "わたくし━")

        // Verify katakana is normalized to hiragana
        let kare03 = audioFileEntities.filter { $0.name == "kare_03.ogg" }.first
        #expect(kare03?.kanaReading == "カレ")
        #expect(kare03?.normalizedReading == "かれ") // Katakana → hiragana

        // Verify media files are copied to app group
        let fileManager = FileManager.default
        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            Issue.record("App group directory not found")
            return
        }

        guard let sourceID = source?.id else {
            Issue.record("Source ID not found")
            return
        }

        let mediaDir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)
        #expect(fileManager.fileExists(atPath: mediaDir.path), "Media directory should exist")

        for audioFile in audioFiles {
            let expectedPath = mediaDir.appendingPathComponent(audioFile)
            #expect(fileManager.fileExists(atPath: expectedPath.path), "Audio file should exist: \(audioFile)")

            let fileSize = try? fileManager.attributesOfItem(atPath: expectedPath.path)[.size] as? Int
            #expect((fileSize ?? 0) > 0, "Audio file should not be empty: \(audioFile)")
        }
    }

    @Test @MainActor func importAudioSource_ValidOnlineSource_ImportsSuccessfully() async throws {
        // Test: Online source (has media_dir_abs, no media files to copy)
        let indexJSON = """
        {
            "meta": {
                "name": "Online Audio Source",
                "year": 2025,
                "version": 1,
                "media_dir_abs": "https://example.com/audio/"
            },
            "headwords": {
                "食べる": ["taberu_01.mp3"],
                "飲む": ["nomu_01.mp3", "nomu_02.mp3"]
            },
            "files": {
                "taberu_01.mp3": {
                    "kana_reading": "たべる",
                    "pitch_number": "2"
                },
                "nomu_01.mp3": {
                    "kana_reading": "のむ",
                    "pitch_number": "1"
                },
                "nomu_02.mp3": {
                    "kana_reading": "のむ",
                    "pitch_pattern": "のむ━"
                }
            }
        }
        """

        // Online source: single JSON at root, named anything
        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, indexFilename: "shinmeikai8.json", audioFiles: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        // Verify job completed successfully
        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        #expect(job != nil)
        #expect(job?.isCancelled == false)
        #expect(job?.isFailed == false)
        #expect(job?.isComplete == true)

        // Verify AudioSource entity
        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let source = sources.first
        #expect(source?.name == "Online Audio Source")
        #expect(source?.year == 2025)
        #expect(source?.version == 1)
        #expect(source?.isLocal == false)
        #expect(source?.baseRemoteURL == "https://example.com/audio/")
        #expect(source?.indexedByHeadword == true)

        // Verify file extensions detected
        let extensions = source?.audioFileExtensions?.split(separator: ",").map { String($0) } ?? []
        #expect(extensions.contains("mp3"))

        // Verify AudioHeadword entities
        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.count == 2)

        // Verify AudioFile entities
        let audioFileEntities = fetchAudioFiles(from: context)
        #expect(audioFileEntities.count == 3)

        // Verify no media directory created (online source)
        let fileManager = FileManager.default
        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return
        }

        guard let sourceID = source?.id else {
            return
        }

        let mediaDir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)
        // For online sources, media directory should not be created (or should be empty)
        if fileManager.fileExists(atPath: mediaDir.path) {
            let contents = try? fileManager.contentsOfDirectory(atPath: mediaDir.path)
            #expect(contents?.isEmpty ?? true, "Media directory should be empty for online sources")
        }
    }

    @Test @MainActor func importAudioSource_MinimalMetadata_ImportsSuccessfully() async throws {
        // Test: Source with only required metadata (name)
        let indexJSON = """
        {
            "meta": {
                "name": "Minimal Source"
            },
            "headwords": {
                "テスト": ["test.ogg"]
            },
            "files": {
                "test.ogg": {
                    "kana_reading": "てすと"
                }
            }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: ["test.ogg"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        #expect(job?.isComplete == true)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let source = sources.first
        #expect(source?.name == "Minimal Source")
        #expect(source?.year == 0) // Default
        #expect(source?.version == 0) // Default
        #expect(source?.isLocal == true) // No media_dir_abs
    }

    // MARK: - Cancellation Tests

    @Test func importAudioSource_CancelAfterIndex_CleansUpProperly() async throws {
        let indexJSON = """
        {
            "meta": { "name": "Test" },
            "headwords": { "テスト": ["test.ogg"] },
            "files": { "test.ogg": { "kana_reading": "てすと" } }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: ["test.ogg"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        // Cancel during first cancellation check (after index processing)
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 1 {
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        await MainActor.run {
            let job = getJob(from: context, importID: importID)
            verifyJobCancelled(job)

            // Verify source record remains but no entries were created
            let sources = fetchAudioSources(from: context)
            #expect(sources.count == 1)

            let headwords = fetchAudioHeadwords(from: context)
            #expect(headwords.isEmpty)

            let files = fetchAudioFiles(from: context)
            #expect(files.isEmpty)
        }
    }

    @Test func importAudioSource_CancelAfterEntries_CleansUpProperly() async throws {
        let indexJSON = """
        {
            "meta": { "name": "Test" },
            "headwords": { "テスト": ["test.ogg"] },
            "files": { "test.ogg": { "kana_reading": "てすと" } }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: ["test.ogg"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        // Cancel after entry processing (second cancellation check)
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 2 {
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        await MainActor.run {
            let job = getJob(from: context, importID: importID)
            verifyJobCancelled(job)

            let sources = fetchAudioSources(from: context)
            #expect(sources.count == 1)

            let headwords = fetchAudioHeadwords(from: context)
            #expect(headwords.isEmpty)

            let files = fetchAudioFiles(from: context)
            #expect(files.isEmpty)
        }
    }

    @Test func importAudioSource_CancelAfterMediaCopy_CleansUpProperly() async throws {
        let indexJSON = """
        {
            "meta": { "name": "Test" },
            "headwords": { "テスト": ["test.ogg"] },
            "files": { "test.ogg": { "kana_reading": "てすと" } }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: ["test.ogg"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        // Cancel after media copy (third cancellation check)
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 3 {
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        await MainActor.run {
            let job = getJob(from: context, importID: importID)
            verifyJobCancelled(job)

            let sources = fetchAudioSources(from: context)
            #expect(sources.count == 1)

            let headwords = fetchAudioHeadwords(from: context)
            #expect(headwords.isEmpty)

            let files = fetchAudioFiles(from: context)
            #expect(files.isEmpty)
        }
    }

    @Test @MainActor func importAudioSource_CancelQueuedJob_CleansUpProperly() async throws {
        let indexJSON = """
        {
            "meta": { "name": "Test" },
            "headwords": { "テスト": ["test.ogg"] },
            "files": { "test.ogg": { "kana_reading": "てすと" } }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Cancel immediately (while in queue)
        await importManager.cancelImport(jobID: importID)

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        verifyJobCancelled(job)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.isEmpty)

        let files = fetchAudioFiles(from: context)
        #expect(files.isEmpty)
    }

    // MARK: - Failure Tests

    @Test @MainActor func importAudioSource_MalformedZIP_FailsAndCleansUp() async throws {
        let zipURL = try createCorruptedZIP()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        verifyJobFailed(job)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.isEmpty)

        let files = fetchAudioFiles(from: context)
        #expect(files.isEmpty)
    }

    @Test @MainActor func importAudioSource_MissingIndexJSON_FailsAndCleansUp() async throws {
        let zipURL = try await createZIPWithoutIndex()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        verifyJobFailed(job)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.isEmpty)

        let files = fetchAudioFiles(from: context)
        #expect(files.isEmpty)
    }

    @Test @MainActor func importAudioSource_InvalidJSON_FailsAndCleansUp() async throws {
        let invalidJSON = """
        {
            "meta": {
                "name": "Test"
            },
            "headwords": {
                "invalid": "json"  // Should be array, not string
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: invalidJSON, audioFiles: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        verifyJobFailed(job)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.isEmpty)

        let files = fetchAudioFiles(from: context)
        #expect(files.isEmpty)
    }

    @Test @MainActor func importAudioSource_MultipleJSONFiles_FailsForAmbiguity() async throws {
        // Create a ZIP with multiple JSON files at root (ambiguous for online sources)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        // First JSON file
        let json1 = """
        { "meta": { "name": "Source 1" }, "headwords": {}, "files": {} }
        """
        try json1.write(to: contentsDir.appendingPathComponent("source1.json"), atomically: true, encoding: .utf8)

        // Second JSON file
        let json2 = """
        { "meta": { "name": "Source 2" }, "headwords": {}, "files": {} }
        """
        try json2.write(to: contentsDir.appendingPathComponent("source2.json"), atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("multiple_json.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        verifyJobFailed(job)

        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        let headwords = fetchAudioHeadwords(from: context)
        #expect(headwords.isEmpty)

        let files = fetchAudioFiles(from: context)
        #expect(files.isEmpty)
    }

    @Test func importAudioSource_FileSystemError_FailsAndCleansUp() async throws {
        let indexJSON = """
        {
            "meta": { "name": "Test" },
            "headwords": { "テスト": ["test.ogg"] },
            "files": { "test.ogg": { "kana_reading": "てすと" } }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        // Inject error
        await importManager.setTestErrorInjection {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [
                NSLocalizedDescriptionKey: "Simulated file system error",
            ])
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        await MainActor.run {
            let context = persistenceController.container.viewContext
            let job = getJob(from: context, importID: importID)
            verifyJobFailed(job)

            let sources = fetchAudioSources(from: context)
            #expect(sources.count == 1)

            let headwords = fetchAudioHeadwords(from: context)
            #expect(headwords.isEmpty)

            let files = fetchAudioFiles(from: context)
            #expect(files.isEmpty)
        }
    }

    // MARK: - Deletion Tests

    @Test @MainActor func deleteAudioSource_RemovesAllData() async throws {
        // First, import an audio source
        let indexJSON = """
        {
            "meta": { "name": "Delete Test" },
            "headwords": {
                "削除": ["sakujo.ogg"],
                "テスト": ["test.ogg"]
            },
            "files": {
                "sakujo.ogg": { "kana_reading": "さくじょ" },
                "test.ogg": { "kana_reading": "てすと" }
            }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: ["sakujo.ogg", "test.ogg"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext

        // Verify import succeeded
        let sources = fetchAudioSources(from: context)
        #expect(sources.count == 1)

        guard let source = sources.first else {
            Issue.record("Source not found")
            return
        }

        let sourceObjectID = source.objectID
        let sourceUUID = source.id

        // Verify entities exist
        #expect(fetchAudioHeadwords(from: context).count == 2)
        #expect(fetchAudioFiles(from: context).count == 2)

        // Verify media directory exists
        let fileManager = FileManager.default
        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ), let sourceID = sourceUUID else {
            Issue.record("App group or source ID not found")
            return
        }

        let mediaDir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)
        #expect(fileManager.fileExists(atPath: mediaDir.path))

        // Delete the audio source
        await importManager.deleteAudioSource(sourceID: sourceObjectID)

        await waitForSourceDeletion(in: context)

        // Verify all data is deleted
        let remainingSources = fetchAudioSources(from: context)
        #expect(remainingSources.isEmpty)

        let remainingHeadwords = fetchAudioHeadwords(from: context)
        #expect(remainingHeadwords.isEmpty)

        let remainingFiles = fetchAudioFiles(from: context)
        #expect(remainingFiles.isEmpty)

        // Verify media directory is deleted
        #expect(!fileManager.fileExists(atPath: mediaDir.path))
    }

    @Test @MainActor func cleanupInterruptedAudioSourceImports_MarksFailedAndCleansEntries() async throws {
        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let sourceID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        let importID = try await context.perform {
            let source = AudioSource(context: context)
            source.id = sourceID
            source.name = "Interrupted Source"
            source.audioFileExtensions = "ogg"
            source.dateAdded = Date()
            source.enabled = true
            source.isLocal = true
            source.indexedByHeadword = true
            source.isComplete = false
            source.isFailed = false
            source.isCancelled = false
            source.isStarted = true
            source.pendingDeletion = false
            source.displayProgressMessage = "Importing..."
            source.indexProcessed = true
            source.entriesProcessed = true
            source.mediaImported = true
            source.priority = 0

            let headword = AudioHeadword(context: context)
            headword.id = UUID()
            headword.expression = "てすと"
            headword.files = "[\"test.ogg\"]"
            headword.sourceID = sourceID

            let audioFile = AudioFile(context: context)
            audioFile.id = UUID()
            audioFile.name = "test.ogg"
            audioFile.kanaReading = "てすと"
            audioFile.normalizedReading = "てすと"
            audioFile.pitchNumber = "0"
            audioFile.sourceID = sourceID

            try context.save()
            return source.objectID
        }

        var mediaDir: URL?
        if let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) {
            let dir = appGroupDir.appendingPathComponent("AudioMedia").appendingPathComponent(sourceID.uuidString)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let marker = dir.appendingPathComponent("marker.txt")
            try? "marker".write(to: marker, atomically: true, encoding: .utf8)
            mediaDir = dir
        }

        await importManager.cleanupInterruptedImports()

        let viewContext = persistenceController.container.viewContext
        let job = getJob(from: viewContext, importID: importID)
        verifyJobFailed(job)
        #expect(job?.indexProcessed == false)
        #expect(job?.entriesProcessed == false)
        #expect(job?.mediaImported == false)
        #expect(fetchAudioHeadwords(from: viewContext).isEmpty)
        #expect(fetchAudioFiles(from: viewContext).isEmpty)

        if let mediaDir {
            #expect(!FileManager.default.fileExists(atPath: mediaDir.path), "Audio media directory should be deleted")
        }
    }

    // MARK: - Large Data Tests

    @Test @MainActor func importAudioSource_LargeDataset_ImportsSuccessfully() async throws {
        // Generate a large JSON with many headwords and files
        var headwords: [String] = []
        var files: [String] = []

        for i in 0 ..< 500 {
            headwords.append("\"word\(i)\": [\"file\(i).ogg\"]")
            files.append("\"file\(i).ogg\": { \"kana_reading\": \"よみ\(i)\" }")
        }

        let indexJSON = """
        {
            "meta": { "name": "Large Source" },
            "headwords": {
                \(headwords.joined(separator: ",\n"))
            },
            "files": {
                \(files.joined(separator: ",\n"))
            }
        }
        """

        let zipURL = try await createMockAudioSourceZIP(indexJSON: indexJSON, audioFiles: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let importManager = AudioSourceImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let job = getJob(from: context, importID: importID)
        #expect(job?.isComplete == true)

        let headwordEntities = fetchAudioHeadwords(from: context)
        #expect(headwordEntities.count == 500)

        let fileEntities = fetchAudioFiles(from: context)
        #expect(fileEntities.count == 500)
    }
}
