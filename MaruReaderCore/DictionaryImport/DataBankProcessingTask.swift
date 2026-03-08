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
import os

struct DataBankProcessingTask {
    static let batchSize = 5000

    let jobID: NSManagedObjectID
    let dictionaryID: UUID
    let archiveURL: URL
    let bankPaths: DictionaryBankPaths
    let persistentContainer: NSPersistentContainer
    private let logger = Logger.maru(category: "TermBankProcessingTask")

    /// Thread-safe counter for tracking total entries processed across concurrent channels.
    private actor ProgressCounter {
        private var value = 0

        func add(_ count: Int) -> Int {
            value += count
            return value
        }
    }

    init(jobID: NSManagedObjectID, dictionaryID: UUID, archiveURL: URL, bankPaths: DictionaryBankPaths, container: NSPersistentContainer) {
        self.jobID = jobID
        self.dictionaryID = dictionaryID
        self.archiveURL = archiveURL
        self.bankPaths = bankPaths
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

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.termBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<TermBankV1Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await termEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            termEntryChannel.fail(error)
                        }
                    }
                }
            }
            termEntryChannel.finish()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.kanjiBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<KanjiBankV1Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await kanjiEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            kanjiEntryChannel.fail(error)
                        }
                    }
                }
            }
            kanjiEntryChannel.finish()
        }

        async let termsProcessed = processChannel(channel: termEntryChannel, entityName: "TermEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let kanjiProcessed = processChannel(channel: kanjiEntryChannel, entityName: "KanjiEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        let results = try await [
            termsProcessed,
            kanjiProcessed,
        ]
        logger.info("Processed \(results.reduce(0, +)) entries: Terms=\(results[0]), Kanji=\(results[1])")
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

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.termBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<TermBankV3Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await termEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            termEntryChannel.fail(error)
                        }
                    }
                }
            }
            termEntryChannel.finish()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.kanjiBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<KanjiBankV3Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await kanjiEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            kanjiEntryChannel.fail(error)
                        }
                    }
                }
            }
            kanjiEntryChannel.finish()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.tagBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<TagBankV3Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await dictionaryTagMetaEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            dictionaryTagMetaEntryChannel.fail(error)
                        }
                    }
                }
            }
            dictionaryTagMetaEntryChannel.finish()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.kanjiMetaBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    await kanjiFrequencyEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                                }
                            }
                        } catch {
                            kanjiFrequencyEntryChannel.fail(error)
                        }
                    }
                }
            }
            kanjiFrequencyEntryChannel.finish()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for path in bankPaths.termMetaBanks {
                    group.addTask {
                        do {
                            try await self.withExtractedEntry(archiveURL: archiveURL, entryPath: path) { fileURL in
                                let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [fileURL])
                                for try await entry in iterator {
                                    let dataDict = entry.toDataDictionary(dictionaryID: self.dictionaryID)
                                    switch dataDict.0 {
                                    case .termFrequencyEntry:
                                        await termFrequencyEntryChannel.send(dataDict.1)
                                    case .pitchAccentEntry:
                                        await pitchAccentEntryChannel.send(dataDict.1)
                                    case .ipaEntry:
                                        await ipaEntryChannel.send(dataDict.1)
                                    default: throw DictionaryImportError.invalidData
                                    }
                                }
                            }
                        } catch {
                            termFrequencyEntryChannel.fail(error)
                            pitchAccentEntryChannel.fail(error)
                            ipaEntryChannel.fail(error)
                        }
                    }
                }
            }
            termFrequencyEntryChannel.finish()
            pitchAccentEntryChannel.finish()
            ipaEntryChannel.finish()
        }

        async let termsProcessed = processChannel(channel: termEntryChannel, entityName: "TermEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let kanjiProcessed = processChannel(channel: kanjiEntryChannel, entityName: "KanjiEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let termFrequencyProcessed = processChannel(channel: termFrequencyEntryChannel, entityName: "TermFrequencyEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let kanjiFrequencyProcessed = processChannel(channel: kanjiFrequencyEntryChannel, entityName: "KanjiFrequencyEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let pitchAccentProcessed = processChannel(channel: pitchAccentEntryChannel, entityName: "PitchAccentEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let ipaProcessed = processChannel(channel: ipaEntryChannel, entityName: "IPAEntry", context: context, progressCounter: progressCounter, progressContext: progressContext)
        async let tagMetaProcessed = processChannel(channel: dictionaryTagMetaEntryChannel, entityName: "DictionaryTagMeta", context: context, progressCounter: progressCounter, progressContext: progressContext)
        let results = try await [
            termsProcessed,
            kanjiProcessed,
            termFrequencyProcessed,
            kanjiFrequencyProcessed,
            pitchAccentProcessed,
            ipaProcessed,
            tagMetaProcessed,
        ]

        try await context.perform {
            guard let dictionary = try? context.existingObject(with: self.jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.ipaCount = Int64(results[5])
            dictionary.pitchesCount = Int64(results[4])
            dictionary.kanjiCount = Int64(results[1])
            dictionary.termCount = Int64(results[0])
            dictionary.tagCount = Int64(results[6])
            dictionary.kanjiFrequencyCount = Int64(results[3])
            dictionary.termFrequencyCount = Int64(results[2])
            try context.save()
        }
        logger.info("Processed \(results.reduce(0, +)) entries: Terms=\(results[0]), Kanji=\(results[1]), TermFrequency=\(results[2]), KanjiFrequency=\(results[3]), PitchAccent=\(results[4]), IPA=\(results[5]), TagMeta=\(results[6])")
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

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
