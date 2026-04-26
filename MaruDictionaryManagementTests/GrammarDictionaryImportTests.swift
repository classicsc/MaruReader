// GrammarDictionaryImportTests.swift
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

struct GrammarDictionaryImportTests {
    @Test func archiveTypeDetector_recognizesGrammarDictionaryPackage() throws {
        let indexJSON = """
        {
          "type": "maru-grammar-dictionary",
          "format": 1,
          "title": "Grammar",
          "revision": "1",
          "entries": [{"id": "passive", "title": "Passive", "path": "entries/passive.md"}],
          "formTags": {"passive": ["passive"]}
        }
        """

        let type = try ArchiveTypeDetector.classify(indexData: Data(indexJSON.utf8))

        #expect(type == .grammarDictionary)
    }

    @Test @MainActor func importGrammarDictionary_validPackagePersistsMetadataAndFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseDirectory = tempDir.appendingPathComponent("app-group", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let zipURL = try await createMockGrammarDictionaryZIP(in: tempDir)
        let persistenceController = makeDictionaryPersistenceController(
            storeKind: .temporarySQLite,
            baseDirectory: baseDirectory
        )
        let importManager = ImportManager(
            container: persistenceController.container,
            baseDirectory: baseDirectory
        )

        let importID = try await importManager.enqueueGrammarDictionaryImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        context.refreshAllObjects()
        let request: NSFetchRequest<GrammarDictionary> = GrammarDictionary.fetchRequest()
        let grammarDictionaries = try context.fetch(request)
        let grammarDictionary = try #require(grammarDictionaries.first)

        #expect(grammarDictionary.isComplete)
        #expect(grammarDictionary.isFailed == false)
        #expect(grammarDictionary.title == "Test Grammar")
        #expect(grammarDictionary.entryCount == 2)
        #expect(grammarDictionary.formTagCount == 2)

        let entryRequest: NSFetchRequest<GrammarDictionaryEntry> = GrammarDictionaryEntry.fetchRequest()
        entryRequest.sortDescriptors = [NSSortDescriptor(keyPath: \GrammarDictionaryEntry.entryID, ascending: true)]
        let storedEntries = try context.fetch(entryRequest)
        #expect(storedEntries.map(\.entryID) == ["passive", "past"])
        #expect(storedEntries.map(\.title) == ["Passive", "Past"])
        #expect(storedEntries.map(\.path) == ["entries/passive.md", "entries/past.md"])
        #expect(storedEntries.map(\.formTags) == ["passive", "past"])

        let grammarID = try #require(grammarDictionary.id)
        let installDirectory = try #require(GrammarDictionaryStorage.installedDirectoryURL(
            grammarDictionaryID: grammarID,
            in: baseDirectory
        ))
        #expect(FileManager.default.fileExists(atPath: installDirectory.appendingPathComponent("index.json").path))
        #expect(FileManager.default.fileExists(atPath: installDirectory.appendingPathComponent("entries/passive.md").path))
        #expect(FileManager.default.fileExists(atPath: installDirectory.appendingPathComponent("media/example.png").path))
    }

    @Test @MainActor func deleteGrammarDictionary_removesPersistedEntriesAndFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseDirectory = tempDir.appendingPathComponent("app-group", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let zipURL = try await createMockGrammarDictionaryZIP(in: tempDir)
        let persistenceController = makeDictionaryPersistenceController(
            storeKind: .temporarySQLite,
            baseDirectory: baseDirectory
        )
        let importManager = ImportManager(
            container: persistenceController.container,
            baseDirectory: baseDirectory
        )

        let importID = try await importManager.enqueueGrammarDictionaryImport(from: zipURL)
        await importManager.waitForCompletion(jobID: importID)

        let context = persistenceController.container.viewContext
        context.refreshAllObjects()
        let grammarDictionary = try #require(try context.existingObject(with: importID) as? GrammarDictionary)
        let grammarID = try #require(grammarDictionary.id)
        let installDirectory = try #require(GrammarDictionaryStorage.installedDirectoryURL(
            grammarDictionaryID: grammarID,
            in: baseDirectory
        ))

        await importManager.deleteGrammarDictionary(grammarDictionaryID: importID)
        await waitForGrammarDictionaryDeletion(in: context, grammarDictionaryID: importID)

        let entryRequest: NSFetchRequest<GrammarDictionaryEntry> = GrammarDictionaryEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(format: "dictionaryID == %@", grammarID as CVarArg)
        #expect(try context.count(for: entryRequest) == 0)
        #expect(!FileManager.default.fileExists(atPath: installDirectory.path))
    }

    private func createMockGrammarDictionaryZIP(in tempDir: URL) async throws -> URL {
        let contentsDir = tempDir.appendingPathComponent("contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let indexJSON = """
        {
          "type": "maru-grammar-dictionary",
          "format": 1,
          "title": "Test Grammar",
          "revision": "2026.04.25",
          "attribution": "CC-BY Test",
          "entries": [
            {"id": "passive", "title": "Passive", "path": "entries/passive.md"},
            {"id": "past", "title": "Past", "path": "entries/past.md"}
          ],
          "formTags": {
            "passive": ["passive"],
            "past": ["past"]
          }
        }
        """
        try Data(indexJSON.utf8).write(to: contentsDir.appendingPathComponent("index.json"))

        let entriesDir = contentsDir.appendingPathComponent("entries", isDirectory: true)
        try FileManager.default.createDirectory(at: entriesDir, withIntermediateDirectories: true)
        try "# Passive\n\nSee ![](media/example.png)\n".write(
            to: entriesDir.appendingPathComponent("passive.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Past\n".write(
            to: entriesDir.appendingPathComponent("past.md"),
            atomically: true,
            encoding: .utf8
        )

        let mediaDir = contentsDir.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: mediaDir.appendingPathComponent("example.png"))

        let zipURL = tempDir.appendingPathComponent("grammar.zip")
        let archive = try await Archive(url: zipURL, accessMode: .create)
        let rootPath = contentsDir.path.hasSuffix("/") ? contentsDir.path : contentsDir.path + "/"
        let enumerator = FileManager.default.enumerator(at: contentsDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            guard !fileURL.hasDirectoryPath else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: rootPath, with: "")
            try await archive.addEntry(with: relativePath, relativeTo: contentsDir)
        }
        return zipURL
    }

    @MainActor private func waitForGrammarDictionaryDeletion(
        in context: NSManagedObjectContext,
        grammarDictionaryID: NSManagedObjectID
    ) async {
        for _ in 0 ..< 50 {
            context.refreshAllObjects()
            let request: NSFetchRequest<GrammarDictionary> = GrammarDictionary.fetchRequest()
            request.predicate = NSPredicate(format: "self == %@", grammarDictionaryID)
            if ((try? context.count(for: request)) ?? 0) == 0 {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
