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
    /// The batch size for batch inserts.
    private let batchSize = 5000

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
        // Process kanji banks if available
        if let kanjiBankURLs, !kanjiBankURLs.isEmpty {
            try await processKanjiBanks(dictionaryID: dictionaryID, dataFormat: dataFormat)
            logger.debug("Processed \(kanjiBankURLs.count) kanji bank(s)")
        }
        // Process kanji meta banks (only valid for format 3)
        if let kanjiMetaBankURLs, !kanjiMetaBankURLs.isEmpty {
            try await processKanjiMetaBanks(dictionaryID: dictionaryID, dataFormat: dataFormat)
            logger.debug("Processed \(kanjiMetaBankURLs.count) kanji meta bank(s)")
        }

        // Process term meta banks (only valid for format 3)
        if let termMetaBankURLs, !termMetaBankURLs.isEmpty {
            try await processTermMetaBanks(dictionaryID: dictionaryID, dataFormat: dataFormat)
            logger.debug("Processed \(termMetaBankURLs.count) term meta bank(s)")
        }

        // Process tag banks (only valid for format 3)
        if let tagBankURLs, !tagBankURLs.isEmpty {
            try await processTagBanks(dictionaryID: dictionaryID, dataFormat: dataFormat)
            logger.debug("Processed \(tagBankURLs.count) tag bank(s)")
        }

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
        let dictionaryURI = dictionaryID.uriRepresentation()

        var termsBatch: [ParsedTerm] = []
        termsBatch.reserveCapacity(batchSize)

        switch dataFormat {
        case 1:
            let iterator = StreamingBankIterator<TermBankV1Entry>(bankURLs: termBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                let term = ParsedTerm(from: entry)
                termsBatch.append(term)
                if termsBatch.count >= batchSize {
                    try await performTermBatchInsert(terms: termsBatch, dictionaryURI: dictionaryURI)
                    termsBatch.removeAll(keepingCapacity: true)
                }
            }
        case 3:
            let iterator = StreamingBankIterator<TermBankV3Entry>(bankURLs: termBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                let term = ParsedTerm(from: entry)
                termsBatch.append(term)
                if termsBatch.count >= batchSize {
                    try await performTermBatchInsert(terms: termsBatch, dictionaryURI: dictionaryURI)
                    termsBatch.removeAll(keepingCapacity: true)
                }
            }
        default:
            throw DictionaryImportError.unsupportedFormat
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
                term.score = parsedTerm.score
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

    /// Process tag banks and send to the persistence layer (format 3 only). If format 1 has tag banks, treat as invalid data.
    private func processTagBanks(dictionaryID: NSManagedObjectID, dataFormat: Int) async throws {
        guard let tagBankURLs else { return }
        let dictionaryURI = dictionaryID.uriRepresentation()

        switch dataFormat {
        case 1:
            // v1 dictionaries should not have external tag banks
            throw DictionaryImportError.invalidData
        case 3:
            var tagsBatch: [TagBankV3Entry] = []
            tagsBatch.reserveCapacity(batchSize)
            let iterator = StreamingBankIterator<TagBankV3Entry>(bankURLs: tagBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                tagsBatch.append(entry)
                if tagsBatch.count >= batchSize {
                    try await performTagBatchInsert(tags: tagsBatch, dictionaryURI: dictionaryURI)
                    tagsBatch.removeAll(keepingCapacity: true)
                }
            }
            if !tagsBatch.isEmpty {
                try await performTagBatchInsert(tags: tagsBatch, dictionaryURI: dictionaryURI)
            }
        default:
            throw DictionaryImportError.unsupportedFormat
        }
    }

    /// Perform a batch insert of tags into Core Data.
    private func performTagBatchInsert(tags: [TagBankV3Entry], dictionaryURI: URL) async throws {
        try await container.performBackgroundTask { context in
            let batchInsert = createTagBatchInsertRequest(tags: tags, dictionaryURI: dictionaryURI)
            do {
                try context.execute(batchInsert)
            } catch {
                throw DictionaryImportError.batchInsertFailed
            }
        }
    }

    /// Create a batch insert request for tags.
    private func createTagBatchInsertRequest(tags: [TagBankV3Entry], dictionaryURI: URL) -> NSBatchInsertRequest {
        var index = 0
        let total = tags.count
        let batchInsert = NSBatchInsertRequest(entity: Tag.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let tag = managedObject as? Tag {
                let entry = tags[index]
                tag.name = entry.name
                tag.category = entry.category
                tag.order = entry.order
                tag.notes = entry.notes
                tag.score = entry.score
                tag.dictionary = dictionaryURI
            }
            index += 1
            return false
        }
        return batchInsert
    }

    /// Process term meta banks and send to the persistence layer (format 3 only). If format 1 has term meta banks, treat as invalid data.
    private func processTermMetaBanks(dictionaryID: NSManagedObjectID, dataFormat: Int) async throws {
        guard let termMetaBankURLs else { return }
        let dictionaryURI = dictionaryID.uriRepresentation()

        switch dataFormat {
        case 1:
            // v1 dictionaries should not have external term meta banks
            throw DictionaryImportError.invalidData
        case 3:
            var metaBatch: [TermMetaBankV3Entry] = []
            metaBatch.reserveCapacity(batchSize)
            let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: termMetaBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                metaBatch.append(entry)
                if metaBatch.count >= batchSize {
                    try await performTermMetaBatchInsert(entries: metaBatch, dictionaryURI: dictionaryURI)
                    metaBatch.removeAll(keepingCapacity: true)
                }
            }
            if !metaBatch.isEmpty {
                try await performTermMetaBatchInsert(entries: metaBatch, dictionaryURI: dictionaryURI)
            }
        default:
            throw DictionaryImportError.unsupportedFormat
        }
    }

    /// Perform a batch insert of term meta entries into Core Data.
    private func performTermMetaBatchInsert(entries: [TermMetaBankV3Entry], dictionaryURI: URL) async throws {
        try await container.performBackgroundTask { context in
            let batchInsert = createTermMetaBatchInsertRequest(entries: entries, dictionaryURI: dictionaryURI)
            do {
                try context.execute(batchInsert)
            } catch {
                throw DictionaryImportError.batchInsertFailed
            }
        }
    }

    /// Create a batch insert request for term meta entries.
    private func createTermMetaBatchInsertRequest(entries: [TermMetaBankV3Entry], dictionaryURI: URL) -> NSBatchInsertRequest {
        var index = 0
        let total = entries.count
        let batchInsert = NSBatchInsertRequest(entity: TermMeta.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let meta = managedObject as? TermMeta {
                let entry = entries[index]
                meta.expression = entry.term
                meta.type = entry.kind.rawValue
                // Assign transformable value using KVC to avoid NSObject cast requirements
                meta.setValue(entry.data, forKey: "data")
                switch entry.data {
                case let .frequency(freq):
                    meta.frequencyValue = freq.value
                    if let display = freq.displayValue { meta.displayFrequency = display }
                case let .frequencyWithReading(rf):
                    meta.frequencyValue = rf.frequency.value
                    if let display = rf.frequency.displayValue { meta.displayFrequency = display }
                case .pitch, .ipa:
                    break // no frequency fields
                }
                meta.dictionary = dictionaryURI
            }
            index += 1
            return false
        }
        return batchInsert
    }

    /// Process kanji banks and send to the persistence layer.
    private func processKanjiBanks(dictionaryID: NSManagedObjectID, dataFormat: Int) async throws {
        guard let kanjiBankURLs else { return }
        let dictionaryURI = dictionaryID.uriRepresentation()

        var kanjiBatch: [ParsedKanji] = []
        kanjiBatch.reserveCapacity(batchSize)

        switch dataFormat {
        case 1:
            let iterator = StreamingBankIterator<KanjiBankV1Entry>(bankURLs: kanjiBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                let parsed = ParsedKanji(from: entry)
                kanjiBatch.append(parsed)
                if kanjiBatch.count >= batchSize {
                    try await performKanjiBatchInsert(kanji: kanjiBatch, dictionaryURI: dictionaryURI)
                    kanjiBatch.removeAll(keepingCapacity: true)
                }
            }
        case 3:
            let iterator = StreamingBankIterator<KanjiBankV3Entry>(bankURLs: kanjiBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                let parsed = ParsedKanji(from: entry)
                kanjiBatch.append(parsed)
                if kanjiBatch.count >= batchSize {
                    try await performKanjiBatchInsert(kanji: kanjiBatch, dictionaryURI: dictionaryURI)
                    kanjiBatch.removeAll(keepingCapacity: true)
                }
            }
        default:
            throw DictionaryImportError.unsupportedFormat
        }

        if !kanjiBatch.isEmpty {
            try await performKanjiBatchInsert(kanji: kanjiBatch, dictionaryURI: dictionaryURI)
        }
    }

    /// Perform a batch insert of kanji into Core Data.
    private func performKanjiBatchInsert(kanji: [ParsedKanji], dictionaryURI: URL) async throws {
        try await container.performBackgroundTask { context in
            let batchInsert = createKanjiBatchInsertRequest(kanji: kanji, dictionaryURI: dictionaryURI)
            do {
                try context.execute(batchInsert)
            } catch {
                throw DictionaryImportError.batchInsertFailed
            }
        }
    }

    /// Create a batch insert request for kanji.
    private func createKanjiBatchInsertRequest(kanji: [ParsedKanji], dictionaryURI: URL) -> NSBatchInsertRequest {
        var index = 0
        let total = kanji.count
        let batchInsert = NSBatchInsertRequest(entity: Kanji.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let k = managedObject as? Kanji {
                let parsed = kanji[index]
                k.character = parsed.character
                k.onyomi = parsed.onyomi
                k.kunyomi = parsed.kunyomi
                k.tags = parsed.tags
                k.meanings = parsed.meanings
                k.stats = parsed.stats
                k.dictionary = dictionaryURI
            }
            index += 1
            return false
        }
        return batchInsert
    }

    /// Process kanji meta banks and send to the persistence layer (format 3 only). If format 1 has kanji meta banks, treat as invalid data.
    private func processKanjiMetaBanks(dictionaryID: NSManagedObjectID, dataFormat: Int) async throws {
        guard let kanjiMetaBankURLs else { return }
        let dictionaryURI = dictionaryID.uriRepresentation()

        switch dataFormat {
        case 1:
            // v1 dictionaries should not have external kanji meta banks
            throw DictionaryImportError.invalidData
        case 3:
            var metaBatch: [KanjiMetaBankV3Entry] = []
            metaBatch.reserveCapacity(batchSize)
            let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: kanjiMetaBankURLs, dataFormat: dataFormat)
            for try await entry in iterator {
                metaBatch.append(entry)
                if metaBatch.count >= batchSize {
                    try await performKanjiMetaBatchInsert(entries: metaBatch, dictionaryURI: dictionaryURI)
                    metaBatch.removeAll(keepingCapacity: true)
                }
            }
            if !metaBatch.isEmpty {
                try await performKanjiMetaBatchInsert(entries: metaBatch, dictionaryURI: dictionaryURI)
            }
        default:
            throw DictionaryImportError.unsupportedFormat
        }
    }

    /// Perform a batch insert of kanji meta entries into Core Data.
    private func performKanjiMetaBatchInsert(entries: [KanjiMetaBankV3Entry], dictionaryURI: URL) async throws {
        try await container.performBackgroundTask { context in
            let batchInsert = createKanjiMetaBatchInsertRequest(entries: entries, dictionaryURI: dictionaryURI)
            do {
                try context.execute(batchInsert)
            } catch {
                throw DictionaryImportError.batchInsertFailed
            }
        }
    }

    /// Create a batch insert request for kanji meta entries.
    private func createKanjiMetaBatchInsertRequest(entries: [KanjiMetaBankV3Entry], dictionaryURI: URL) -> NSBatchInsertRequest {
        var index = 0
        let total = entries.count
        let batchInsert = NSBatchInsertRequest(entity: KanjiMeta.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let meta = managedObject as? KanjiMeta {
                let entry = entries[index]
                meta.character = entry.kanji
                meta.type = entry.type
                switch entry.frequency {
                case let .number(num):
                    meta.frequencyValue = num
                case let .string(str):
                    meta.displayFrequency = str
                    if let num = Double(str) { meta.frequencyValue = num }
                case let .object(value, displayValue):
                    meta.frequencyValue = value
                    if let displayValue { meta.displayFrequency = displayValue }
                }
                meta.dictionary = dictionaryURI
            }
            index += 1
            return false
        }
        return batchInsert
    }
}
