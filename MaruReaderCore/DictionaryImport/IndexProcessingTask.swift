//
//  IndexProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

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

    private static func encodeURLArray(_ urls: [URL]) throws -> String {
        let strings = urls.map(\.absoluteString)
        let data = try JSONEncoder().encode(strings)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw DictionaryImportError.invalidData
        }
        return encoded
    }

    func start() async throws -> UUID {
        let container = self.persistentContainer
        let jobID = self.jobID
        // Load index.json
        // Create Dictionary entity
        // Populate job.termBanks, job.kanjiBanks, etc.
        // Index can contain tag metadata that needs to be processed

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (indexURL, workingDir) = try await context.perform {
            guard let dictionary = try context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.importNotFound
            }
            guard let workingDir = dictionary.workingDirectory else {
                throw DictionaryImportError.noWorkingDirectory
            }
            let indexURL = workingDir.appendingPathComponent("index.json")
            guard FileManager.default.fileExists(atPath: indexURL.path) else {
                throw DictionaryImportError.notADictionary
            }
            return (indexURL, workingDir)
        }

        // Decode index.json to type DictionaryIndex
        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()
        let index = try decoder.decode(DictionaryIndex.self, from: data)

        // Ensure format is supported
        guard let format = index.format, DictionaryImportManager.supportedFormats.contains(format) else {
            throw DictionaryImportError.unsupportedFormat
        }

        // Find the bank files in working directory
        let contents = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: nil)
        let termBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_bank_") && $0.pathExtension == "json" }
        let kanjiBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_bank_") && $0.pathExtension == "json" }
        let termMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_meta_bank_") && $0.pathExtension == "json" }
        let kanjiMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_meta_bank_") && $0.pathExtension == "json" }
        let tagBanks = contents.filter { $0.lastPathComponent.hasPrefix("tag_bank_") && $0.pathExtension == "json" }

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

            dictionary.termBanks = try Self.encodeURLArray(termBanks)
            dictionary.kanjiBanks = try Self.encodeURLArray(kanjiBanks)
            dictionary.termMetaBanks = try Self.encodeURLArray(termMetaBanks)
            dictionary.kanjiMetaBanks = try Self.encodeURLArray(kanjiMetaBanks)
            dictionary.tagBanks = try Self.encodeURLArray(tagBanks)
            dictionary.indexProcessed = true
            dictionary.displayProgressMessage = "Processed dictionary index."

            try context.save()
            return dictionaryID
        }
        return dictionaryID
    }
}
