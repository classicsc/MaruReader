//
//  DataBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

internal import AsyncAlgorithms
import CoreData
import Foundation
import os.log

struct DataBankProcessingTask {
    static let batchSize = 5000

    let jobID: NSManagedObjectID
    let dictionaryID: UUID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermBankProcessingTask")

    init(jobID: NSManagedObjectID, dictionaryID: UUID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.dictionaryID = dictionaryID
        self.persistentContainer = container
    }

    private static func decodeURLArray(from jsonString: String?) throws -> [URL] {
        guard let jsonString,
              let data = jsonString.data(using: .utf8)
        else {
            throw DictionaryImportError.databaseError
        }
        let strings = try JSONDecoder().decode([String].self, from: data)
        let urls = strings.compactMap { URL(string: $0) }
        guard urls.count == strings.count else {
            throw DictionaryImportError.invalidData
        }
        return urls
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        // Fetch format and term bank URLs on the context queue
        let (format, termBankURLs, kanjiBankURLs, termMetaBankURLs, kanjiMetaBankURLs, tagMetaBankURLs) = try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            let formatRaw = Int(dictionary.format)
            guard let format = try? DictionaryFormat.resolve(format: formatRaw, version: nil) else {
                throw DictionaryImportError.databaseError
            }
            let termBankURLs = try Self.decodeURLArray(from: dictionary.termBanks)
            let kanjiBankURLs = try Self.decodeURLArray(from: dictionary.kanjiBanks)
            let termMetaBankURLs = try Self.decodeURLArray(from: dictionary.termMetaBanks)
            let kanjiMetaBankURLs = try Self.decodeURLArray(from: dictionary.kanjiMetaBanks)
            let tagMetaBankURLs = try Self.decodeURLArray(from: dictionary.tagBanks)
            return (format, termBankURLs, kanjiBankURLs, termMetaBankURLs, kanjiMetaBankURLs, tagMetaBankURLs)
        }

        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.displayProgressMessage = "Processing dictionary data..."
            try context.save()
        }

        try await processDataBanks(format: format, termBankURLs: termBankURLs, kanjiBankURLs: kanjiBankURLs, termMetaBankURLs: termMetaBankURLs, kanjiMetaBankURLs: kanjiMetaBankURLs, tagMetaBankURLs: tagMetaBankURLs, context: context)

        // Mark banks as processed
        try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }
            dictionary.displayProgressMessage = "Processed data."
            dictionary.banksProcessed = true
            try context.save()
        }

        try Task.checkCancellation()
    }

    private func processDataBanks(format: DictionaryFormat, termBankURLs: [URL], kanjiBankURLs: [URL], termMetaBankURLs: [URL], kanjiMetaBankURLs: [URL], tagMetaBankURLs: [URL], context: NSManagedObjectContext) async throws {
        switch format {
        case .v1:
            try await processV1DataBanks(termBankURLs: termBankURLs, kanjiBankURLs: kanjiBankURLs, termMetaBankURLs: termMetaBankURLs, kanjiMetaBankURLs: kanjiMetaBankURLs, tagMetaBankURLs: tagMetaBankURLs, context: context)
        case .v3:
            try await processV3DataBanks(termBankURLs: termBankURLs, kanjiBankURLs: kanjiBankURLs, termMetaBankURLs: termMetaBankURLs, kanjiMetaBankURLs: kanjiMetaBankURLs, tagMetaBankURLs: tagMetaBankURLs, context: context)
        }
    }

    private func processV1DataBanks(termBankURLs: [URL], kanjiBankURLs: [URL], termMetaBankURLs _: [URL], kanjiMetaBankURLs _: [URL], tagMetaBankURLs _: [URL], context: NSManagedObjectContext) async throws {
        let termEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in termBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TermBankV1Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await termEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
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
                for url in kanjiBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiBankV1Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await kanjiEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
                            }
                        } catch {
                            kanjiEntryChannel.fail(error)
                        }
                    }
                }
            }
            kanjiEntryChannel.finish()
        }

        async let termsProcessed = processChannel(channel: termEntryChannel, entityName: "TermEntry", context: context)
        async let kanjiProcessed = processChannel(channel: kanjiEntryChannel, entityName: "KanjiEntry", context: context)
        let results = try await [
            termsProcessed,
            kanjiProcessed,
        ]
        logger.info("Processed \(results.reduce(0, +)) entries: Terms=\(results[0]), Kanji=\(results[1])")
    }

    private func processV3DataBanks(termBankURLs: [URL], kanjiBankURLs: [URL], termMetaBankURLs: [URL], kanjiMetaBankURLs: [URL], tagMetaBankURLs: [URL], context: NSManagedObjectContext) async throws {
        let termEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let termFrequencyEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let kanjiFrequencyEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let pitchAccentEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let ipaEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()
        let dictionaryTagMetaEntryChannel = AsyncThrowingChannel<[String: Sendable], Error>()

        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in termBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TermBankV3Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await termEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
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
                for url in kanjiBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiBankV3Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await kanjiEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
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
                for url in tagMetaBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TagBankV3Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await dictionaryTagMetaEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
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
                for url in kanjiMetaBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [url])
                        do {
                            for try await entry in iterator {
                                await kanjiFrequencyEntryChannel.send(entry.toDataDictionary(dictionaryID: self.dictionaryID).1)
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
                for url in termMetaBankURLs {
                    group.addTask {
                        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [url])
                        do {
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

        async let termsProcessed = processChannel(channel: termEntryChannel, entityName: "TermEntry", context: context)
        async let kanjiProcessed = processChannel(channel: kanjiEntryChannel, entityName: "KanjiEntry", context: context)
        async let termFrequencyProcessed = processChannel(channel: termFrequencyEntryChannel, entityName: "TermFrequencyEntry", context: context)
        async let kanjiFrequencyProcessed = processChannel(channel: kanjiFrequencyEntryChannel, entityName: "KanjiFrequencyEntry", context: context)
        async let pitchAccentProcessed = processChannel(channel: pitchAccentEntryChannel, entityName: "PitchAccentEntry", context: context)
        async let ipaProcessed = processChannel(channel: ipaEntryChannel, entityName: "IPAEntry", context: context)
        async let tagMetaProcessed = processChannel(channel: dictionaryTagMetaEntryChannel, entityName: "DictionaryTagMeta", context: context)
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

    private func processChannel(channel: AsyncThrowingChannel<[String: Sendable], Error>, entityName: String, context: NSManagedObjectContext) async throws -> Int {
        var batch: [[String: Sendable]] = []
        var itemsProcessed = 0
        for try await entry in channel {
            try Task.checkCancellation()

            batch.append(entry)

            if batch.count >= Self.batchSize {
                itemsProcessed += try await processBatch(batch: batch, entity: entityName, context: context)
                batch.removeAll(keepingCapacity: true)
            }
        }
        // Process any remaining items in the batch
        if !batch.isEmpty {
            itemsProcessed += try await processBatch(batch: batch, entity: entityName, context: context)
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
}
