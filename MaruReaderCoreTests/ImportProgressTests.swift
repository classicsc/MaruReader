// ImportProgressTests.swift
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
@testable import MaruReaderCore
import Testing
internal import ReadiumZIPFoundation

struct ImportProgressTests {
    /// Collects all displayProgressMessage values saved by any background context during an import.
    private final class ProgressMessageCollector: @unchecked Sendable {
        private var messages: [String] = []
        private var observation: Any?

        init(container: NSPersistentContainer) {
            observation = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let context = notification.object as? NSManagedObjectContext,
                      context.persistentStoreCoordinator === container.persistentStoreCoordinator
                else { return }

                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                for object in updated {
                    if let dictionary = object as? Dictionary,
                       let message = dictionary.displayProgressMessage
                    {
                        self?.messages.append(message)
                    }
                }

                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                for object in inserted {
                    if let dictionary = object as? Dictionary,
                       let message = dictionary.displayProgressMessage
                    {
                        self?.messages.append(message)
                    }
                }
            }
        }

        deinit {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }

        var collectedMessages: [String] {
            messages
        }
    }

    // MARK: - Test Helpers

    private func createMockZIP(
        indexJSON: String,
        tagJSON: String? = nil,
        termJSON: String? = nil,
        termMetaJSON: String? = nil,
        kanjiJSON: String? = nil,
        kanjiMetaJSON: String? = nil,
        mediaFiles: [String]? = nil
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        try indexJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("index.json"))

        if let tagJSON {
            try tagJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("tag_bank_1.json"))
        }
        if let termJSON {
            try termJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("term_bank_1.json"))
        }
        if let termMetaJSON {
            try termMetaJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("term_meta_bank_1.json"))
        }
        if let kanjiJSON {
            try kanjiJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("kanji_bank_1.json"))
        }
        if let kanjiMetaJSON {
            try kanjiMetaJSON.data(using: .utf8)!.write(to: contentsDir.appendingPathComponent("kanji_meta_bank_1.json"))
        }

        if let mediaFiles {
            let mockData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            for mediaPath in mediaFiles {
                let mediaURL = contentsDir.appendingPathComponent(mediaPath)
                let mediaDir = mediaURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: mediaDir.path) {
                    try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
                }
                try mockData.write(to: mediaURL)
            }
        }

        let zipURL = tempDir.appendingPathComponent("mock.zip")
        let archive = try await Archive(url: zipURL, accessMode: .create)
        let rootPath = contentsDir.path + "/"
        let enumerator = FileManager.default.enumerator(at: contentsDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = String(fileURL.path.dropFirst(rootPath.count))
            if !relativePath.isEmpty {
                try await archive.addEntry(with: relativePath, fileURL: fileURL)
            }
        }
        return zipURL
    }

    // MARK: - Bank Progress Tests

    @Test @MainActor func bankProcessing_updatesProgressWithEntryCounts() async throws {
        let indexJSON = """
        {"title": "ProgressTest", "revision": "1.0", "format": 3}
        """
        let termJSON = """
        [
            ["食べる", "たべる", "", "", 100, ["to eat"], 1, ""],
            ["飲む", "のむ", "", "", 90, ["to drink"], 1, ""],
            ["走る", "はしる", "", "", 80, ["to run"], 1, ""]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, termJSON: termJSON)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let collector = ProgressMessageCollector(container: persistenceController.container)
        let importManager = DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let dictionary = try? context.existingObject(with: importID) as? Dictionary
        #expect(dictionary?.isComplete == true)
        #expect(dictionary?.displayProgressMessage == "Import complete.")

        let messages = collector.collectedMessages
        let bankProgressMessages = messages.filter { $0.contains("entries)") }
        #expect(!bankProgressMessages.isEmpty, "Expected at least one bank progress message with entry count")

        for message in bankProgressMessages {
            #expect(message.hasPrefix("Processing dictionary data"))
        }
    }

    @Test @MainActor func bankProcessing_v1Format_updatesProgressWithEntryCounts() async throws {
        let indexJSON = """
        {"title": "V1ProgressTest", "revision": "1.0", "format": 1}
        """
        let termJSON = """
        [
            ["食べる", "たべる", "", "", 100, "to eat"],
            ["飲む", "のむ", "", "", 90, "to drink"]
        ]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, termJSON: termJSON)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let collector = ProgressMessageCollector(container: persistenceController.container)
        let importManager = DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let dictionary = try? context.existingObject(with: importID) as? Dictionary
        #expect(dictionary?.isComplete == true)

        let messages = collector.collectedMessages
        let bankProgressMessages = messages.filter { $0.contains("entries)") }
        #expect(!bankProgressMessages.isEmpty, "Expected at least one V1 bank progress message with entry count")
    }

    // MARK: - Media Progress Tests

    @Test @MainActor func mediaCopy_updatesProgressWithFileCounts() async throws {
        let indexJSON = """
        {"title": "MediaProgressTest", "revision": "1.0", "format": 3}
        """
        let termJSON = """
        [["食べる", "たべる", "", "", 100, ["to eat"], 1, ""]]
        """
        // Create enough media files to trigger at least one progress update (every 10 files)
        var mediaFiles: [String] = []
        for i in 1 ... 15 {
            mediaFiles.append("images/img\(i).png")
        }

        let zipURL = try await createMockZIP(indexJSON: indexJSON, termJSON: termJSON, mediaFiles: mediaFiles)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let collector = ProgressMessageCollector(container: persistenceController.container)
        let importManager = DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let dictionary = try? context.existingObject(with: importID) as? Dictionary
        #expect(dictionary?.isComplete == true)

        let messages = collector.collectedMessages
        let mediaProgressMessages = messages.filter { $0.contains(" of ") && $0.contains("media") }
        #expect(!mediaProgressMessages.isEmpty, "Expected at least one media progress message with file counts")

        // Verify the final media progress message shows correct total
        if let lastMediaProgress = mediaProgressMessages.last {
            #expect(lastMediaProgress.contains("15"), "Expected total media count of 15 in progress message")
        }
    }

    @Test @MainActor func mediaCopy_noMediaFiles_skipsMediaProgress() async throws {
        let indexJSON = """
        {"title": "NoMediaTest", "revision": "1.0", "format": 3}
        """
        let termJSON = """
        [["食べる", "たべる", "", "", 100, ["to eat"], 1, ""]]
        """

        let zipURL = try await createMockZIP(indexJSON: indexJSON, termJSON: termJSON)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let collector = ProgressMessageCollector(container: persistenceController.container)
        let importManager = DictionaryImportManager(container: persistenceController.container)

        let importID = try await importManager.enqueueImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        let dictionary = try? context.existingObject(with: importID) as? Dictionary
        #expect(dictionary?.isComplete == true)

        let messages = collector.collectedMessages
        let mediaProgressMessages = messages.filter { $0.contains(" of ") && $0.contains("media") }
        #expect(mediaProgressMessages.isEmpty, "Should not have media progress messages when no media files exist")
    }
}
