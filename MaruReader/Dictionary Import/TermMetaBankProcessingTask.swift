//
//  TermMetaBankProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

actor TermMetaBankProcessingTask {
    static let batchSize = 500

    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TermMetaBankProcessingTask")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() {
        let container = persistentContainer
        let jobID = self.jobID

        task = Task {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            // Fetch format and term meta bank URLs on the context queue
            let (format, termMetaBankURLs, dictionary): (Int64, [URL], Dictionary) = try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                guard let dictionary = job.dictionary else {
                    throw DictionaryImportError.databaseError
                }
                let format = dictionary.format
                guard let termMetaBankURLs = job.termMetaBanks as? [URL] else {
                    throw DictionaryImportError.databaseError
                }
                return (format, termMetaBankURLs, dictionary)
            }

            if !termMetaBankURLs.isEmpty {
                // Process term meta banks only for format 3
                guard format == 3 else {
                    throw DictionaryImportError.invalidData
                }

                try await context.perform {
                    guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                        throw DictionaryImportError.databaseError
                    }
                    job.displayProgressMessage = "Processing term metadata..."
                    try context.save()
                }

                let termMetaIterator = StreamingBankIterator<TermMetaBankV3Entry>(
                    bankURLs: termMetaBankURLs,
                    dataFormat: Int(format)
                )

                var entryBatch: [TermMetaBankV3Entry] = []

                for try await entry in termMetaIterator {
                    try Task.checkCancellation()

                    entryBatch.append(entry)

                    if entryBatch.count >= Self.batchSize {
                        let currentBatch = entryBatch
                        entryBatch.removeAll(keepingCapacity: true)

                        try await processBatch(currentBatch, jobID: jobID, context: context)
                        try Task.checkCancellation()
                    }
                }

                // Process any remaining entries in the batch
                if !entryBatch.isEmpty {
                    let currentBatch = entryBatch
                    entryBatch.removeAll()

                    try await processBatch(currentBatch, jobID: jobID, context: context)
                    try Task.checkCancellation()
                }
            }

            // Mark term meta banks as processed
            try await context.perform {
                guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.databaseError
                }
                job.setValue(termMetaBankURLs, forKey: "processedTermMetaBanks")
                job.displayProgressMessage = "Processed term metadata."
                try context.save()
            }

            try Task.checkCancellation()
        }
    }

    private func processBatch(_ batch: [TermMetaBankV3Entry], jobID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        try await context.perform {
            guard let job = try? context.existingObject(with: jobID) as? DictionaryZIPFileImport,
                  let dictionary = job.dictionary
            else {
                throw DictionaryImportError.databaseError
            }
            for entry in batch {
                switch entry.data {
                case let .frequency(freq):
                    // Create Term entity with empty reading for frequency entries without reading
                    let term = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.term, reading: "", context: context)

                    // Create TermFrequencyEntry
                    let frequencyEntry = TermFrequencyEntry(context: context)
                    frequencyEntry.id = UUID()
                    frequencyEntry.value = freq.value
                    frequencyEntry.displayValue = freq.displayValue

                    context.insert(frequencyEntry)

                    // Link relationships
                    frequencyEntry.term = term
                    frequencyEntry.dictionary = dictionary

                case let .frequencyWithReading(freqReading):
                    // Create TermFrequencyEntry with reading-specific term
                    let termWithReading = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.term, reading: freqReading.reading, context: context)
                    let frequencyEntry = TermFrequencyEntry(context: context)
                    frequencyEntry.id = UUID()
                    frequencyEntry.value = freqReading.frequency.value
                    frequencyEntry.displayValue = freqReading.frequency.displayValue

                    context.insert(frequencyEntry)

                    // Link relationships
                    frequencyEntry.term = termWithReading
                    frequencyEntry.dictionary = dictionary

                case let .pitch(pitchData):
                    // Create Term with specific reading
                    let termWithReading = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.term, reading: pitchData.reading, context: context)

                    // Create PitchAccentEntry for each pitch accent
                    for pitch in pitchData.pitches {
                        let pitchEntry = PitchAccentEntry(context: context)
                        pitchEntry.id = UUID()

                        // Handle position (mora or pattern)
                        switch pitch.position {
                        case let .mora(moraValue):
                            pitchEntry.mora = Int64(moraValue)
                            pitchEntry.pattern = nil
                        case let .pattern(patternValue):
                            pitchEntry.pattern = patternValue
                            pitchEntry.mora = 0
                        }

                        // Set optional arrays
                        pitchEntry.setValue(pitch.nasal, forKey: "nasal")
                        pitchEntry.setValue(pitch.devoice, forKey: "devoice")
                        pitchEntry.setValue(pitch.tags, forKey: "tags")

                        context.insert(pitchEntry)

                        // Link relationships
                        pitchEntry.term = termWithReading
                        pitchEntry.dictionary = dictionary

                        // Link tags
                        if let tags = pitch.tags {
                            try DictionaryImportUtilities.linkTagsToPitchEntry(pitchEntry, tags: tags, dictionary: dictionary, context: context)
                        }
                    }

                case let .ipa(ipaData):
                    // Create Term with specific reading
                    let termWithReading = try DictionaryImportUtilities.findOrCreateTerm(expression: entry.term, reading: ipaData.reading, context: context)

                    // Create IPAEntry for each transcription
                    for transcription in ipaData.transcriptions {
                        let ipaEntry = IPAEntry(context: context)
                        ipaEntry.id = UUID()
                        ipaEntry.transcription = transcription.ipa
                        ipaEntry.setValue(transcription.tags, forKey: "tags")

                        context.insert(ipaEntry)

                        // Link relationships
                        ipaEntry.term = termWithReading
                        ipaEntry.dictionary = dictionary

                        // Link tags
                        if let tags = transcription.tags {
                            try DictionaryImportUtilities.linkTagsToIPAEntry(ipaEntry, tags: tags, dictionary: dictionary, context: context)
                        }
                    }
                }
            }

            try context.save()
        }
    }
}
