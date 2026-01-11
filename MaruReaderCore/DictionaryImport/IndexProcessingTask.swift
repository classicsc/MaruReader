// IndexProcessingTask.swift
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
import os.log
internal import ReadiumZIPFoundation

struct DictionaryBankPaths: Sendable {
    let termBanks: [String]
    let kanjiBanks: [String]
    let termMetaBanks: [String]
    let kanjiMetaBanks: [String]
    let tagBanks: [String]
}

struct DictionaryIndexResult: Sendable {
    let dictionaryID: UUID
    let archiveURL: URL
    let bankPaths: DictionaryBankPaths
}

struct IndexProcessingTask {
    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryImport")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer = DictionaryPersistenceController.shared.container) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    /// Get the next available priority value for a given priority field
    /// - Parameters:
    ///   - field: The priority field name (e.g., "termDisplayPriority")
    ///   - context: The managed object context
    /// - Returns: The next priority value (max + 1, or 0 if no dictionaries exist)
    private static func getNextPriority(for field: String, in context: NSManagedObjectContext) throws -> Int64 {
        let fetchRequest: NSFetchRequest<Dictionary> = Dictionary.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: field, ascending: false)]
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)
        if let maxDict = results.first {
            let maxValue = maxDict.value(forKey: field) as? Int64 ?? 0
            return maxValue + 1
        }
        return 0
    }

    func start() async throws -> DictionaryIndexResult {
        let container = self.persistentContainer
        let jobID = self.jobID
        // Load index.json
        // Create Dictionary entity
        // Index can contain tag metadata that needs to be processed

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let jobURL = try await context.perform {
            guard let dictionary = try context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            guard let jobURL = dictionary.file else {
                throw DictionaryImportError.missingFile
            }
            dictionary.displayProgressMessage = "Processing dictionary index..."
            try context.save()
            return jobURL
        }

        guard jobURL.startAccessingSecurityScopedResource() else {
            throw DictionaryImportError.fileAccessDenied
        }

        defer {
            jobURL.stopAccessingSecurityScopedResource()
        }

        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw DictionaryImportError.missingFile
        }

        let archive: Archive
        do {
            archive = try await Archive(url: jobURL, accessMode: .read)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        guard let indexEntry = try await archive.get("index.json") else {
            throw DictionaryImportError.notADictionary
        }

        let tempIndexURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempIndexURL)
        }
        do {
            _ = try await archive.extract(indexEntry, to: tempIndexURL, skipCRC32: true)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        // Decode index.json to type DictionaryIndex
        let decoder = JSONDecoder()
        let indexData = try Data(contentsOf: tempIndexURL)
        let index = try decoder.decode(DictionaryIndex.self, from: indexData)

        // Ensure format is supported
        guard let format = index.format, DictionaryImportManager.supportedFormats.contains(format) else {
            throw DictionaryImportError.unsupportedFormat
        }

        // Find the bank files in archive
        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
        let termBanks = Self.bankPaths(from: entries, prefix: "term_bank_")
        let kanjiBanks = Self.bankPaths(from: entries, prefix: "kanji_bank_")
        let termMetaBanks = Self.bankPaths(from: entries, prefix: "term_meta_bank_")
        let kanjiMetaBanks = Self.bankPaths(from: entries, prefix: "kanji_meta_bank_")
        let tagBanks = Self.bankPaths(from: entries, prefix: "tag_bank_")

        // Dictionary must have at least one of termBanks, kanjiBanks, termMetaBanks, kanjiMetaBanks
        if termBanks.isEmpty, kanjiBanks.isEmpty, termMetaBanks.isEmpty, kanjiMetaBanks.isEmpty {
            throw DictionaryImportError.notADictionary
        }

        try Task.checkCancellation()

        let dictionaryID = try await context.perform {
            guard let dictionary = try context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            if dictionary.id == nil {
                dictionary.id = UUID()
            }
            guard let dictionaryID = dictionary.id else {
                throw DictionaryImportError.dictionaryCreationFailed
            }
            dictionary.title = index.title
            dictionary.attribution = index.attribution
            dictionary.downloadURL = index.downloadUrl
            dictionary.displayDescription = index.description
            dictionary.frequencyMode = index.frequencyMode?.rawValue
            dictionary.sequenced = index.sequenced ?? false
            dictionary.author = index.author
            dictionary.indexURL = index.indexUrl
            dictionary.isUpdatable = index.isUpdatable ?? false
            dictionary.minimumYomitanVersion = index.minimumYomitanVersion
            dictionary.sourceLanguage = index.sourceLanguage
            dictionary.targetLanguage = index.targetLanguage
            dictionary.revision = index.revision
            dictionary.format = Int64(format)

            // Assign default priorities - new dictionaries appear last in each category
            // Higher priority value = lower display priority (appears later)
            dictionary.termDisplayPriority = try Self.getNextPriority(for: "termDisplayPriority", in: context)
            dictionary.kanjiDisplayPriority = try Self.getNextPriority(for: "kanjiDisplayPriority", in: context)
            dictionary.ipaDisplayPriority = try Self.getNextPriority(for: "ipaDisplayPriority", in: context)
            dictionary.pitchDisplayPriority = try Self.getNextPriority(for: "pitchDisplayPriority", in: context)
            dictionary.termFrequencyDisplayPriority = try Self.getNextPriority(for: "termFrequencyDisplayPriority", in: context)
            dictionary.kanjiFrequencyDisplayPriority = try Self.getNextPriority(for: "kanjiFrequencyDisplayPriority", in: context)

            // If the index has embedded tags, create DictionaryTagMeta entities
            if let embeddedTags = index.tagMeta {
                for (name, entry) in embeddedTags {
                    let tag = DictionaryTagMeta(context: context)
                    tag.id = UUID()
                    tag.name = name
                    tag.category = entry.category
                    tag.order = Double(entry.order ?? 0)
                    tag.notes = entry.notes
                    tag.score = Double(entry.score ?? 0)
                    tag.dictionaryID = dictionaryID

                    context.insert(tag)
                }
            }

            dictionary.indexProcessed = true
            dictionary.displayProgressMessage = "Processed dictionary index."

            try context.save()
            return dictionaryID
        }
        return DictionaryIndexResult(
            dictionaryID: dictionaryID,
            archiveURL: jobURL,
            bankPaths: DictionaryBankPaths(
                termBanks: termBanks,
                kanjiBanks: kanjiBanks,
                termMetaBanks: termMetaBanks,
                kanjiMetaBanks: kanjiMetaBanks,
                tagBanks: tagBanks
            )
        )
    }

    private static func bankPaths(from entries: [Entry], prefix: String) -> [String] {
        entries.compactMap { entry in
            guard entry.type == .file else { return nil }
            let name = entry.path.split(separator: "/").last.map(String.init) ?? entry.path
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else { return nil }
            return entry.path
        }
    }
}
