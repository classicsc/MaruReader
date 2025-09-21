//
//  DictionaryPersistenceTests.swift
//  MaruReaderTests
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import Foundation
@testable import MaruReader
import Testing
import Zip

struct DictionaryPersistenceTests {
    // Custom errors for diagnostics
    enum MockZipError: Error {
        case invalidJSON(String)
        case fileWriteFailed(URL)
        case fileNotFound(URL)
        case missingFile(String)
    }

    // Helper: Create a mock ZIP file with given JSON contents
    private func createMockZIP(indexJSON: String, tagJSON: String?, termJSON: String?, termMetaJSON: String?, kanjiJSON: String?, kanjiMetaJSON: String?, mediaFiles: [String]? = nil) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        debugPrint("Created temp directory: \(tempDir.path)")

        // Always create index.json as it's required
        let indexURL = tempDir.appendingPathComponent("index.json")
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
            let tagURL = tempDir.appendingPathComponent("tag_bank_1.json")
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
            let termURL = tempDir.appendingPathComponent("term_bank_1.json")
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
            let termMetaURL = tempDir.appendingPathComponent("term_meta_bank_1.json")
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
            let kanjiURL = tempDir.appendingPathComponent("kanji_bank_1.json")
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
            let kanjiMetaURL = tempDir.appendingPathComponent("kanji_meta_bank_1.json")
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
                let mediaURL = tempDir.appendingPathComponent(mediaPath)

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
        // Get all items in the temp directory
        let tempContents = try FileManager.default.contentsOfDirectory(at: tempDir.absoluteURL, includingPropertiesForKeys: [])

        try Zip.zipFiles(paths: tempContents, zipFilePath: zipURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw MockZipError.fileNotFound(zipURL)
        }
        debugPrint("Created ZIP: \(zipURL.path)")

        return zipURL
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
    private func createZIPWithoutIndex() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create some other file
        let dummyURL = tempDir.appendingPathComponent("dummy.txt")
        try "dummy content".write(to: dummyURL, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("no_index.zip")
        try Zip.zipFiles(paths: [dummyURL], zipFilePath: zipURL, password: nil, progress: nil)

        return zipURL
    }

    // Helper: Verify job is properly cancelled
    private func verifyJobCancelled(_ job: MaruReader.DictionaryZIPFileImport?) {
        #expect(job != nil)
        #expect(job?.isCancelled == true)
        #expect(job?.isFailed == false)
        #expect(job?.isComplete == false)
        #expect(job?.timeCancelled != nil)
    }

    // Helper: Verify job is properly marked as failed
    private func verifyJobFailed(_ job: MaruReader.DictionaryZIPFileImport?) {
        #expect(job != nil)
        #expect(job?.isFailed == true)
        #expect(job?.isCancelled == false)
        #expect(job?.isComplete == false)
        #expect(job?.timeFailed != nil)
        #expect(job?.displayProgressMessage?.isEmpty == false)
    }

    // Helper: Verify directory cleanup
    private func verifyDirectoryCleanup(importManager: MaruReader.DictionaryImportManager, job: MaruReader.DictionaryZIPFileImport) async {
        #expect(await importManager.workingDirectoryExists(for: job) == false)
        #expect(await importManager.mediaDirectoryExists(for: job) == false)
    }

    @Test func importDictionary_ValidV3ZIP_ImportsSuccessfully() async throws {
        // Test Description: Verifies that a valid Yomitan ZIP is unzipped, parsed, and batch-inserted into Core Data.
        // - Setup: Mock ZIP with index, tags, and terms.
        // - Action: Call importDictionary
        // - Expected: DictionaryEntry created and marked complete; fetchable data.
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
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: tagJSON, termJSON: termJSON, termMetaJSON: termMetaJSON, kanjiJSON: kanjiJSON, kanjiMetaJSON: kanjiMetaJSON, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Assert: import does not show as failed or cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        #expect(job != nil)
        #expect(job?.isCancelled == false)
        #expect(job?.isFailed == false)
        #expect(job?.displayProgressMessage == "Import complete.")
        // Assert: tag banks marked processed
        let tagBanks = job?.tagBanks as? [URL]
        let processedTagBanks = job?.processedTagBanks as? [URL]
        // Confirm contents match
        let tagBankSet = Set(tagBanks ?? [])
        let processedTagBankSet = Set(processedTagBanks ?? [])
        #expect(tagBankSet == processedTagBankSet)

        // Assert: Data persisted

        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResult = try? context.fetch(dictRequest).first
        #expect(dictResult?.title == "TestDict")
        #expect(dictResult?.revision == "1.0")
        #expect(dictResult?.format == 3)
        #expect(dictResult?.isComplete == true)

        let tagRequest: NSFetchRequest<MaruReader.DictionaryTagMeta> = MaruReader.DictionaryTagMeta.fetchRequest()
        let tagResults = try context.fetch(tagRequest)
        #expect(tagResults.count == 3)

        let nounTag = tagResults.first { $0.name == "noun" }
        #expect(nounTag?.category == "partOfSpeech")
        #expect(nounTag?.notes == "Common noun")
        #expect(nounTag?.order == 1)
        #expect(nounTag?.score == 0)
        #expect(nounTag?.dictionary?.title == "TestDict")

        let termTag = tagResults.first { $0.name == "term-tag" }
        #expect(termTag?.category == "termTag")
        #expect(termTag?.notes == "Term tag")
        #expect(termTag?.order == 2)
        #expect(termTag?.score == 0)
        #expect(termTag?.dictionary?.title == "TestDict")

        let defTag = tagResults.first { $0.name == "def-tag" }
        #expect(defTag?.category == "definitionTag")
        #expect(defTag?.notes == "Definition tag")
        #expect(defTag?.order == 3)
        #expect(defTag?.score == 0)
        #expect(defTag?.dictionary?.title == "TestDict")

        // Assert: Term and TermEntry persisted with all attributes
        let termRequest: NSFetchRequest<MaruReader.Term> = MaruReader.Term.fetchRequest()
        let termResult = try? context.fetch(termRequest)
        #expect(termResult?.count == 2) // One with reading, one with empty reading from frequency

        // Find the term with reading (from term bank, pitch, and IPA)
        let termWithReading = termResult?.first { $0.reading == "たべる" }
        #expect(termWithReading?.expression == "食べる")
        #expect(termWithReading?.reading == "たべる")
        #expect(termWithReading?.id != nil)

        // Find the term with empty reading (from frequency)
        let termWithoutReading = termResult?.first { $0.reading == "" }
        #expect(termWithoutReading?.expression == "食べる")
        #expect(termWithoutReading?.reading == "")
        #expect(termWithoutReading?.id != nil)

        let termEntryResult = try? context.fetch(MaruReader.TermEntry.fetchRequest())
        #expect(termEntryResult?.count == 1)
        let termEntry = termEntryResult?.first
        #expect(termEntry?.score == 100)
        #expect(termEntry?.sequence == 1)
        #expect(termEntry?.id != nil)

        // Test glossary (definitions)
        let definitions = termEntry?.glossary as? [MaruReader.Definition]
        #expect(definitions?.count == 1)
        if case let .text(glossaryText) = definitions?.first {
            #expect(glossaryText == "to eat")
        }

        // Test rules
        let rules = termEntry?.rules as? [String]
        #expect(rules == ["A"])

        // Test definition tags (3rd element in V3 schema)
        let definitionTags = termEntry?.definitionTags as? [String]
        #expect(definitionTags == ["def-tag"])

        // Test term tags (8th element in V3 schema)
        let termTags = termEntry?.termTags as? [String]
        #expect(termTags?.sorted() == ["noun", "term-tag"])

        // Test relationships
        #expect(termEntry?.term === termWithReading)
        #expect(termEntry?.dictionary === dictResult)
        let termEntries = termWithReading?.entries as? Set<MaruReader.TermEntry>
        if let termEntry, let termEntries {
            #expect(termEntries.contains(termEntry))
        }

        // Assert: Tag linking worked through richTermTags relationship
        #expect(termEntry?.richTermTags?.count == 2)
        let linkedTermTags = termEntry?.richTermTags?.allObjects as? [MaruReader.DictionaryTagMeta]
        let termTagNames = linkedTermTags?.map { $0.name ?? "" }.sorted()
        #expect(termTagNames == ["noun", "term-tag"])

        // Assert: Definition tag linking through richDefinitionTags relationship
        #expect(termEntry?.richDefinitionTags?.count == 1)
        let linkedDefTag = termEntry?.richDefinitionTags?.allObjects.first as? MaruReader.DictionaryTagMeta
        #expect(linkedDefTag?.name == "def-tag")

        // Assert: Kanji and KanjiEntry persisted with all V3 attributes
        let kanjiRequest: NSFetchRequest<MaruReader.Kanji> = MaruReader.Kanji.fetchRequest()
        let kanjiResult = try context.fetch(kanjiRequest)
        #expect(kanjiResult.count == 1)
        let kanji = kanjiResult.first
        #expect(kanji?.character == "食")
        #expect(kanji?.id != nil)

        let kanjiEntryResult = try context.fetch(MaruReader.KanjiEntry.fetchRequest())
        #expect(kanjiEntryResult.count == 1)
        let kanjiEntry = kanjiEntryResult.first
        #expect(kanjiEntry?.id != nil)

        // Test onyomi
        let onyomi = kanjiEntry?.onyomi as? [String]
        #expect(onyomi == ["ショク"])

        // Test kunyomi
        let kunyomi = kanjiEntry?.kunyomi as? [String]
        #expect(kunyomi == ["た.べ"])

        // Test meanings
        let meanings = kanjiEntry?.meanings as? [String]
        #expect(meanings?.sorted() == ["eat", "food"])

        // Test stats
        let stats = kanjiEntry?.stats as? [String: String]
        #expect(stats?["freq"] == "100")

        // Test tags
        let kanjiTags = kanjiEntry?.tags as? [String]
        #expect(kanjiTags?.sorted() == ["noun", "term-tag"])

        // Test relationships
        #expect(kanjiEntry?.kanji === kanji)
        #expect(kanjiEntry?.dictionary === dictResult)
        if let kanjiEntry, let entries = kanji?.entries {
            #expect(entries.contains(kanjiEntry))
        } else {
            Issue.record("Kanji entries relationship is nil")
        }

        // Assert: Tag linking for kanji through richTags relationship
        #expect(kanjiEntry?.richTags?.count == 2)
        let linkedKanjiTags = kanjiEntry?.richTags?.allObjects as? [MaruReader.DictionaryTagMeta]
        let kanjiTagNames = linkedKanjiTags?.map { $0.name ?? "" }.sorted()
        #expect(kanjiTagNames == ["noun", "term-tag"])

        // Assert: Kanji frequency entries persisted
        let kanjiFreqRequest: NSFetchRequest<MaruReader.KanjiFrequencyEntry> = MaruReader.KanjiFrequencyEntry.fetchRequest()
        let kanjiFreqResults = try context.fetch(kanjiFreqRequest)
        #expect(kanjiFreqResults.count == 1)
        let kanjiFreq = kanjiFreqResults.first
        #expect(kanjiFreq?.frequencyValue == 200)
        #expect(kanjiFreq?.displayFrequency == "200★")
        #expect(kanjiFreq?.dictionary === dictResult)
        #expect(kanjiFreq?.kanji?.character == "食")

        // Assert: Term frequency entries persisted
        let termFreqRequest: NSFetchRequest<MaruReader.TermFrequencyEntry> = MaruReader.TermFrequencyEntry.fetchRequest()
        let termFreqResults = try context.fetch(termFreqRequest)
        #expect(termFreqResults.count == 1)
        let termFreq = termFreqResults.first
        #expect(termFreq?.value == 5000)
        #expect(termFreq?.displayValue == "5000㋕")
        #expect(termFreq?.dictionary === dictResult)
        #expect(termFreq?.term?.expression == "食べる")
        #expect(termFreq?.term?.reading == "") // Frequency entries use empty reading term

        // Assert: Pitch accent entries persisted (2 pitch accents from the test data)
        let pitchRequest: NSFetchRequest<MaruReader.PitchAccentEntry> = MaruReader.PitchAccentEntry.fetchRequest()
        let pitchResults = try context.fetch(pitchRequest)
        #expect(pitchResults.count == 2)

        // First pitch accent: mora position 2 with nasal [1], devoice [3]
        let moraPitch = pitchResults.first { $0.mora == 2 }
        #expect(moraPitch != nil)
        #expect(moraPitch?.pattern == nil)
        #expect(moraPitch?.mora == 2)
        let moraNasal = moraPitch?.nasal as? [Int]
        let moraDevoice = moraPitch?.devoice as? [Int]
        #expect(moraNasal == [1])
        #expect(moraDevoice == [3])
        let moraTags = moraPitch?.tags as? [String]
        #expect(moraTags?.sorted() == ["noun", "term-tag"])
        #expect(moraPitch?.dictionary === dictResult)
        #expect(moraPitch?.term?.expression == "食べる")
        #expect(moraPitch?.term?.reading == "たべる")

        // Second pitch accent: pattern "HLL"
        let patternPitch = pitchResults.first { $0.pattern == "HLL" }
        #expect(patternPitch != nil)
        #expect(patternPitch?.pattern == "HLL")
        #expect(patternPitch?.mora == 0)
        #expect(patternPitch?.nasal == nil)
        #expect(patternPitch?.devoice == nil)
        let patternTags = patternPitch?.tags as? [String]
        #expect(patternTags == ["def-tag"])
        #expect(patternPitch?.dictionary === dictResult)

        // Assert: Pitch accent tag linking through richTags relationship
        #expect(moraPitch?.richTags?.count == 2)
        let linkedPitchTags = moraPitch?.richTags?.allObjects as? [MaruReader.DictionaryTagMeta]
        let pitchTagNames = linkedPitchTags?.map { $0.name ?? "" }.sorted()
        #expect(pitchTagNames == ["noun", "term-tag"])

        #expect(patternPitch?.richTags?.count == 1)
        let linkedPatternTag = patternPitch?.richTags?.allObjects.first as? MaruReader.DictionaryTagMeta
        #expect(linkedPatternTag?.name == "def-tag")

        // Assert: IPA entries persisted (2 transcriptions from the test data)
        let ipaRequest: NSFetchRequest<MaruReader.IPAEntry> = MaruReader.IPAEntry.fetchRequest()
        let ipaResults = try context.fetch(ipaRequest)
        #expect(ipaResults.count == 2)

        // First IPA transcription with tags
        let taggedIPA = ipaResults.first { ($0.tags as? [String])?.contains("noun") == true }
        #expect(taggedIPA != nil)
        #expect(taggedIPA?.transcription == "/tabe̞ɾɯ̟ᵝ/")
        let ipaTags = taggedIPA?.tags as? [String]
        #expect(ipaTags == ["noun"])
        #expect(taggedIPA?.dictionary === dictResult)
        #expect(taggedIPA?.term?.expression == "食べる")
        #expect(taggedIPA?.term?.reading == "たべる")

        // Second IPA transcription without tags
        let untaggedIPA = ipaResults.first { ($0.tags as? [String])?.isEmpty != false }
        #expect(untaggedIPA != nil)
        #expect(untaggedIPA?.transcription == "/tabeɾɯ/")
        #expect(untaggedIPA?.tags == nil)
        #expect(untaggedIPA?.dictionary === dictResult)

        // Assert: IPA tag linking through richTags relationship
        #expect(taggedIPA?.richTags?.count == 1)
        let linkedIPATag = taggedIPA?.richTags?.allObjects.first as? MaruReader.DictionaryTagMeta
        #expect(linkedIPATag?.name == "noun")

        // Assert: Media files are copied to application support directory
        guard let dictionaryID = dictResult?.id else {
            Issue.record("Dictionary ID is nil")
            return
        }

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

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

    @Test func importDictionary_ValidV1ZIP_ImportsSuccessfully() async throws {
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
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: kanjiJSON, kanjiMetaJSON: nil, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = PersistenceController(inMemory: true)
        let importManager = DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Assert: import does not show as failed or cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        #expect(job != nil)
        #expect(job?.isCancelled == false)
        #expect(job?.isFailed == false)
        #expect(job?.displayProgressMessage == "Import complete.")

        let dictionaryRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictionaryResult = try context.fetch(dictionaryRequest)
        #expect(dictionaryResult.count == 1)
        #expect(dictionaryResult.first?.title == "LegacyDict")

        let tagRequest: NSFetchRequest<MaruReader.DictionaryTagMeta> = MaruReader.DictionaryTagMeta.fetchRequest()
        let tagResults = try context.fetch(tagRequest)
        #expect(tagResults.count == 2)

        let nounTag = tagResults.first { $0.name == "noun" }
        #expect(nounTag?.category == "partOfSpeech")
        #expect(nounTag?.notes == "Common noun")
        #expect(nounTag?.order == 1)
        #expect(nounTag?.score == 0)
        #expect(nounTag?.dictionary?.title == "LegacyDict")

        let defTag = tagResults.first { $0.name == "def-tag" }
        #expect(defTag?.category == "definitionTag")
        #expect(defTag?.notes == "Definition tag")
        #expect(defTag?.order == 2)
        #expect(defTag?.score == 0)
        #expect(defTag?.dictionary?.title == "LegacyDict")

        // Assert: Term and TermEntry persisted with all V1 attributes
        let termRequest: NSFetchRequest<MaruReader.Term> = MaruReader.Term.fetchRequest()
        let termResult = try context.fetch(termRequest)
        #expect(termResult.count == 1)
        let term = termResult.first
        #expect(term?.expression == "猫")
        #expect(term?.reading == "ねこ")
        #expect(term?.id != nil)

        let termEntryResult = try context.fetch(MaruReader.TermEntry.fetchRequest())
        #expect(termEntryResult.count == 1)
        let termEntry = termEntryResult.first
        #expect(termEntry?.score == 100)
        #expect(termEntry?.sequence == 0) // V1 doesn't have sequence, defaults to 0
        #expect(termEntry?.id != nil)

        // Test glossary (V1 uses remaining elements as string definitions)
        let definitions = termEntry?.glossary as? [MaruReader.Definition]
        #expect(definitions?.count == 2)
        if case let .text(firstGlossary) = definitions?[0] {
            #expect(firstGlossary == "cat")
        }
        if case let .text(secondGlossary) = definitions?[1] {
            #expect(secondGlossary == "feline")
        }

        // Test rules
        let rules = termEntry?.rules as? [String]
        #expect(rules == ["v1"])

        // Test definition tags (V1 has only definition tags, no separate term tags)
        let definitionTags = termEntry?.definitionTags as? [String]
        #expect(definitionTags?.sorted() == ["def-tag", "noun"])

        // Test term tags (should be empty for V1)
        let termTags = termEntry?.termTags as? [String]
        #expect(termTags?.isEmpty == true)

        // Test relationships
        #expect(termEntry?.term === term)
        #expect(termEntry?.dictionary === dictionaryResult.first)
        if let termEntry, let entries = term?.entries {
            #expect(entries.contains(termEntry))
        } else {
            Issue.record("Term entries relationship is nil")
        }

        // Assert: Definition tag linking through richDefinitionTags relationship
        #expect(termEntry?.richDefinitionTags?.count == 2)
        let linkedDefTags = termEntry?.richDefinitionTags?.allObjects as? [MaruReader.DictionaryTagMeta]
        let defTagNames = linkedDefTags?.map { $0.name ?? "" }.sorted()
        #expect(defTagNames == ["def-tag", "noun"])

        // Assert: No term tags for V1
        #expect(termEntry?.richTermTags?.count == 0)

        // Assert: Kanji and KanjiEntry persisted with all V1 attributes
        let kanjiRequest: NSFetchRequest<MaruReader.Kanji> = MaruReader.Kanji.fetchRequest()
        let kanjiResult = try context.fetch(kanjiRequest)
        #expect(kanjiResult.count == 1)
        let kanji = kanjiResult.first
        #expect(kanji?.character == "猫")
        #expect(kanji?.id != nil)

        let kanjiEntryResult = try context.fetch(MaruReader.KanjiEntry.fetchRequest())
        #expect(kanjiEntryResult.count == 1)
        let kanjiEntry = kanjiEntryResult.first
        #expect(kanjiEntry?.id != nil)

        // Test onyomi
        let onyomi = kanjiEntry?.onyomi as? [String]
        #expect(onyomi == ["ビョウ"])

        // Test kunyomi
        let kunyomi = kanjiEntry?.kunyomi as? [String]
        #expect(kunyomi == ["ねこ"])

        // Test meanings (V1 format has meanings as remaining string elements)
        let meanings = kanjiEntry?.meanings as? [String]
        #expect(meanings?.sorted() == ["cat", "feline animal"])

        // Test stats (V1 doesn't have stats, should be empty)
        let stats = kanjiEntry?.stats as? [String: String]
        #expect(stats?.isEmpty == true)

        // Test tags
        let kanjiTags = kanjiEntry?.tags as? [String]
        #expect(kanjiTags == ["noun"])

        // Test relationships
        #expect(kanjiEntry?.kanji === kanji)
        #expect(kanjiEntry?.dictionary === dictionaryResult.first)
        if let kanjiEntry, let entries = kanji?.entries {
            #expect(entries.contains(kanjiEntry))
        } else {
            Issue.record("Kanji entries relationship is nil")
        }

        // Assert: Tag linking for kanji through richTags relationship
        #expect(kanjiEntry?.richTags?.count == 1)
        let linkedKanjiTag = kanjiEntry?.richTags?.allObjects.first as? MaruReader.DictionaryTagMeta
        #expect(linkedKanjiTag?.name == "noun")

        // Assert: Media files are copied for V1 format as well
        guard let dictionaryID = dictionaryResult.first?.id else {
            Issue.record("Dictionary ID is nil")
            return
        }

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Verify media directory exists
        #expect(fileManager.fileExists(atPath: mediaDir.path))

        // Verify each media file was copied
        for mediaFile in mediaFiles {
            let expectedPath = mediaDir.appendingPathComponent(mediaFile)
            #expect(fileManager.fileExists(atPath: expectedPath.path), "V1 media file should exist at: \(expectedPath.path)")
        }
    }

    // MARK: - Cancellation Tests

    @Test func importDictionary_CancelDuringUnzip_CleansUpProperly() async throws {
        // Test cancellation during unzip phase
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger during unzip (after first cancellation check)
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 1 {
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobCancelled(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)

        let termRequest: NSFetchRequest<MaruReader.Term> = MaruReader.Term.fetchRequest()
        let termResults = try context.fetch(termRequest)
        #expect(termResults.isEmpty)
    }

    @Test func importDictionary_CancelAfterIndex_CleansUpProperly() async throws {
        // Test cancellation after index processing but before term processing
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil, mediaFiles: ["test.png"])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger after index processing
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 2 { // Second call is after index processing
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobCancelled(job)

        // Verify cleanup (dictionary should be deleted)
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify dictionary was deleted during cleanup
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
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
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger after media copy
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 7 { // After media copy
                throw CancellationError()
            }
        }

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobCancelled(job)

        // Verify cleanup (media directory should be removed despite being created)
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify dictionary was deleted during cleanup
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    @Test func importDictionary_CancelQueuedJob_CleansUpProperly() async throws {
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Cancel immediately (while still in queue)
        await importManager.cancelImport(jobID: importID)

        // Wait a bit to ensure cancellation is processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify job is properly cancelled
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobCancelled(job)

        // For queued jobs, no directories should be created
        if let job {
            #expect(await importManager.workingDirectoryExists(for: job) == false)
            #expect(await importManager.mediaDirectoryExists(for: job) == false)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    // MARK: - Failure Tests

    @Test func importDictionary_MalformedZIP_FailsAndCleansUp() async throws {
        // Test failure with corrupted ZIP file
        let zipURL = try createCorruptedZIP()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    @Test func importDictionary_MissingIndexJSON_FailsAndCleansUp() async throws {
        // Test failure when index.json is missing
        let zipURL = try createZIPWithoutIndex()
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    @Test func importDictionary_InvalidJSON_FailsAndCleansUp() async throws {
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: invalidTermJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify dictionary was deleted during cleanup
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    @Test func importDictionary_UnsupportedFormat_FailsAndCleansUp() async throws {
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        // Set up error injection to simulate file system error
        await importManager.setTestErrorInjection {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [
                NSLocalizedDescriptionKey: "Simulated file system error",
            ])
        }

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }

    @Test func importDictionary_NoBankFiles_FailsAndCleansUp() async throws {
        // Test failure when no valid bank files are present
        let indexJSON = """
        {
            "title": "TestDict",
            "revision": "1.0",
            "format": 3
        }
        """

        // Create ZIP with only index.json, no bank files
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: nil, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = MaruReader.PersistenceController(inMemory: true)
        let importManager = MaruReader.DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: importID)

        // Verify job is properly marked as failed
        let context = persistenceController.container.viewContext
        let job = context.object(with: importID) as? MaruReader.DictionaryZIPFileImport
        verifyJobFailed(job)

        // Verify cleanup
        if let job {
            await verifyDirectoryCleanup(importManager: importManager, job: job)
        }

        // Verify no Core Data entities were created
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let dictResults = try context.fetch(dictRequest)
        #expect(dictResults.isEmpty)
    }
}
