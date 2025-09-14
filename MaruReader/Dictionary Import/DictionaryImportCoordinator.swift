//
//  DictionaryImportCoordinator.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import Foundation
import os.log
import Zip

/// Represents a single import operation for a dictionary.
struct DictionaryImportCoordinator {
    /// The display name of the dictionary.
    let displayName: String?

    /// The URL of the index.
    let indexURL: URL

    /// URLs of the term banks.
    let termBankURLs: [URL]?

    /// URLs of the kanji banks.
    let kanjiBankURLs: [URL]?

    /// URLs of the term meta banks.
    let termMetaBankURLs: [URL]?

    /// URLs of the kanji meta banks.
    let kanjiMetaBankURLs: [URL]?

    /// URLs of the tag banks.
    let tagBankURLs: [URL]?

    /// URLs of media resources - in a zip import, this is all non-json files.
    let mediaURLs: [URL]?

    /// The Core Data container to use for persistence.
    let container: NSPersistentContainer

    /// The import manager that created this coordinator.
    weak var importManager: DictionaryImportManager?

    /// A  unique identifier for the import operation.
    let id: UUID

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryImport")

    /// Runs the import operation.
    func runImport() async throws {
        let (dictionaryID, dataFormat) = try await processIndex()
        logger.debug("Created dictionary object with ID: \(dictionaryID) and format: \(dataFormat)")

        // Process term banks if available
        if let termBankURLs, !termBankURLs.isEmpty {
            try await processTermBanks(dictionaryID: dictionaryID, dataFormat: dataFormat)
            logger.debug("Processed \(termBankURLs.count) term bank(s)")
        }

        // Process the other bank types here...

        // Mark the dictionary object as complete
        try await container.performBackgroundTask { context in
            guard let dict = try context.existingObject(with: dictionaryID) as? Dictionary else {
                throw DictionaryImportError.dictionaryCreationFailed
            }
            dict.isComplete = true
            try context.save()
        }
        // Then notify the import manager that we're done
        await importManager?.markImportComplete(id: id)
    }

    /// Process the index file and send to the persistence layer.
    private func processIndex() async throws -> (NSManagedObjectID, Int) {
        // Load the index file
        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()
        guard let index = try? decoder.decode(DictionaryIndex.self, from: data) else {
            throw DictionaryImportError.invalidData
        }
        let indexFormat = index.format ?? index.version ?? 0
        guard indexFormat == 1 || indexFormat == 3 else {
            throw DictionaryImportError.unsupportedFormat
        }
        // Send to persistence layer
        return try await container.performBackgroundTask { context in
            let dict = Dictionary(context: context)
            dict.title = index.title
            dict.author = index.author
            dict.attribution = index.attribution
            dict.sourceLanguage = index.sourceLanguage
            dict.targetLanguage = index.targetLanguage
            dict.revision = index.revision
            dict.isUpdatable = index.isUpdatable ?? false
            dict.minimumYomitanVersion = index.minimumYomitanVersion
            dict.frequencyMode = index.frequencyMode?.rawValue
            dict.sequenced = index.sequenced ?? false
            dict.format = Int64(indexFormat)
            dict.revision = index.revision
            dict.downloadURL = index.downloadUrl
            dict.indexURL = index.indexUrl
            dict.url = index.url
            dict.displayDescription = index.description
            do {
                try context.save()
            } catch {
                throw DictionaryImportError.unsupportedFormat
            }

            // Insert legacy tagMeta tags (format v1 dictionaries may include inline tag metadata)
            if let tagMeta = index.tagMeta {
                for (tagName, meta) in tagMeta {
                    let tag = Tag(context: context)
                    tag.name = tagName
                    tag.category = meta.category
                    if let order = meta.order { tag.order = order }
                    if let score = meta.score { tag.score = score }
                    tag.notes = meta.notes
                    tag.dictionary = dict.objectID.uriRepresentation()
                }

                do {
                    try context.save()
                } catch {
                    throw DictionaryImportError.unsupportedFormat
                }
            }
            return (dict.objectID, indexFormat)
        }
    }

    /// Process term banks and send to the persistence layer.
    private func processTermBanks(dictionaryID: NSManagedObjectID, dataFormat: Int) async throws {
        guard let termBankURLs else { return }
        let iterator = TermBankIterator(termBankURLs: termBankURLs, dataFormat: dataFormat)
        let dictionaryURI = dictionaryID.uriRepresentation()

        let batchSize = 5000
        var termsBatch: [ParsedTerm] = []
        termsBatch.reserveCapacity(batchSize)

        for try await term in iterator {
            termsBatch.append(term)
            if termsBatch.count >= batchSize {
                try await performTermBatchInsert(terms: termsBatch, dictionaryURI: dictionaryURI)
                termsBatch.removeAll(keepingCapacity: true)
            }
        }

        // Insert any remaining terms
        if !termsBatch.isEmpty {
            try await performTermBatchInsert(terms: termsBatch, dictionaryURI: dictionaryURI)
        }
    }

    /// Perform a batch insert of terms into Core Data.
    private func performTermBatchInsert(terms: [ParsedTerm], dictionaryURI: URL) async throws {
        try await container.performBackgroundTask { context in
            let batchInsert = createTermBatchInsertRequest(terms: terms, dictionaryURI: dictionaryURI)

            do {
                try context.execute(batchInsert)
            } catch {
                throw DictionaryImportError.batchInsertFailed
            }
        }
    }

    /// Create a batch insert request for terms.
    private func createTermBatchInsertRequest(terms: [ParsedTerm], dictionaryURI: URL) -> NSBatchInsertRequest {
        var index = 0
        let total = terms.count

        let batchInsert = NSBatchInsertRequest(entity: Term.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let term = managedObject as? Term {
                let parsedTerm = terms[index]
                term.expression = parsedTerm.expression
                term.reading = parsedTerm.reading
                term.score = Double(parsedTerm.score)
                term.rules = parsedTerm.rules
                term.definitionTags = parsedTerm.definitionTags
                term.termTags = parsedTerm.termTags
                term.glossary = parsedTerm.glossary
                term.sequence = parsedTerm.sequence ?? 0
                term.dictionary = dictionaryURI
            }
            index += 1
            return false
        }
        return batchInsert
    }
}
