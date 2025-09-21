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

    // Helper struct for tag fetch results
    struct TagResult {
        let name: String
        let category: String
        let notes: String
        let order: Double
        let score: Double
        let dictionaryTitle: String
    }

    // Helper struct for dictionary fetch results
    struct DictionaryResult {
        let title: String
        let revision: String
        let format: Int64
        let isComplete: Bool
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

    @Test func importDictionary_ValidZIP_ImportsSuccessfully() async throws {
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
            ["noun", "partOfSpeech", 1, "Common noun", 0]
        ]
        """
        let termJSON = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "noun"]
        ]
        """

        let termMetaJSON = """
        [
            [
                "食べる",
                "freq",
                {"value": 5000, "displayValue": "5000㋕"}
            ]
        ]
        """
        let kanjiJSON = """
        [
            [
                "食",
                "ショク",
                "た.べ",
                "",
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

        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: tagJSON, termJSON: termJSON, termMetaJSON: termMetaJSON, kanjiJSON: kanjiJSON, kanjiMetaJSON: kanjiMetaJSON)
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

        let dictResult = try await context.perform {
            let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
            let dictionaries = try context.fetch(dictRequest)
            return dictionaries.map { dict in
                DictionaryResult(
                    title: dict.title ?? "",
                    revision: dict.revision ?? "",
                    format: dict.format,
                    isComplete: dict.isComplete
                )
            }.first
        }
        #expect(dictResult?.title == "TestDict")
        #expect(dictResult?.revision == "1.0")
        #expect(dictResult?.format == 3)
        #expect(dictResult?.isComplete == true)

        let tagResult = try await context.perform {
            let tagRequest: NSFetchRequest<MaruReader.DictionaryTagMeta> = MaruReader.DictionaryTagMeta.fetchRequest()
            let tags = try context.fetch(tagRequest)
            return tags.map { tag in
                TagResult(
                    name: tag.name ?? "",
                    category: tag.category ?? "",
                    notes: tag.notes ?? "",
                    order: tag.order,
                    score: tag.score,
                    dictionaryTitle: tag.dictionary?.title ?? ""
                )
            }.first
        }
        #expect(tagResult?.name == "noun")
        #expect(tagResult?.category == "partOfSpeech")
        #expect(tagResult?.notes == "Common noun")
        #expect(tagResult?.order == 1)
        #expect(tagResult?.score == 0)
        #expect(tagResult?.dictionaryTitle == "TestDict")

        // Assert: Term and TermEntry persisted
        let (termCount, termExpression, termReading) = try await context.perform {
            let termRequest: NSFetchRequest<MaruReader.Term> = MaruReader.Term.fetchRequest()
            let terms = try context.fetch(termRequest)
            return (terms.count, terms.first?.expression ?? "", terms.first?.reading ?? "")
        }
        #expect(termCount == 1)
        #expect(termExpression == "食べる")
        #expect(termReading == "たべる")

        let (termEntryCount, termEntryScore, termEntryGlossary) = try await context.perform {
            let termEntryRequest: NSFetchRequest<MaruReader.TermEntry> = MaruReader.TermEntry.fetchRequest()
            let termEntries = try context.fetch(termEntryRequest)
            let glossaryData = termEntries.first?.glossary as? Data
            let glossary = glossaryData.flatMap { try? JSONDecoder().decode([Definition].self, from: $0) }
            return (termEntries.count, termEntries.first?.score ?? 0, glossary?.first)
        }
        #expect(termEntryCount == 1)
        #expect(termEntryScore == 100)
        if case let .text(glossaryText) = termEntryGlossary {
            #expect(glossaryText == "to eat")
        }

        // Assert: Tag linking worked
        let tagLinkingResult = try await context.perform {
            let termEntryRequest: NSFetchRequest<MaruReader.TermEntry> = MaruReader.TermEntry.fetchRequest()
            let termEntries = try context.fetch(termEntryRequest)
            guard let termEntry = termEntries.first else { return (0, "") }

            let richTermTags = termEntry.richTermTags?.allObjects as? [MaruReader.DictionaryTagMeta] ?? []
            return (richTermTags.count, richTermTags.first?.name ?? "")
        }
        #expect(tagLinkingResult.0 == 1)
        #expect(tagLinkingResult.1 == "noun")
    }

    @Test func importDictionary_LegacyTagMeta_PersistsTags() async throws {
        // Setup: index.json with legacy tagMeta and no tag_bank file.
        let indexJSON = """
        {
            "title": "LegacyDict",
            "revision": "1.0",
            "format": 1,
            "tagMeta": {
                "noun": {"category": "partOfSpeech", "order": 1, "notes": "Common noun", "score": 0}
            }
        }
        """
        // Need a term bank to be a valid dictionary
        let termJSON = """
        [
            ["猫", "ねこ", "noun", "", 100, "cat"]
        ]
        """
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: termJSON, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
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

        let (dictionaryCount, title) = try await context.perform {
            let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
            let dictionaries = try context.fetch(dictRequest)
            return (dictionaries.count, dictionaries.first?.title ?? "")
        }
        #expect(dictionaryCount == 1)
        #expect(title == "LegacyDict")

        let tagResult = try await context.perform {
            let tagRequest: NSFetchRequest<MaruReader.DictionaryTagMeta> = MaruReader.DictionaryTagMeta.fetchRequest()
            let tags = try context.fetch(tagRequest)
            return tags.map { tag in
                TagResult(
                    name: tag.name ?? "",
                    category: tag.category ?? "",
                    notes: tag.notes ?? "",
                    order: tag.order,
                    score: tag.score,
                    dictionaryTitle: tag.dictionary?.title ?? ""
                )
            }.first
        }
        #expect(tagResult?.name == "noun")
        #expect(tagResult?.category == "partOfSpeech")
        #expect(tagResult?.notes == "Common noun")
        #expect(tagResult?.order == 1)
        #expect(tagResult?.score == 0)
        #expect(tagResult?.dictionaryTitle == "LegacyDict")
    }
}
