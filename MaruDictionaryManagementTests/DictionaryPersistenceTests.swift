// DictionaryPersistenceTests.swift
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

internal import ReadiumZIPFoundation
import CoreData
import Foundation
@testable import MaruDictionaryManagement
import MaruReaderCore
import Testing

struct DictionaryPersistenceTests {
    /// Custom errors for diagnostics
    enum MockZipError: Error {
        case invalidJSON(String)
        case fileWriteFailed(URL)
        case fileNotFound(URL)
        case missingFile(String)
    }

    final class MockUpdateNetworkProvider: NetworkProviding, @unchecked Sendable {
        private(set) var requestedURLs: [URL] = []
        private var responses: [URL: (Data, URLResponse)] = [:]

        func queueResponse(url: URL, data: Data, statusCode: Int = 200, expectedLength: Int64? = nil) {
            let headers: [String: String]? = if let expectedLength {
                ["Content-Length": "\(expectedLength)"]
            } else {
                nil
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )!
            responses[url] = (data, response)
        }

        func data(from url: URL) async throws -> (Data, URLResponse) {
            requestedURLs.append(url)
            if let response = responses[url] {
                return response
            }
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
    }

    actor MockAnkiUpdater: DictionaryUpdateAnkiPreferencesUpdating {
        private(set) var replacements: [(UUID, UUID)] = []

        func replaceDictionaryIDs(oldID: UUID, newID: UUID) async {
            replacements.append((oldID, newID))
        }

        func lastReplacement() -> (UUID, UUID)? {
            replacements.last
        }
    }

    final class PersistentContainerBox: @unchecked Sendable {
        let container: NSPersistentContainer

        init(container: NSPersistentContainer) {
            self.container = container
        }
    }

    private var nonExpiringBackgroundTaskRunner: ApplicationBackgroundTaskRunner {
        ApplicationBackgroundTaskRunner { _, _, operation in
            await operation()
        }
    }

    private var expiringBackgroundTaskRunner: ApplicationBackgroundTaskRunner {
        ApplicationBackgroundTaskRunner { _, expirationHandler, operation in
            expirationHandler()
            await Task.yield()
            await operation()
        }
    }

    private func delayedExpiringBackgroundTaskRunner(
        delayNanoseconds: UInt64 = 200_000_000
    ) -> ApplicationBackgroundTaskRunner {
        ApplicationBackgroundTaskRunner { _, expirationHandler, operation in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            expirationHandler()
            await Task.yield()
            await operation()
        }
    }

    // Helper: Create a mock ZIP file with given JSON contents
    private func createMockZIP(indexJSON: String, tagJSON: String?, termJSON: String?, termMetaJSON: String?, kanjiJSON: String?, kanjiMetaJSON: String?, mediaFiles: [String]? = nil) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)
        debugPrint("Created temp directory: \(tempDir.path)")

        // Always create index.json as it's required
        let indexURL = contentsDir.appendingPathComponent("index.json")
        guard let indexData = indexJSON.data(using: .utf8) else {
            throw MockZipError.invalidJSON("Failed to convert JSON to data for index.json")
        }
        try indexData.write(to: indexURL)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw MockZipError.fileWriteFailed(indexURL)
        }
        debugPrint("Wrote file: \(indexURL.path)")

        // Create tag_bank_1.json if tagJSON is provided
        if let tagJSON {
            let tagURL = contentsDir.appendingPathComponent("tag_bank_1.json")
            guard let tagData = tagJSON.data(using: .utf8) else {
                throw MockZipError.invalidJSON("Failed to convert JSON to data for tag_bank_1.json")
            }
            try tagData.write(to: tagURL)
            guard FileManager.default.fileExists(atPath: tagURL.path) else {
                throw MockZipError.fileWriteFailed(tagURL)
            }
            debugPrint("Wrote file: \(tagURL.path)")
        }

        // Create term_bank_1.json if termJSON is provided
        if let termJSON {
            let termURL = contentsDir.appendingPathComponent("term_bank_1.json")
            guard let termData = termJSON.data(using: .utf8) else {
                throw MockZipError.invalidJSON("Failed to convert JSON to data for term_bank_1.json")
            }
            try termData.write(to: termURL)
            guard FileManager.default.fileExists(atPath: termURL.path) else {
                throw MockZipError.fileWriteFailed(termURL)
            }
            debugPrint("Wrote file: \(termURL.path)")
        }

        // Create term_meta_bank_1.json if termMetaJSON is provided
        if let termMetaJSON {
            let termMetaURL = contentsDir.appendingPathComponent("term_meta_bank_1.json")
            guard let termMetaData = termMetaJSON.data(using: .utf8) else {
                throw MockZipError.invalidJSON("Failed to convert JSON to data for term_meta_bank_1.json")
            }
            try termMetaData.write(to: termMetaURL)
            guard FileManager.default.fileExists(atPath: termMetaURL.path) else {
                throw MockZipError.fileWriteFailed(termMetaURL)
            }
            debugPrint("Wrote file: \(termMetaURL.path)")
        }

        // Create kanji_bank_1.json if kanjiJSON is provided
        if let kanjiJSON {
            let kanjiURL = contentsDir.appendingPathComponent("kanji_bank_1.json")
            guard let kanjiData = kanjiJSON.data(using: .utf8) else {
                throw MockZipError.invalidJSON("Failed to convert JSON to data for kanji_bank_1.json")
            }
            try kanjiData.write(to: kanjiURL)
            guard FileManager.default.fileExists(atPath: kanjiURL.path) else {
                throw MockZipError.fileWriteFailed(kanjiURL)
            }
            debugPrint("Wrote file: \(kanjiURL.path)")
        }

        // Create kanji_meta_bank_1.json if kanjiMetaJSON is provided
        if let kanjiMetaJSON {
            let kanjiMetaURL = contentsDir.appendingPathComponent("kanji_meta_bank_1.json")
            guard let kanjiMetaData = kanjiMetaJSON.data(using: .utf8) else {
                throw MockZipError.invalidJSON("Failed to convert JSON to data for kanji_meta_bank_1.json")
            }
            try kanjiMetaData.write(to: kanjiMetaURL)
            guard FileManager.default.fileExists(atPath: kanjiMetaURL.path) else {
                throw MockZipError.fileWriteFailed(kanjiMetaURL)
            }
            debugPrint("Wrote file: \(kanjiMetaURL.path)")
        }

        // Create media files if provided
        if let mediaFiles {
            for mediaPath in mediaFiles {
                let mediaURL = contentsDir.appendingPathComponent(mediaPath)

                // Create intermediate directories if needed
                let mediaDir = mediaURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: mediaDir.path) {
                    try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
                }

                // Create a mock media file with some dummy content
                // For testing purposes, we'll create a small PNG-like binary file
                let mockImageData = Data([
                    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
                    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
                    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 pixel
                    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // Rest of minimal PNG
                ])

                try mockImageData.write(to: mediaURL)
                guard FileManager.default.fileExists(atPath: mediaURL.path) else {
                    throw MockZipError.fileWriteFailed(mediaURL)
                }
                debugPrint("Wrote media file: \(mediaURL.path)")
            }
        }

        let zipURL = tempDir.appendingPathComponent("mock.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)

        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw MockZipError.fileNotFound(zipURL)
        }
        debugPrint("Created ZIP: \(zipURL.path)")

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

    // Helper: Create a corrupted ZIP file for testing error handling
    private func createCorruptedZIP() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let zipURL = tempDir.appendingPathComponent("corrupted.zip")
        let corruptedData = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF]) // Invalid ZIP header
        try corruptedData.write(to: zipURL)

        return zipURL
    }

    // Helper: Create ZIP without index.json
    private func createZIPWithoutIndex() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        // Create some other file
        let dummyURL = contentsDir.appendingPathComponent("dummy.txt")
        try "dummy content".write(to: dummyURL, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("no_index.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)

        return zipURL
    }

    private func seedPartiallyImportedTermEntry(
        in container: NSPersistentContainer,
        dictionaryUUID: UUID
    ) async throws -> NSManagedObjectID {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let dictionary = Dictionary(context: context)
            dictionary.id = dictionaryUUID
            dictionary.title = "Partial Import"
            dictionary.timeQueued = Date()
            dictionary.isComplete = false
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.isStarted = true
            dictionary.displayProgressMessage = "Processing dictionary data..."
            dictionary.format = 3

            let termEntry = TermEntry(context: context)
            termEntry.id = UUID()
            termEntry.dictionaryID = dictionaryUUID
            termEntry.expression = "食べる"
            termEntry.reading = "たべる"
            termEntry.glossary = try GlossaryCompressionCodec.encodeGlossaryJSON(
                Data(#"["to eat"]"#.utf8),
                using: .zstdV1,
                dictionaryID: nil
            )
            termEntry.definitionTags = "[]"
            termEntry.termTags = "[]"
            termEntry.rules = "[]"
            termEntry.score = 0
            termEntry.sequence = 1

            try context.save()
            return dictionary.objectID
        }
    }

    // Helper: Verify dictionary import is properly cancelled
    @MainActor
    private func verifyDictionaryCancelled(_ dictionary: Dictionary?) {
        #expect(dictionary != nil)
        #expect(dictionary?.isCancelled == true)
        #expect(dictionary?.isFailed == false)
        #expect(dictionary?.isComplete == false)
        #expect(dictionary?.timeCancelled != nil)
    }

    // Helper: Verify dictionary import is properly marked as failed
    @MainActor
    private func verifyDictionaryFailed(_ dictionary: Dictionary?) {
        #expect(dictionary != nil)
        #expect(dictionary?.isFailed == true)
        #expect(dictionary?.isCancelled == false)
        #expect(dictionary?.isComplete == false)
        #expect(dictionary?.timeFailed != nil)
        #expect(dictionary?.errorMessage?.isEmpty == false)
    }

    // Helper: Get dictionary from context safely
    @MainActor
    private func getDictionary(from context: NSManagedObjectContext, importID: NSManagedObjectID) -> Dictionary? {
        try? context.existingObject(with: importID) as? Dictionary
    }

    // Helper: Fetch dictionaries safely
    @MainActor
    private func fetchDictionaries(from context: NSManagedObjectContext) -> [Dictionary] {
        let request: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    @MainActor
    private func waitForDictionaryDeletion(
        in context: NSManagedObjectContext,
        importID: NSManagedObjectID,
        timeout: TimeInterval = 5.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !fetchDictionaries(from: context).contains(where: { $0.objectID == importID }) {
                return
            }
            context.refreshAllObjects()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // Helper: Fetch dictionary tag metas safely
    @MainActor
    private func fetchDictionaryTagMetas(from context: NSManagedObjectContext) -> [DictionaryTagMeta] {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch term entries safely
    @MainActor
    private func fetchTermEntries(from context: NSManagedObjectContext) -> [TermEntry] {
        let request: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch kanji entries safely
    @MainActor
    private func fetchKanjiEntries(from context: NSManagedObjectContext) -> [KanjiEntry] {
        let request: NSFetchRequest<KanjiEntry> = KanjiEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch kanji frequency entries safely
    @MainActor
    private func fetchKanjiFrequencyEntries(from context: NSManagedObjectContext) -> [KanjiFrequencyEntry] {
        let request: NSFetchRequest<KanjiFrequencyEntry> = KanjiFrequencyEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch term frequency entries safely
    @MainActor
    private func fetchTermFrequencyEntries(from context: NSManagedObjectContext) -> [TermFrequencyEntry] {
        let request: NSFetchRequest<TermFrequencyEntry> = TermFrequencyEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch pitch accent entries safely
    @MainActor
    private func fetchPitchAccentEntries(from context: NSManagedObjectContext) -> [PitchAccentEntry] {
        let request: NSFetchRequest<PitchAccentEntry> = PitchAccentEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Fetch IPA entries safely
    @MainActor
    private func fetchIPAEntries(from context: NSManagedObjectContext) -> [IPAEntry] {
        let request: NSFetchRequest<IPAEntry> = IPAEntry.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }

    // Helper: Verify directory cleanup
    private func verifyDirectoryCleanup(importManager: DictionaryImportManager, importID: NSManagedObjectID) async {
        let mediaDirectoryExists = try? await importManager.mediaDirectoryExists(for: importID)
        #expect(mediaDirectoryExists == false)
    }

    private func createDictionaryScratchDirectory(dictionaryID: UUID) throws -> URL {
        let scratchSpace = ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryID)
        try scratchSpace.ensureExists()
        let markerURL = scratchSpace.rootURL.appendingPathComponent("marker.txt")
        try "marker".write(to: markerURL, atomically: true, encoding: .utf8)
        return scratchSpace.rootURL
    }

    private func expectDictionaryScratchDirectoryRemoved(dictionaryID: UUID) {
        let scratchURL = ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryID).rootURL
        #expect(!FileManager.default.fileExists(atPath: scratchURL.path), "Dictionary scratch directory should be deleted")
    }

    private func runtimeCompressionDictionaryURL(for dictionaryID: UUID) -> URL? {
        guard let baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return nil
        }

        return GlossaryCompressionCodec.zstdDictionaryURL(dictionaryID: dictionaryID, in: baseDirectory)
    }

    @Test @MainActor func importDictionary_BackgroundTaskExpires_CancelsGracefully() async throws {
        let indexJSON = """
        {
            "title": "Expiring Dictionary",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["期限", "きげん", "", "", 0, ["deadline"], 1, ""]
        ]
        """
        let zipURL = try await createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        await importManager.setBackgroundTaskRunner(delayedExpiringBackgroundTaskRunner())

        let importID = try await importManager.enqueueImport(from: zipURL)
        let queuedImportID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)
        await importManager.waitForCompletion(jobID: queuedImportID)

        let viewContext = persistenceController.container.viewContext
        viewContext.refreshAllObjects()
        let dictionary = getDictionary(from: viewContext, importID: importID)
        let queuedDictionary = getDictionary(from: viewContext, importID: queuedImportID)
        verifyDictionaryCancelled(dictionary)
        verifyDictionaryCancelled(queuedDictionary)
        #expect(fetchTermEntries(from: viewContext).isEmpty)
        #expect(dictionary?.termCount == 0)
        #expect(queuedDictionary?.termCount == 0)
        #expect(fetchDictionaries(from: viewContext).count == 2)
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)
        await verifyDirectoryCleanup(importManager: importManager, importID: queuedImportID)
    }

    @Test @MainActor func deleteDictionary_BackgroundTaskExpires_LeavesPendingDeletionForCleanup() async throws {
        let indexJSON = """
        {
            "title": "Delete Retry Dictionary",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["削除", "さくじょ", "", "", 0, ["delete"], 1, ""]
        ]
        """
        let zipURL = try await createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        await importManager.setBackgroundTaskRunner(nonExpiringBackgroundTaskRunner)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let viewContext = persistenceController.container.viewContext
        #expect(getDictionary(from: viewContext, importID: importID)?.isComplete == true)
        #expect(!fetchTermEntries(from: viewContext).isEmpty)

        await importManager.setBackgroundTaskRunner(expiringBackgroundTaskRunner)
        await importManager.deleteDictionary(dictionaryID: importID)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let pendingDictionary = getDictionary(from: viewContext, importID: importID)
        #expect(pendingDictionary != nil)
        #expect(pendingDictionary?.pendingDeletion == true)
        #expect(!fetchTermEntries(from: viewContext).isEmpty)

        await importManager.setBackgroundTaskRunner(nonExpiringBackgroundTaskRunner)
        await importManager.cleanupPendingDeletions()
        await waitForDictionaryDeletion(in: viewContext, importID: importID)

        #expect(fetchDictionaries(from: viewContext).isEmpty)
        #expect(fetchTermEntries(from: viewContext).isEmpty)
    }

    @Test @MainActor func importDictionary_ValidV3ZIP_ImportsSuccessfully() async throws {
        // Test Description: Verifies that a valid Yomitan ZIP is read, parsed, and batch-inserted into Core Data.
        // - Setup: Mock ZIP with index, tags, and terms.
        // - Action: Call importDictionary
        // - Expected: Dictionary created and marked complete; fetchable data.
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let tagJSON = """
        [
            ["noun", "partOfSpeech", 1, "Common noun", 0],
            ["term-tag", "termTag", 2, "Term tag", 0],
            ["def-tag", "definitionTag", 3, "Definition tag", 0]
        ]
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let termMetaJSON = """
        [
            [
                "食べる",
                "freq",
                {"value": 5000, "displayValue": "5000㋕"}
            ],
            [
                "食べる",
                "pitch",
                {
                    "reading": "たべる",
                    "pitches": [
                        {"position": 2, "nasal": [1], "devoice": [3], "tags": ["noun", "term-tag"]},
                        {"position": "HLL", "tags": ["def-tag"]}
                    ]
                }
            ],
            [
                "食べる",
                "ipa",
                {
                    "reading": "たべる",
                    "transcriptions": [
                        {"ipa": "/tabe̞ɾɯ̟ᵝ/", "tags": ["noun"]},
                        {"ipa": "/tabeɾɯ/"}
                    ]
                }
            ]
        ]
        """
        let kanjiJSON = """
        [
            [
                "食",
                "ショク",
                "た.べ",
                "noun term-tag",
                ["eat", "food"],
                {"freq": "100"}
            ]
        ]
        """
        let kanjiMetaJSON = """
        [
            [
                "食",
                "freq",
                {"value": 200, "displayValue": "200★"}
            ]
        ]
        """

        let mediaFiles = ["images/test.png", "audio/pronunciation.mp3", "nested/folder/file.jpg"]
        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: tagJSON, termJSON: termJSON, termMetaJSON: termMetaJSON, kanjiJSON: kanjiJSON, kanjiMetaJSON: kanjiMetaJSON, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Assert: import does not show as failed or cancelled
        let context = persistenceController.container.viewContext
        let importRecord = getDictionary(from: context, importID: importID)
        #expect(importRecord != nil)
        #expect(importRecord?.isCancelled == false)
        #expect(importRecord?.isFailed == false)
        #expect(importRecord?.displayProgressMessage == FrameworkLocalization.string("Import complete."))

        // Assert: Data persisted
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
        let dict = dictResults.first
        #expect(dict?.title == "TestDict")
        #expect(dict?.revision == "1.0")
        #expect(dict?.format == 3)
        #expect(dict?.isComplete == true)

        guard let dictionary = dictResults.first else {
            Issue.record("Dictionary not found")
            return
        }
        let dictionaryID = dictionary.id

        let tagResults = fetchDictionaryTagMetas(from: context)
        #expect(tagResults.count == 3)

        let nounTag = tagResults.first { $0.name == "noun" }
        #expect(nounTag?.category == "partOfSpeech")
        #expect(nounTag?.notes == "Common noun")
        #expect(nounTag?.order == 1)
        #expect(nounTag?.score == 0)
        #expect(nounTag?.dictionaryID == dictionaryID)

        let termTag = tagResults.first { $0.name == "term-tag" }
        #expect(termTag?.category == "termTag")
        #expect(termTag?.notes == "Term tag")
        #expect(termTag?.order == 2)
        #expect(termTag?.score == 0)
        #expect(termTag?.dictionaryID == dictionaryID)

        let defTag = tagResults.first { $0.name == "def-tag" }
        #expect(defTag?.category == "definitionTag")
        #expect(defTag?.notes == "Definition tag")
        #expect(defTag?.order == 3)
        #expect(defTag?.score == 0)
        #expect(defTag?.dictionaryID == dictionaryID)

        // Assert: TermEntry persisted with all attributes
        let termResults = fetchTermEntries(from: context)
        #expect(termResults.count == 1)
        let termEntry = termResults.first
        #expect(termEntry?.expression == "食べる")
        #expect(termEntry?.reading == "たべる")
        #expect(termEntry?.score == 100)
        #expect(termEntry?.sequence == 1)
        #expect(termEntry?.definitionCount == 1)
        #expect(termEntry?.dictionaryID == dictionaryID)

        // Test glossary (definitions) from compressed payload
        let decoder = JSONDecoder()
        let glossaryPayload: Data? = termEntry?.glossary
        let glossaryJSON = GlossaryCompressionCodec.decodeGlossaryJSON(
            glossaryPayload,
            dictionaryID: termEntry?.dictionaryID
        )
        let definitions = try? decoder.decode([Definition].self, from: glossaryJSON ?? Data())
        #expect(definitions?.count == 1)
        if case let .text(glossaryText) = definitions?.first {
            #expect(glossaryText == "to eat")
        }

        // Test rules (now stored as JSON string)
        let rulesData = termEntry?.rules?.data(using: .utf8)
        let rules = try? decoder.decode([String].self, from: rulesData ?? Data())
        #expect(rules == ["A"])

        // Test definition tags (now stored as JSON string)
        let definitionTagsData = termEntry?.definitionTags?.data(using: .utf8)
        let definitionTags = try? decoder.decode([String].self, from: definitionTagsData ?? Data())
        #expect(definitionTags == ["def-tag"])

        // Test term tags (8th element in V3 schema, now stored as JSON string)
        let termTagsData = termEntry?.termTags?.data(using: .utf8)
        let termTags = (try? decoder.decode([String].self, from: termTagsData ?? Data())) ?? []
        #expect(termTags.sorted() == ["noun", "term-tag"])

        // Assert: KanjiEntry persisted with all V3 attributes
        let kanjiResults = fetchKanjiEntries(from: context)
        #expect(kanjiResults.count == 1)
        let kanji = kanjiResults.first
        #expect(kanji?.character == "食")
        #expect(kanji?.dictionaryID == dictionaryID)

        // Test onyomi (now stored as JSON string)
        let onyomiData = kanji?.onyomi?.data(using: .utf8)
        let onyomi = try? decoder.decode([String].self, from: onyomiData ?? Data())
        #expect(onyomi == ["ショク"])

        // Test kunyomi (now stored as JSON string)
        let kunyomiData = kanji?.kunyomi?.data(using: .utf8)
        let kunyomi = try? decoder.decode([String].self, from: kunyomiData ?? Data())
        #expect(kunyomi == ["た.べ"])

        // Test meanings (now stored as JSON string)
        let meaningsData = kanji?.meanings?.data(using: .utf8)
        let meanings = (try? decoder.decode([String].self, from: meaningsData ?? Data())) ?? []
        #expect(meanings.sorted() == ["eat", "food"])

        // Test stats (now stored as JSON string)
        let statsData = kanji?.stats?.data(using: .utf8)
        let stats = (try? decoder.decode([String: String].self, from: statsData ?? Data())) ?? [:]
        #expect(stats["freq"] == "100")

        // Test tags (now stored as JSON string)
        let kanjiTagsData = kanji?.tags?.data(using: .utf8)
        let kanjiTags = (try? decoder.decode([String].self, from: kanjiTagsData ?? Data())) ?? []
        #expect(kanjiTags.sorted() == ["noun", "term-tag"])

        // Assert: Kanji frequency entries persisted
        let kanjiFreqResults = fetchKanjiFrequencyEntries(from: context)
        #expect(kanjiFreqResults.count == 1)
        let kanjiFreq = kanjiFreqResults.first
        #expect(kanjiFreq?.character == "食")
        #expect(kanjiFreq?.frequencyValue == 200)
        #expect(kanjiFreq?.displayFrequency == "200★")
        #expect(kanjiFreq?.dictionaryID == dictionaryID)

        // Assert: Term frequency entries persisted
        let termFreqResults = fetchTermFrequencyEntries(from: context)
        #expect(termFreqResults.count == 1)
        let termFreq = termFreqResults.first
        #expect(termFreq?.expression == "食べる")
        #expect(termFreq?.reading == "")
        #expect(termFreq?.value == 5000)
        #expect(termFreq?.displayValue == "5000㋕")
        #expect(termFreq?.dictionaryID == dictionaryID)

        // Assert: Pitch accent entries persisted (1 entry with 2 pitches in array)
        let pitchResults = fetchPitchAccentEntries(from: context)
        #expect(pitchResults.count == 1)
        let pitchEntry = pitchResults.first
        #expect(pitchEntry?.expression == "食べる")
        #expect(pitchEntry?.reading == "たべる")
        #expect(pitchEntry?.dictionaryID == dictionaryID)

        // Pitch data is now stored as JSON string
        let pitchesData = pitchEntry?.pitches?.data(using: .utf8)
        let pitches = (try? decoder.decode([PitchAccent].self, from: pitchesData ?? Data())) ?? []
        #expect(pitches.count == 2)

        // First pitch accent: mora position 2 with nasal [1], devoice [3]
        if pitches.count > 0 {
            let moraPitch = pitches[0]
            switch moraPitch.position {
            case let .mora(value):
                #expect(value == 2)
            default: Issue.record("Expected mora position, got \(moraPitch.position)"); return
            }
            #expect(moraPitch.nasal == [1])
            #expect(moraPitch.devoice == [3])
            #expect(moraPitch.tags?.sorted() == ["noun", "term-tag"])
        }

        // Second pitch accent: pattern "HLL"
        if pitches.count > 1 {
            let patternPitch = pitches[1]
            switch patternPitch.position {
            case let .pattern(value):
                #expect(value == "HLL")
            default: Issue.record("Expected pattern position, got \(patternPitch.position)"); return
            }
            #expect(patternPitch.nasal == nil)
            #expect(patternPitch.devoice == nil)
            #expect(patternPitch.tags == ["def-tag"])
        } else {
            Issue.record("Expected second pitch accent entry")
        }

        // Assert: IPA entries persisted (1 entry with 2 transcriptions in array)
        let ipaResults = fetchIPAEntries(from: context)
        #expect(ipaResults.count == 1)
        let ipaEntry = ipaResults.first
        #expect(ipaEntry?.expression == "食べる")
        #expect(ipaEntry?.reading == "たべる")
        #expect(ipaEntry?.dictionaryID == dictionaryID)

        // Transcriptions data is now stored as JSON string
        let transcriptionsData = ipaEntry?.transcriptions?.data(using: .utf8)
        let transcriptions = (try? decoder.decode([IPATranscription].self, from: transcriptionsData ?? Data())) ?? []
        #expect(transcriptions.count == 2)

        // First IPA transcription with tags
        if transcriptions.count > 0 {
            let taggedIPA = transcriptions[0]
            #expect(taggedIPA.ipa == "/tabe̞ɾɯ̟ᵝ/")
            #expect(taggedIPA.tags == ["noun"])
        }

        // Second IPA transcription without tags
        if transcriptions.count > 1 {
            let untaggedIPA = transcriptions[1]
            #expect(untaggedIPA.ipa == "/tabeɾɯ/")
            #expect(untaggedIPA.tags == nil)
        }

        // Assert: Media files are copied to app group directory
        let fileManager = FileManager.default
        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            Issue.record("App group directory not found")
            return
        }
        guard let dictionaryID else {
            Issue.record("Dictionary ID not found")
            return
        }
        let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Verify media directory exists
        #expect(fileManager.fileExists(atPath: mediaDir.path))

        // Verify each media file was copied with correct path structure
        for mediaFile in mediaFiles {
            let expectedPath = mediaDir.appendingPathComponent(mediaFile)
            #expect(fileManager.fileExists(atPath: expectedPath.path), "Media file should exist at: \(expectedPath.path)")

            // Verify it's not empty (our mock files have content)
            let fileSize = try? fileManager.attributesOfItem(atPath: expectedPath.path)[.size] as? Int
            #expect((fileSize ?? 0) > 0, "Media file should not be empty: \(expectedPath.path)")
        }

        // Verify nested directory structure is preserved
        let nestedDir = mediaDir.appendingPathComponent("nested/folder")
        #expect(fileManager.fileExists(atPath: nestedDir.path), "Nested directory structure should be preserved")

        // Verify JSON files are NOT copied to media directory
        let jsonFiles = try fileManager.contentsOfDirectory(at: mediaDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        let jsonInMedia = jsonFiles.filter { $0.pathExtension.lowercased() == "json" }
        #expect(jsonInMedia.isEmpty, "JSON files should not be copied to media directory")
    }

    @Test @MainActor func importDictionary_ValidV1ZIP_ImportsSuccessfully() async throws {
        // Setup: index.json with legacy tagMeta and no tag_bank file.
        let indexJSON = """
        {
            "title": "LegacyDict",
            "revision": "1.0",
            "format": 1,
            "tagMeta": {
                "noun": {"category": "partOfSpeech", "order": 1, "notes": "Common noun", "score": 0},
                "def-tag": {"category": "definitionTag", "order": 2, "notes": "Definition tag", "score": 0}
            }
        }
        """
        // Need a term bank to be a valid dictionary
        let termJSON = """
        [
            ["猫", "ねこ", "noun def-tag", "v1", 100, "cat", "feline"]
        ]
        """
        // V1 kanji bank for testing
        let kanjiJSON = """
        [
            ["猫", "ビョウ", "ねこ", "noun", "cat", "feline animal"]
        ]
        """
        let mediaFiles = ["sounds/audio.wav", "pictures/image.gif"]
        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: kanjiJSON, kanjiMetaJSON: nil, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Assert: import does not show as failed or cancelled
        let context = persistenceController.container.viewContext
        let importRecord = getDictionary(from: context, importID: importID)
        #expect(importRecord != nil)
        #expect(importRecord?.isCancelled == false)
        #expect(importRecord?.isFailed == false)
        #expect(importRecord?.displayProgressMessage == FrameworkLocalization.string("Import complete."))

        let dictionaryResults = fetchDictionaries(from: context)
        #expect(dictionaryResults.count == 1)
        #expect(dictionaryResults.first?.title == "LegacyDict")

        guard let dictionary = dictionaryResults.first else {
            Issue.record("Dictionary not found")
            return
        }
        let dictionaryID = dictionary.id

        let tagResults = fetchDictionaryTagMetas(from: context)
        #expect(tagResults.count == 2)

        let nounTag = tagResults.first { $0.name == "noun" }
        #expect(nounTag?.category == "partOfSpeech")
        #expect(nounTag?.notes == "Common noun")
        #expect(nounTag?.order == 1)
        #expect(nounTag?.score == 0)
        #expect(nounTag?.dictionaryID == dictionaryID)

        let defTag = tagResults.first { $0.name == "def-tag" }
        #expect(defTag?.category == "definitionTag")
        #expect(defTag?.notes == "Definition tag")
        #expect(defTag?.order == 2)
        #expect(defTag?.score == 0)
        #expect(defTag?.dictionaryID == dictionaryID)

        // Assert: TermEntry persisted with all V1 attributes
        let termResults = fetchTermEntries(from: context)
        #expect(termResults.count == 1)
        let termEntry = termResults.first
        #expect(termEntry?.expression == "猫")
        #expect(termEntry?.reading == "ねこ")
        #expect(termEntry?.score == 100)
        #expect(termEntry?.sequence == 0) // V1 doesn't have sequence, defaults to 0
        #expect(termEntry?.definitionCount == 2)
        #expect(termEntry?.dictionaryID == dictionaryID)

        // Test glossary (V1 uses remaining elements as string definitions) - now stored as compressed payload
        let decoder = JSONDecoder()
        let glossaryPayload: Data? = termEntry?.glossary
        let glossaryJSON = GlossaryCompressionCodec.decodeGlossaryJSON(
            glossaryPayload,
            dictionaryID: termEntry?.dictionaryID
        )
        let definitions = try? decoder.decode([Definition].self, from: glossaryJSON ?? Data())
        #expect(definitions?.count == 2)
        if case let .text(firstGlossary) = definitions?[0] {
            #expect(firstGlossary == "cat")
        }
        if case let .text(secondGlossary) = definitions?[1] {
            #expect(secondGlossary == "feline")
        }

        // Test rules (now stored as JSON string)
        let rulesData = termEntry?.rules?.data(using: .utf8)
        let rules = try? decoder.decode([String].self, from: rulesData ?? Data())
        #expect(rules == ["v1"])

        // Test definition tags (V1 has only definition tags, no separate term tags) - now stored as JSON string
        let definitionTagsData = termEntry?.definitionTags?.data(using: .utf8)
        let definitionTags = (try? decoder.decode([String].self, from: definitionTagsData ?? Data())) ?? []
        #expect(definitionTags.sorted() == ["def-tag", "noun"])

        // Test term tags (should be empty for V1) - now stored as JSON string
        let termTagsData = termEntry?.termTags?.data(using: .utf8)
        let termTags = (try? decoder.decode([String].self, from: termTagsData ?? Data())) ?? []
        #expect(termTags.isEmpty == true)

        // Assert: KanjiEntry persisted with all V1 attributes
        let kanjiResults = fetchKanjiEntries(from: context)
        #expect(kanjiResults.count == 1)
        let kanji = kanjiResults.first
        #expect(kanji?.character == "猫")
        #expect(kanji?.dictionaryID == dictionaryID)

        // Test onyomi (now stored as JSON string)
        let onyomiData = kanji?.onyomi?.data(using: .utf8)
        let onyomi = try? decoder.decode([String].self, from: onyomiData ?? Data())
        #expect(onyomi == ["ビョウ"])

        // Test kunyomi (now stored as JSON string)
        let kunyomiData = kanji?.kunyomi?.data(using: .utf8)
        let kunyomi = try? decoder.decode([String].self, from: kunyomiData ?? Data())
        #expect(kunyomi == ["ねこ"])

        // Test meanings (V1 format has meanings as remaining string elements) - now stored as JSON string
        let meaningsData = kanji?.meanings?.data(using: .utf8)
        let meanings = (try? decoder.decode([String].self, from: meaningsData ?? Data())) ?? []
        #expect(meanings.sorted() == ["cat", "feline animal"])

        // Test stats (V1 doesn't have stats, should be empty) - now stored as JSON string
        let statsData = kanji?.stats?.data(using: .utf8)
        let stats = (try? decoder.decode([String: String].self, from: statsData ?? Data())) ?? [:]
        #expect(stats.isEmpty == true)

        // Test tags (now stored as JSON string)
        let kanjiTagsData = kanji?.tags?.data(using: .utf8)
        let kanjiTags = try? decoder.decode([String].self, from: kanjiTagsData ?? Data())
        #expect(kanjiTags == ["noun"])

        // Assert: Media files are copied for V1 format as well
        let fileManager = FileManager.default
        guard let appGroupDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            Issue.record("App group directory not found")
            return
        }
        guard let dictionaryID else {
            Issue.record("Dictionary ID not found")
            return
        }
        let mediaDir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Verify media directory exists
        #expect(fileManager.fileExists(atPath: mediaDir.path))

        // Verify each media file was copied
        for mediaFile in mediaFiles {
            let expectedPath = mediaDir.appendingPathComponent(mediaFile)
            #expect(fileManager.fileExists(atPath: expectedPath.path), "V1 media file should exist at: \(expectedPath.path)")
        }
    }

    @Test @MainActor func importDictionary_RuntimeGlossaryCompression_PersistsAndCleansUpPerDictionaryDictionary() async throws {
        let indexJSON = """
        {
            "title": "RuntimeGlossaryCompression",
            "revision": "1.0",
            "format": 3
        }
        """
        let termRows = (0 ..< 384).map { index in
            let glossary = String(repeating: "structured-definition-\(index)-", count: 32)
            return #"["単語\#(index)","たんご\#(index)","","",\#(1000 - index),["\#(glossary)"],\#(index),""]"#
        }
        let termJSON = """
        [
        \(termRows.joined(separator: ",\n"))
        ]
        """

        let zipURL = try await createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdRuntimeV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        guard let dictionary = getDictionary(from: context, importID: importID),
              let dictionaryID = dictionary.id,
              let compressionDictionaryURL = runtimeCompressionDictionaryURL(for: dictionaryID)
        else {
            Issue.record("Failed to resolve imported dictionary or runtime compression dictionary path")
            return
        }
        _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryID)

        #expect(dictionary.isComplete == true)
        #expect(FileManager.default.fileExists(atPath: compressionDictionaryURL.path))

        let glossaryPayload = fetchTermEntries(from: context).first?.glossary
        let glossaryJSON = GlossaryCompressionCodec.decodeGlossaryJSON(
            glossaryPayload,
            dictionaryID: dictionaryID
        )
        let definitions = try? JSONDecoder().decode([Definition].self, from: glossaryJSON ?? Data())
        #expect(definitions?.isEmpty == false)

        await importManager.deleteDictionary(dictionaryID: importID)
        await waitForDictionaryDeletion(in: context, importID: importID)

        #expect(!FileManager.default.fileExists(atPath: compressionDictionaryURL.path))
        expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryID)
        #expect(
            GlossaryCompressionCodec.decodeGlossaryJSON(
                glossaryPayload,
                dictionaryID: dictionaryID
            ) == nil
        )
    }

    @Test @MainActor func importDictionary_RuntimeGlossaryCompressionFallback_UsesPlainZSTDWithoutPersistingDictionary() async throws {
        let indexJSON = """
        {
            "title": "RuntimeGlossaryCompressionFallback",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "", "", 100, ["to eat"], 1, ""]
        ]
        """

        let zipURL = try await createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdRuntimeV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        guard let dictionary = getDictionary(from: context, importID: importID),
              let dictionaryID = dictionary.id,
              let compressionDictionaryURL = runtimeCompressionDictionaryURL(for: dictionaryID),
              let glossaryPayload = fetchTermEntries(from: context).first?.glossary
        else {
            Issue.record("Failed to resolve imported fallback dictionary or payload")
            return
        }

        #expect(dictionary.isComplete == true)
        #expect(!FileManager.default.fileExists(atPath: compressionDictionaryURL.path))
        #expect(glossaryPayload.starts(with: Data("MRG2".utf8)))

        let glossaryJSON = GlossaryCompressionCodec.decodeGlossaryJSON(
            glossaryPayload,
            dictionaryID: dictionaryID
        )
        let definitions = try? JSONDecoder().decode([Definition].self, from: glossaryJSON ?? Data())
        #expect(definitions?.count == 1)
        if case let .text(firstDefinition) = definitions?.first {
            #expect(firstDefinition == "to eat")
        } else {
            Issue.record("Expected fallback glossary definition to decode as text")
        }
    }

    @Test func glossaryCompressionVersionsToTry_appendsUncompressedFallbackLast() {
        let versions = DictionaryImportManager.glossaryCompressionVersionsToTry(
            requested: .zstdRuntimeV1,
            prepared: .zstdRuntimeV1
        )

        #expect(versions == [.zstdRuntimeV1, .zstdV1, .lzfseV1, .uncompressedV1])
    }

    @Test @MainActor func cleanupPartialImportForCompressionRetry_ContinuesWhenDeleteThrowsAfterRemovingRows() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        let containerBox = PersistentContainerBox(container: persistenceController.container)
        let dictionaryUUID = UUID()
        _ = try await seedPartiallyImportedTermEntry(
            in: persistenceController.container,
            dictionaryUUID: dictionaryUUID
        )

        await importManager.setTestDeleteDictionaryEntitiesHook { dictionaryUUID, _ in
            let cleanupContext = containerBox.container.newBackgroundContext()
            try await cleanupContext.perform {
                let fetchRequest: NSFetchRequest<TermEntry> = TermEntry.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "dictionaryID == %@", dictionaryUUID as CVarArg)
                let entries = try cleanupContext.fetch(fetchRequest)
                for entry in entries {
                    cleanupContext.delete(entry)
                }
                try cleanupContext.save()
            }

            throw NSError(
                domain: "DictionaryPersistenceTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated cleanup failure"]
            )
        }

        try await importManager.cleanupPartialImportForCompressionRetry(
            dictionaryUUID: dictionaryUUID,
            batchSize: 10000
        )

        let context = persistenceController.container.viewContext
        #expect(fetchTermEntries(from: context).isEmpty)
    }

    @Test @MainActor func cleanupPartialImportForCompressionRetry_ThrowsWhenRowsRemain() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        let dictionaryUUID = UUID()
        _ = try await seedPartiallyImportedTermEntry(
            in: persistenceController.container,
            dictionaryUUID: dictionaryUUID
        )

        await importManager.setTestDeleteDictionaryEntitiesHook { _, _ in }

        do {
            try await importManager.cleanupPartialImportForCompressionRetry(
                dictionaryUUID: dictionaryUUID,
                batchSize: 10000
            )
            Issue.record("Expected compression retry cleanup to fail when rows remain")
        } catch {
            #expect(error.localizedDescription.contains("Remaining rows: TermEntry=1"))
        }

        let context = persistenceController.container.viewContext
        #expect(fetchTermEntries(from: context).count == 1)
    }

    // MARK: - Cancellation Tests

    @Test func importDictionary_CancelAfterIndex_CleansUpProperly() async throws {
        // Test cancellation after index processing
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        // Set up cancellation hook to trigger after index processing
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 1 {
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        let dictionaryUUID = await MainActor.run {
            getDictionary(from: persistenceController.container.viewContext, importID: importID)?.id
        }
        if let dictionaryUUID {
            _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryUUID)
        }

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        await MainActor.run {
            let dictionary = getDictionary(from: context, importID: importID)
            verifyDictionaryCancelled(dictionary)

            // Verify dictionary record exists but no entries were created
            let dictResults = fetchDictionaries(from: context)
            #expect(dictResults.count == 1)

            let termResults = fetchTermEntries(from: context)
            #expect(termResults.isEmpty)
        }

        await verifyDirectoryCleanup(importManager: importManager, importID: importID)
        if let dictionaryUUID {
            expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryUUID)
        }
    }

    @Test func importDictionary_CancelAfterDataProcessing_CleansUpProperly() async throws {
        // Test cancellation after data processing but before media copy
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil, mediaFiles: ["test.png"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        // Set up cancellation hook to trigger after data processing
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 2 { // Second call is after data processing
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        let dictionaryUUID = await MainActor.run {
            getDictionary(from: persistenceController.container.viewContext, importID: importID)?.id
        }
        if let dictionaryUUID {
            _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryUUID)
        }

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        await MainActor.run {
            let context = persistenceController.container.viewContext
            let dictionary = getDictionary(from: context, importID: importID)
            verifyDictionaryCancelled(dictionary)

            // Verify dictionary record exists but no entries were created
            let dictResults = fetchDictionaries(from: context)
            #expect(dictResults.count == 1)
        }
        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)
        if let dictionaryUUID {
            expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryUUID)
        }
    }

    @Test func importDictionary_CancelAfterMediaCopy_CleansUpProperly() async throws {
        // Test cancellation after media files are copied
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let mediaFiles = ["images/test.png", "audio/sound.mp3"]
        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        // Set up cancellation hook to trigger after media copy
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 3 { // After media copy
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        let dictionaryUUID = await MainActor.run {
            getDictionary(from: persistenceController.container.viewContext, importID: importID)?.id
        }
        if let dictionaryUUID {
            _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryUUID)
        }

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        await MainActor.run {
            let context = persistenceController.container.viewContext
            let dictionary = getDictionary(from: context, importID: importID)
            verifyDictionaryCancelled(dictionary)
            // Verify dictionary record exists but no entries were created
            let dictResults = fetchDictionaries(from: context)
            #expect(dictResults.count == 1)
        }
        // Verify cleanup (media directory should be removed despite being created)
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)
        if let dictionaryUUID {
            expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryUUID)
        }
    }

    @Test @MainActor func importDictionary_CancelQueuedJob_CleansUpProperly() async throws {
        // Test cancellation of a job that's still in queue (not started)
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Cancel immediately (while still in queue)
        await importManager.cancelImport(jobID: importID)

        // Wait a bit to ensure cancellation is processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryCancelled(dictionary)

        // For queued jobs, no directories should be created
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists but no entries were created
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    // MARK: - Failure Tests

    @Test @MainActor func importDictionary_MalformedZIP_FailsAndCleansUp() async throws {
        // Test failure with corrupted ZIP file
        let zipURL = try createCorruptedZIP()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryFailed(dictionary)

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    @Test @MainActor func importDictionary_MissingIndexJSON_FailsAndCleansUp() async throws {
        // Test failure when index.json is missing
        let zipURL = try await createZIPWithoutIndex()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryFailed(dictionary)

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    @Test @MainActor func importDictionary_InvalidJSON_FailsAndCleansUp() async throws {
        // Test failure with malformed JSON in bank files
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let invalidTermJSON = """
        [
            ["invalid", "json", "structure"  // Missing closing bracket and quotes
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: invalidTermJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryFailed(dictionary)

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    @Test @MainActor func importDictionary_UnsupportedFormat_FailsAndCleansUp() async throws {
        // Test failure with unsupported format version
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 2
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryFailed(dictionary)

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    @Test func importDictionary_FileSystemError_FailsAndCleansUp() async throws {
        // Test failure with file system error during processing
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["食べる", "たべる", "def-tag", "A", 100, ["to eat"], 1, "noun term-tag"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        // Set up error injection to simulate file system error
        await importManager.setTestErrorInjection {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [
                NSLocalizedDescriptionKey: "Simulated file system error",
            ])
        }

        let importID = try await importManager.enqueueImport(from: zipURL)
        let dictionaryUUID = await MainActor.run {
            getDictionary(from: persistenceController.container.viewContext, importID: importID)?.id
        }
        if let dictionaryUUID {
            _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryUUID)
        }

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        await MainActor.run {
            let context = persistenceController.container.viewContext
            let dictionary = getDictionary(from: context, importID: importID)
            verifyDictionaryFailed(dictionary)

            // Verify dictionary record exists
            let dictResults = fetchDictionaries(from: context)
            #expect(dictResults.count == 1)
        }

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)
        if let dictionaryUUID {
            expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryUUID)
        }
    }

    @Test @MainActor func importDictionary_NoBankFiles_FailsAndCleansUp() async throws {
        // Test failure when no valid bank files are present
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """

        // Create ZIP with only index.json, no bank files
        let zipURL = try await createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: nil, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let dictionary = getDictionary(from: context, importID: importID)
        verifyDictionaryFailed(dictionary)

        // Verify cleanup
        await verifyDirectoryCleanup(importManager: importManager, importID: importID)

        // Verify dictionary record exists
        let dictResults = fetchDictionaries(from: context)
        #expect(dictResults.count == 1)
    }

    @Test @MainActor func cleanupInterruptedDictionaryImports_MarksFailedAndCleansEntries() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let dictionaryUUID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        let importID = try await context.perform {
            let dictionary = Dictionary(context: context)
            dictionary.id = dictionaryUUID
            dictionary.title = "Interrupted Dictionary"
            dictionary.timeQueued = Date()
            dictionary.isComplete = false
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.isStarted = true
            dictionary.displayProgressMessage = "Importing..."
            dictionary.indexProcessed = true
            dictionary.banksProcessed = true
            dictionary.mediaImported = true
            dictionary.termCount = 1

            let termEntry = TermEntry(context: context)
            termEntry.id = UUID()
            termEntry.dictionaryID = dictionaryUUID
            termEntry.expression = "食べる"
            termEntry.reading = "たべる"
            termEntry.glossary = try GlossaryCompressionCodec.encodeGlossaryJSON(
                Data("[]".utf8),
                using: .zstdV1,
                dictionaryID: nil
            )
            termEntry.definitionTags = "[]"
            termEntry.termTags = "[]"
            termEntry.rules = "[]"
            termEntry.score = 0
            termEntry.sequence = 1

            try context.save()
            return dictionary.objectID
        }

        var mediaDir: URL?
        if let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) {
            let dir = appGroupDir.appendingPathComponent("Media").appendingPathComponent(dictionaryUUID.uuidString)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let marker = dir.appendingPathComponent("marker.txt")
            try? "marker".write(to: marker, atomically: true, encoding: .utf8)
            mediaDir = dir
        }
        _ = try createDictionaryScratchDirectory(dictionaryID: dictionaryUUID)

        await importManager.cleanupInterruptedImports()

        let viewContext = persistenceController.container.viewContext
        let dictionary = getDictionary(from: viewContext, importID: importID)
        verifyDictionaryFailed(dictionary)
        #expect(dictionary?.termCount == 0)
        #expect(dictionary?.indexProcessed == false)
        #expect(dictionary?.banksProcessed == false)
        #expect(dictionary?.mediaImported == false)
        #expect(fetchTermEntries(from: viewContext).isEmpty)

        if let mediaDir {
            #expect(!FileManager.default.fileExists(atPath: mediaDir.path), "Media directory should be deleted")
        }
        expectDictionaryScratchDirectoryRemoved(dictionaryID: dictionaryUUID)
    }

    @Test @MainActor func checkForUpdates_MarksUpdateReadyAndStoresDownloadURL() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        let networkProvider = MockUpdateNetworkProvider()
        let updateManager = DictionaryUpdateManager(
            container: persistenceController.container,
            importManager: importManager,
            networkProvider: networkProvider
        )

        let indexURL = try #require(URL(string: "https://example.com/index.json"))
        let indexJSON = """
        {
            "title": "Test Dictionary",
            "revision": "2.0",
            "format": 3,
            "downloadUrl": "https://example.com/new.zip",
            "indexUrl": "https://example.com/index.json",
            "isUpdatable": true
        }
        """
        networkProvider.queueResponse(url: indexURL, data: Data(indexJSON.utf8))

        let context = persistenceController.container.newBackgroundContext()
        let dictionaryID = try await context.perform {
            let dictionary = Dictionary(context: context)
            dictionary.id = UUID()
            dictionary.title = "Test Dictionary"
            dictionary.timeQueued = Date()
            dictionary.isComplete = true
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.pendingDeletion = false
            dictionary.isUpdatable = true
            dictionary.indexURL = "https://example.com/index.json"
            dictionary.downloadURL = "https://example.com/old.zip"
            dictionary.revision = "1.0"
            try context.save()
            return dictionary.objectID
        }

        let updateCount = await updateManager.checkForUpdates()

        let viewContext = persistenceController.container.viewContext
        let dictionary = getDictionary(from: viewContext, importID: dictionaryID)
        #expect(updateCount == 1)
        #expect(dictionary?.updateReady == true)
        #expect(dictionary?.downloadURL == "https://example.com/new.zip")
    }

    @Test @MainActor func updateDictionary_CopiesPreferencesAndUpdatesAnki() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )
        let networkProvider = MockUpdateNetworkProvider()
        let updateManager = DictionaryUpdateManager(
            container: persistenceController.container,
            importManager: importManager,
            networkProvider: networkProvider
        )
        let ankiUpdater = MockAnkiUpdater()
        await updateManager.setAnkiPreferencesUpdater(ankiUpdater)

        let updatedIndexJSON = """
        {
            "title": "Updated Dictionary",
            "revision": "2.0",
            "format": 3,
            "downloadUrl": "https://example.com/update.zip",
            "indexUrl": "https://example.com/index.json",
            "isUpdatable": true
        }
        """
        let termJSON = """
        [
            ["更新", "こうしん", "", "", 0, ["update"], 1, ""]
        ]
        """
        let termMetaJSON = """
        [
            [
                "更新",
                "freq",
                {"value": 1200, "displayValue": "1200"}
            ],
            [
                "更新",
                "pitch",
                {
                    "reading": "こうしん",
                    "pitches": [
                        {"position": 2}
                    ]
                }
            ],
            [
                "更新",
                "ipa",
                {
                    "reading": "こうしん",
                    "transcriptions": [
                        {"ipa": "/koːɕin/"}
                    ]
                }
            ]
        ]
        """
        let kanjiJSON = """
        [
            [
                "更",
                "コウ",
                "さら",
                "",
                ["renew"],
                {"freq": "500"}
            ]
        ]
        """
        let zipURL = try await createMockZIP(
            indexJSON: updatedIndexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: termMetaJSON,
            kanjiJSON: kanjiJSON,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let downloadURL = try #require(URL(string: "https://example.com/update.zip"))
        let zipData = try Data(contentsOf: zipURL)
        networkProvider.queueResponse(url: downloadURL, data: zipData, expectedLength: Int64(zipData.count))

        let oldDictionaryUUID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        let oldDictionaryID = try await context.perform {
            let dictionary = Dictionary(context: context)
            dictionary.id = oldDictionaryUUID
            dictionary.title = "Old Dictionary"
            dictionary.timeQueued = Date()
            dictionary.isComplete = true
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.pendingDeletion = false
            dictionary.isUpdatable = true
            dictionary.updateReady = true
            dictionary.downloadURL = "https://example.com/update.zip"
            dictionary.indexURL = "https://example.com/index.json"
            dictionary.revision = "1.0"
            dictionary.termDisplayPriority = 2
            dictionary.kanjiDisplayPriority = 3
            dictionary.ipaDisplayPriority = 4
            dictionary.pitchDisplayPriority = 5
            dictionary.termFrequencyDisplayPriority = 6
            dictionary.kanjiFrequencyDisplayPriority = 7
            dictionary.termResultsEnabled = true
            dictionary.kanjiResultsEnabled = true
            dictionary.termFrequencyEnabled = true
            dictionary.kanjiFrequencyEnabled = false
            dictionary.pitchAccentEnabled = true
            dictionary.ipaEnabled = true
            dictionary.termCount = 1
            dictionary.kanjiCount = 1
            dictionary.termFrequencyCount = 1
            dictionary.kanjiFrequencyCount = 1
            dictionary.pitchesCount = 1
            dictionary.ipaCount = 1
            try context.save()
            return dictionary.objectID
        }

        let taskID = try await updateManager.enqueueUpdate(for: oldDictionaryID)
        await updateManager.waitForCompletion(taskID: taskID)

        let viewContext = persistenceController.container.viewContext
        let dictionaries = fetchDictionaries(from: viewContext)
        let oldDictionary = dictionaries.first { $0.id == oldDictionaryUUID }
        let newDictionary = dictionaries.first { $0.id != oldDictionaryUUID && $0.isComplete }
        #expect(oldDictionary == nil || oldDictionary?.pendingDeletion == true)
        #expect(newDictionary != nil)

        if let newDictionary {
            #expect(newDictionary.termDisplayPriority == 2)
            #expect(newDictionary.kanjiDisplayPriority == 3)
            #expect(newDictionary.ipaDisplayPriority == 4)
            #expect(newDictionary.pitchDisplayPriority == 5)
            #expect(newDictionary.termFrequencyDisplayPriority == 6)
            #expect(newDictionary.kanjiFrequencyDisplayPriority == 7)
            #expect(newDictionary.termResultsEnabled == true)
            #expect(newDictionary.kanjiResultsEnabled == true)
            #expect(newDictionary.termFrequencyEnabled == true)
            #expect(newDictionary.kanjiFrequencyEnabled == false)
            #expect(newDictionary.pitchAccentEnabled == true)
            #expect(newDictionary.ipaEnabled == true)
        }

        let replacement = await ankiUpdater.lastReplacement()
        #expect(replacement?.0 == oldDictionaryUUID)
        #expect(replacement?.1 == newDictionary?.id)
    }

    @Test @MainActor func cleanupInterruptedUpdateImports_RetriesInsteadOfFailing() async throws {
        let persistenceController = makeDictionaryPersistenceController(storeKind: .temporarySQLite)
        let importManager = DictionaryImportManager(
            container: persistenceController.container,
            glossaryCompressionVersion: .zstdV1
        )

        let indexJSON = """
        {
            "title": "Retry Dictionary",
            "revision": "1.0",
            "format": 3
        }
        """
        let termJSON = """
        [
            ["再試行", "さいしこう", "", "", 0, ["retry"], 1, ""]
        ]
        """
        let zipURL = try await createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: termJSON,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let dictionaryUUID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        let importID = try await context.perform {
            let dictionary = Dictionary(context: context)
            dictionary.id = dictionaryUUID
            dictionary.title = "Retry Dictionary"
            dictionary.file = zipURL
            dictionary.timeQueued = Date()
            dictionary.isComplete = false
            dictionary.isFailed = false
            dictionary.isCancelled = false
            dictionary.isStarted = true
            dictionary.updateTaskID = UUID()
            dictionary.displayProgressMessage = "Importing..."
            dictionary.termCount = 1
            try context.save()
            return dictionary.objectID
        }

        await importManager.cleanupInterruptedImports()
        await importManager.waitForCompletion(jobID: importID)

        let viewContext = persistenceController.container.viewContext
        let dictionary = getDictionary(from: viewContext, importID: importID)
        #expect(dictionary?.isComplete == true)
        #expect(dictionary?.isFailed == false)
    }
}
