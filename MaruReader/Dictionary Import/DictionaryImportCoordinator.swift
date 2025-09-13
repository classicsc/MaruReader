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
}
