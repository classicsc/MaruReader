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

    @Test func importDictionary_ValidZIP_ImportsSuccessfully() async throws {
        // Test Description: Verifies that a valid Yomitan ZIP is unzipped, parsed, and batch-inserted into Core Data.
        // - Setup: Mock ZIP with index, tags, and terms.
        // - Action: Call importDictionary; track progress calls.
        // - Expected: DictionaryEntry created and marked complete; fetchable Tags and Terms.
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
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"]
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

        let persistenceController = PersistenceController(inMemory: true)
        let importManager = await DictionaryImportManager(container: persistenceController.container)

        let importID = await importManager.runImport(fromZipFile: zipURL)

        // Wait for completion
        try await importManager.waitForImport(id: importID)

        // Assert: Data persisted
        let context = persistenceController.container.viewContext
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let tagRequest: NSFetchRequest<MaruReader.Tag> = MaruReader.Tag.fetchRequest()
        let termRequest: NSFetchRequest<MaruReader.Term> = MaruReader.Term.fetchRequest()
        let termMetaRequest: NSFetchRequest<MaruReader.TermMeta> = MaruReader.TermMeta.fetchRequest()
        let kanjiRequest: NSFetchRequest<MaruReader.Kanji> = MaruReader.Kanji.fetchRequest()
        let kanjiMetaRequest: NSFetchRequest<MaruReader.KanjiMeta> = MaruReader.KanjiMeta.fetchRequest()

        let (dictionaryCount, isComplete, title) = try await context.perform {
            let dictionaries = try context.fetch(dictRequest)
            return (dictionaries.count, dictionaries.first?.isComplete ?? false, dictionaries.first?.title ?? "")
        }
        #expect(dictionaryCount == 1)
        #expect(isComplete == true)
        #expect(title == "TestDict")

        let (tagCount, tagname, tagDictionaryTitle) = try await context.perform {
            let tags = try context.fetch(tagRequest)
            guard let tag = tags.first, let uri = tag.dictionary, let psc = context.persistentStoreCoordinator, let objectID = psc.managedObjectID(forURIRepresentation: uri) else {
                return (tags.count, tags.first?.name ?? "", "")
            }
            let dictObject = try? context.existingObject(with: objectID)
            let dict = dictObject as? MaruReader.Dictionary
            return (tags.count, tag.name ?? "", dict?.title ?? "")
        }
        #expect(tagCount == 1)
        #expect(tagname == "noun")
        #expect(tagDictionaryTitle == "TestDict")
        let (termCount, termExpression, termDictionaryTitle) = try await context.perform {
            let terms = try context.fetch(termRequest)
            var dictTitle = ""
            if let uri = terms.first?.dictionary as? URL, let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri), let dict = try? context.existingObject(with: objectID) as? MaruReader.Dictionary {
                dictTitle = dict.title ?? ""
            }
            return (terms.count, terms.first?.expression ?? "", dictTitle)
        }
        #expect(termCount == 1)
        #expect(termExpression == "食べる")
        #expect(termDictionaryTitle == "TestDict")

        let (termMetaCount, termMetaExpression, termMetaType) = try await context.perform {
            let termMetas = try context.fetch(termMetaRequest)
            return (termMetas.count, termMetas.first?.expression ?? "", termMetas.first?.type ?? "")
        }
        #expect(termMetaCount == 1)
        #expect(termMetaExpression == "食べる")
        #expect(termMetaType == "freq")

        let (kanjiCount, kanjiChar) = try await context.perform {
            let kanji = try context.fetch(kanjiRequest)
            return (kanji.count, kanji.first?.character ?? "")
        }
        #expect(kanjiCount == 1)
        #expect(kanjiChar == "食")

        let (kanjiMetaCount, kmChar, kmType, kmFreqVal, kmDisp) = try await context.perform {
            let metas = try context.fetch(kanjiMetaRequest)
            let first = metas.first
            return (metas.count, first?.character ?? "", first?.type ?? "", first?.frequencyValue, first?.displayFrequency ?? "")
        }
        #expect(kanjiMetaCount == 1)
        #expect(kmChar == "食")
        #expect(kmType == "freq")
        #expect(kmFreqVal == 200)
        #expect(kmDisp == "200★")
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
        let zipURL = try createMockZIP(indexJSON: indexJSON, tagJSON: nil, termJSON: nil, termMetaJSON: nil, kanjiJSON: nil, kanjiMetaJSON: nil)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = PersistenceController(inMemory: true)
        let importManager = await DictionaryImportManager(container: persistenceController.container)
        let importID = await importManager.runImport(fromZipFile: zipURL)
        try await importManager.waitForImport(id: importID)

        let context = persistenceController.container.viewContext
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let tagRequest: NSFetchRequest<MaruReader.Tag> = MaruReader.Tag.fetchRequest()

        let (dictionaryCount, title) = try await context.perform {
            let dictionaries = try context.fetch(dictRequest)
            return (dictionaries.count, dictionaries.first?.title ?? "")
        }
        #expect(dictionaryCount == 1)
        #expect(title == "LegacyDict")

        let (tagCount, tagName, tagDictTitle) = try await context.perform {
            let tags = try context.fetch(tagRequest)
            guard let tag = tags.first, let uri = tag.dictionary, let psc = context.persistentStoreCoordinator, let objectID = psc.managedObjectID(forURIRepresentation: uri) else {
                return (tags.count, tags.first?.name ?? "", "")
            }
            let dictObject = try? context.existingObject(with: objectID)
            let dict = dictObject as? MaruReader.Dictionary
            return (tags.count, tag.name ?? "", dict?.title ?? "")
        }
        #expect(tagCount == 1)
        #expect(tagName == "noun")
        #expect(tagDictTitle == "LegacyDict")
    }

    @Test func importDictionary_MediaFiles_PersistsToCorrectLocation() async throws {
        // Test Description: Verifies that media files in a dictionary ZIP are persisted
        // to the correct location in Application Support directory.
        // - Setup: Mock ZIP with index.json and media files (including subdirectories)
        // - Action: Call importDictionary and wait for completion
        // - Expected: Media files are copied to Application Support/Dictionaries/{import-id}/
        //   preserving their relative directory structure

        let indexJSON = """
        {
            "title": "MediaTestDict",
            "revision": "1.0",
            "format": 3
        }
        """

        // Create media files with subdirectory structure
        let mediaFiles = [
            "icon.png",
            "audio/word1.mp3",
            "audio/word2.mp3",
            "images/kanji/食.png",
        ]

        let zipURL = try createMockZIP(
            indexJSON: indexJSON,
            tagJSON: nil,
            termJSON: nil,
            termMetaJSON: nil,
            kanjiJSON: nil,
            kanjiMetaJSON: nil,
            mediaFiles: mediaFiles
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = PersistenceController(inMemory: true)
        let importManager = await DictionaryImportManager(container: persistenceController.container)
        let importID = await importManager.runImport(fromZipFile: zipURL)
        try await importManager.waitForImport(id: importID)

        // Verify dictionary was created
        let context = persistenceController.container.viewContext
        let dictRequest: NSFetchRequest<MaruReader.Dictionary> = MaruReader.Dictionary.fetchRequest()
        let (dictionaryCount, title, dictID) = try await context.perform {
            let dictionaries = try context.fetch(dictRequest)
            return (dictionaries.count, dictionaries.first?.title ?? "", dictionaries.first?.id)
        }
        #expect(dictionaryCount == 1)
        #expect(title == "MediaTestDict")
        #expect(dictID != nil)

        // Verify media files were copied to the correct location
        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let dictMediaDir = appSupportDir
            .appendingPathComponent("Dictionaries")
            .appendingPathComponent(dictID!.uuidString)

        // Check that the media directory exists
        #expect(fileManager.fileExists(atPath: dictMediaDir.path))

        // Check that each media file exists at its expected location
        for mediaPath in mediaFiles {
            let expectedURL = dictMediaDir.appendingPathComponent(mediaPath)
            #expect(fileManager.fileExists(atPath: expectedURL.path), "Media file should exist at: \(expectedURL.path)")

            // Verify the file has content (our mock PNG data)
            if fileManager.fileExists(atPath: expectedURL.path) {
                let data = try Data(contentsOf: expectedURL)
                #expect(data.count > 0, "Media file should have content")

                // For PNG files, verify they start with PNG signature
                if mediaPath.hasSuffix(".png") {
                    let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
                    let fileSignature = Array(data.prefix(8))
                    #expect(fileSignature == pngSignature, "PNG file should have valid PNG signature")
                }
            }
        }

        // Clean up the created media directory
        try? fileManager.removeItem(at: dictMediaDir.deletingLastPathComponent())
    }
}
