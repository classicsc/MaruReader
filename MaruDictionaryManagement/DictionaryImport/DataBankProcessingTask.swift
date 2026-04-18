// DataBankProcessingTask.swift
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

internal import AsyncAlgorithms
internal import ReadiumZIPFoundation
import CoreData
import Foundation
import MaruReaderCore
import os

struct DataBankProcessingTask {
    static let batchSize = 50000

    let jobID: NSManagedObjectID
    let dictionaryID: UUID
    let archiveURL: URL
    let bankPaths: DictionaryBankPaths
    let glossaryCompressionVersion: GlossaryCompressionCodecVersion
    let glossaryCompressionBaseDirectory: URL?
    let glossaryZSTDCompressionLevel: Int32?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger.maru(category: "TermBankProcessingTask")

    private var scratchSpace: ImportScratchSpace {
        ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryID)
    }

    /// Thread-safe counter for tracking total entries processed across concurrent channels.
    private actor ProgressCounter {
        private var value = 0

        func add(_ count: Int) -> Int {
            value += count
            return value
        }
    }

    private enum BankProcessingCategory {
        case terms
        case kanji
        case termFrequency
        case kanjiFrequency
        case pitchAccent
        case ipa
        case tagMeta
    }

    private enum BankProcessingResult {
        case producerFinished
        case processed(BankProcessingCategory, Int)
    }

    init(
        jobID: NSManagedObjectID,
        dictionaryID: UUID,
        archiveURL: URL,
        bankPaths: DictionaryBankPaths,
        glossaryCompressionVersion: GlossaryCompressionCodecVersion,
        glossaryCompressionBaseDirectory: URL?,
        glossaryZSTDCompressionLevel: Int32?,
        container: NSPersistentContainer
    ) {
        self.jobID = jobID
        self.dictionaryID = dictionaryID
        self.archiveURL = archiveURL
        self.bankPaths = bankPaths
        self.glossaryCompressionVersion = glossaryCompressionVersion
        self.glossaryCompressionBaseDirectory = glossaryCompressionBaseDirectory
        self.glossaryZSTDCompressionLevel = glossaryZSTDCompressionLevel
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        // Fetch format and term bank URLs on the context queue
        let format = try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            let formatRaw = Int(dictionary.format)
            guard let format = try? DictionaryFormat.resolve(format: formatRaw, version: nil) else {
                throw DictionaryImportError.databaseError
            }
            return format
        }

        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.displayProgressMessage = FrameworkLocalization.string("Processing dictionary data...")
            try context.save()
        }

        try await processDataBanks(format: format, bankPaths: bankPaths, archiveURL: archiveURL, context: context)

        // Mark banks as processed
        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.displayProgressMessage = FrameworkLocalization.string("Processed data.")
            dictionary.banksProcessed = true
            try context.save()
        }

        try Task.checkCancellation()
    }

    private func processDataBanks(format: DictionaryFormat, bankPaths: DictionaryBankPaths, archiveURL: URL, context: NSManagedObjectContext) async throws {
        switch format {
        case .v1:
            try await processV1DataBanks(bankPaths: bankPaths, archiveURL: archiveURL, context: context)
        case .v3:
            try await processV3DataBanks(bankPaths: bankPaths, archiveURL: archiveURL, context: context)
        }
    }

    private func processV1DataBanks(bankPaths: DictionaryBankPaths, archiveURL: URL, context: NSManagedObjectContext) async throws {
        let termEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let progressCounter = ProgressCounter()
        let progressContext = persistentContainer.newBackgroundContext()
        var termsProcessed = 0
        var kanjiProcessed = 0

        try await withThrowingTaskGroup(of: BankProcessingResult.self) { group in
            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.termBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<TermBankV1Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await termEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    termEntryChannel.finish()
                    return .producerFinished
                } catch {
                    termEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.kanjiBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<KanjiBankV1Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await kanjiEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    kanjiEntryChannel.finish()
                    return .producerFinished
                } catch {
                    kanjiEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                try await .processed(
                    .terms,
                    self.processChannel(
                        channel: termEntryChannel,
                        entityName: "TermEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .kanji,
                    self.processChannel(
                        channel: kanjiEntryChannel,
                        entityName: "KanjiEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            do {
                for try await result in group {
                    switch result {
                    case .producerFinished:
                        break
                    case let .processed(.terms, count):
                        termsProcessed = count
                    case let .processed(.kanji, count):
                        kanjiProcessed = count
                    default:
                        break
                    }
                }
            } catch {
                group.cancelAll()
                termEntryChannel.fail(error)
                kanjiEntryChannel.fail(error)
                throw error
            }
        }

        logger.info("Processed \(termsProcessed + kanjiProcessed) entries: Terms=\(termsProcessed), Kanji=\(kanjiProcessed)")
    }

    private func processV3DataBanks(bankPaths: DictionaryBankPaths, archiveURL: URL, context: NSManagedObjectContext) async throws {
        let termEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let termFrequencyEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiFrequencyEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let pitchAccentEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let ipaEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let dictionaryTagMetaEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let progressCounter = ProgressCounter()
        let progressContext = persistentContainer.newBackgroundContext()

        var termsProcessed = 0
        var kanjiProcessed = 0
        var termFrequencyProcessed = 0
        var kanjiFrequencyProcessed = 0
        var pitchAccentProcessed = 0
        var ipaProcessed = 0
        var tagMetaProcessed = 0

        try await withThrowingTaskGroup(of: BankProcessingResult.self) { group in
            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.termBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<TermBankV3Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await termEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    termEntryChannel.finish()
                    return .producerFinished
                } catch {
                    termEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.kanjiBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<KanjiBankV3Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await kanjiEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    kanjiEntryChannel.finish()
                    return .producerFinished
                } catch {
                    kanjiEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.tagBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<TagBankV3Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await dictionaryTagMetaEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    dictionaryTagMetaEntryChannel.finish()
                    return .producerFinished
                } catch {
                    dictionaryTagMetaEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.kanjiMetaBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        try await kanjiFrequencyEntryChannel.send(
                                            entry.toDataDictionary(
                                                dictionaryID: self.dictionaryID,
                                                glossaryCompressionVersion: self.glossaryCompressionVersion,
                                                glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                                glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                            ).1
                                        )
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    kanjiFrequencyEntryChannel.finish()
                    return .producerFinished
                } catch {
                    kanjiFrequencyEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for path in bankPaths.termMetaBanks {
                            group.addTask {
                                try Task.checkCancellation()
                                try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                    let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [fileURL])
                                    for try await entry in iterator {
                                        let dataDict = try entry.toDataDictionary(
                                            dictionaryID: self.dictionaryID,
                                            glossaryCompressionVersion: self.glossaryCompressionVersion,
                                            glossaryCompressionBaseDirectory: self.glossaryCompressionBaseDirectory,
                                            glossaryZSTDCompressionLevel: self.glossaryZSTDCompressionLevel
                                        )
                                        switch dataDict.0 {
                                        case .termFrequencyEntry:
                                            await termFrequencyEntryChannel.send(dataDict.1)
                                        case .pitchAccentEntry:
                                            await pitchAccentEntryChannel.send(dataDict.1)
                                        case .ipaEntry:
                                            await ipaEntryChannel.send(dataDict.1)
                                        default:
                                            throw DictionaryImportError.invalidData
                                        }
                                    }
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                    termFrequencyEntryChannel.finish()
                    pitchAccentEntryChannel.finish()
                    ipaEntryChannel.finish()
                    return .producerFinished
                } catch {
                    termFrequencyEntryChannel.fail(error)
                    pitchAccentEntryChannel.fail(error)
                    ipaEntryChannel.fail(error)
                    throw error
                }
            }

            group.addTask {
                try await .processed(
                    .terms,
                    self.processChannel(
                        channel: termEntryChannel,
                        entityName: "TermEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .kanji,
                    self.processChannel(
                        channel: kanjiEntryChannel,
                        entityName: "KanjiEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .termFrequency,
                    self.processChannel(
                        channel: termFrequencyEntryChannel,
                        entityName: "TermFrequencyEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .kanjiFrequency,
                    self.processChannel(
                        channel: kanjiFrequencyEntryChannel,
                        entityName: "KanjiFrequencyEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .pitchAccent,
                    self.processChannel(
                        channel: pitchAccentEntryChannel,
                        entityName: "PitchAccentEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .ipa,
                    self.processChannel(
                        channel: ipaEntryChannel,
                        entityName: "IPAEntry",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            group.addTask {
                try await .processed(
                    .tagMeta,
                    self.processChannel(
                        channel: dictionaryTagMetaEntryChannel,
                        entityName: "DictionaryTagMeta",
                        context: context,
                        progressCounter: progressCounter,
                        progressContext: progressContext
                    )
                )
            }

            do {
                for try await result in group {
                    switch result {
                    case .producerFinished:
                        break
                    case let .processed(.terms, count):
                        termsProcessed = count
                    case let .processed(.kanji, count):
                        kanjiProcessed = count
                    case let .processed(.termFrequency, count):
                        termFrequencyProcessed = count
                    case let .processed(.kanjiFrequency, count):
                        kanjiFrequencyProcessed = count
                    case let .processed(.pitchAccent, count):
                        pitchAccentProcessed = count
                    case let .processed(.ipa, count):
                        ipaProcessed = count
                    case let .processed(.tagMeta, count):
                        tagMetaProcessed = count
                    }
                }
            } catch {
                group.cancelAll()
                termEntryChannel.fail(error)
                kanjiEntryChannel.fail(error)
                termFrequencyEntryChannel.fail(error)
                kanjiFrequencyEntryChannel.fail(error)
                pitchAccentEntryChannel.fail(error)
                ipaEntryChannel.fail(error)
                dictionaryTagMetaEntryChannel.fail(error)
                throw error
            }
        }

        let finalCounts = (
            terms: termsProcessed,
            kanji: kanjiProcessed,
            termFrequency: termFrequencyProcessed,
            kanjiFrequency: kanjiFrequencyProcessed,
            pitchAccent: pitchAccentProcessed,
            ipa: ipaProcessed,
            tagMeta: tagMetaProcessed
        )

        try await context.perform {
            guard let dictionary = try? context.existingObject(with: self.jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.ipaCount = Int64(finalCounts.ipa)
            dictionary.pitchesCount = Int64(finalCounts.pitchAccent)
            dictionary.kanjiCount = Int64(finalCounts.kanji)
            dictionary.termCount = Int64(finalCounts.terms)
            dictionary.tagCount = Int64(finalCounts.tagMeta)
            dictionary.kanjiFrequencyCount = Int64(finalCounts.kanjiFrequency)
            dictionary.termFrequencyCount = Int64(finalCounts.termFrequency)
            try context.save()
        }
        logger.info(
            "Processed \(finalCounts.terms + finalCounts.kanji + finalCounts.termFrequency + finalCounts.kanjiFrequency + finalCounts.pitchAccent + finalCounts.ipa + finalCounts.tagMeta) entries: Terms=\(finalCounts.terms), Kanji=\(finalCounts.kanji), TermFrequency=\(finalCounts.termFrequency), KanjiFrequency=\(finalCounts.kanjiFrequency), PitchAccent=\(finalCounts.pitchAccent), IPA=\(finalCounts.ipa), TagMeta=\(finalCounts.tagMeta)"
        )
    }

    private func processChannel(
        channel: AsyncThrowingChannel<[String: Sendable], Error>,
        entityName: String,
        context: NSManagedObjectContext,
        progressCounter: ProgressCounter,
        progressContext: NSManagedObjectContext
    ) async throws -> Int {
        var batch: [[String: Sendable]] = []
        var itemsProcessed = 0
        for try await entry in channel {
            try Task.checkCancellation()

            batch.append(entry)

            if batch.count >= Self.batchSize {
                let batchCount = try await processBatch(batch: batch, entity: entityName, context: context)
                itemsProcessed += batchCount
                let newTotal = await progressCounter.add(batchCount)
                await reportBankProgress(count: newTotal, context: progressContext)
                batch.removeAll(keepingCapacity: true)
            }
        }
        // Process any remaining items in the batch
        if !batch.isEmpty {
            let batchCount = try await processBatch(batch: batch, entity: entityName, context: context)
            itemsProcessed += batchCount
            let newTotal = await progressCounter.add(batchCount)
            await reportBankProgress(count: newTotal, context: progressContext)
            batch.removeAll()
        }
        return itemsProcessed
    }

    private func processBatch(batch: [[String: Sendable]], entity: String, context: NSManagedObjectContext) async throws -> Int {
        try await context.perform {
            let batchInsert = NSBatchInsertRequest(entityName: entity, objects: batch)
            batchInsert.resultType = .count
            let result = try context.execute(batchInsert) as? NSBatchInsertResult
            return result?.result as? Int ?? 0
        }
    }

    private func reportBankProgress(count: Int, context: NSManagedObjectContext) async {
        let jobID = self.jobID
        await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else { return }
            dictionary.displayProgressMessage = FrameworkLocalization.string("Processing dictionary data… (\(count.formatted()) entries)")
            try? context.save()
        }
    }

    private func withExtractedEntry<T>(
        archiveURL: URL,
        entryPath: String,
        skipCRC32: Bool = true,
        body: (URL) async throws -> T
    ) async throws -> T {
        // Access security scoped resource if needed (returns false for in-sandbox files)
        let didStartAccess = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        let archive: Archive
        do {
            archive = try await Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        let entry: Entry
        do {
            guard let resolvedEntry = try await archive.get(entryPath) else {
                throw DictionaryImportError.invalidData
            }
            entry = resolvedEntry
        } catch {
            if let importError = error as? DictionaryImportError {
                throw importError
            }
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        let tempURL: URL
        do {
            tempURL = try scratchSpace.makeUniqueFileURL(pathExtension: "json")
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await archive.extract(entry, to: tempURL, skipCRC32: skipCRC32)
            return try await body(tempURL)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
    }
}
