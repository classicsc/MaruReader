// AudioSourceEntryProcessingTask.swift
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

import CoreData
import Foundation
import os

/// A task to process headword and file entries from the audio source index.
/// Uses streaming iteration to handle large files without loading everything into memory.
struct AudioSourceEntryProcessingTask {
    static let batchSize = 5000

    let jobID: NSManagedObjectID
    let sourceID: UUID
    let indexURL: URL
    let persistentContainer: NSPersistentContainer
    private let logger = Logger.maru(category: "AudioSourceEntryProcessingTask")

    init(jobID: NSManagedObjectID, sourceID: UUID, indexURL: URL, container: NSPersistentContainer) {
        self.jobID = jobID
        self.sourceID = sourceID
        self.indexURL = indexURL
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let jobID = self.jobID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            job.displayProgressMessage = FrameworkLocalization.string("Processing audio entries...")
            try context.save()
        }

        try Task.checkCancellation()

        // Process headwords
        let headwordCount = try await processHeadwords(context: context)
        logger.info("Processed \(headwordCount) headword entries")

        try Task.checkCancellation()

        // Process files
        let fileCount = try await processFiles(context: context)
        logger.info("Processed \(fileCount) file entries")

        try Task.checkCancellation()

        try await context.perform {
            guard let job = try context.existingObject(with: jobID) as? AudioSource else {
                throw AudioSourceImportError.importNotFound
            }
            job.entriesProcessed = true
            job.displayProgressMessage = FrameworkLocalization.string("Processed \(headwordCount) headwords and \(fileCount) audio files.")
            try context.save()
        }
    }

    /// Process all headword entries from the index.
    private func processHeadwords(context: NSManagedObjectContext) async throws -> Int {
        let iterator = StreamingAudioSourceHeadwordIterator(fileURL: indexURL)
        var batch: [[String: any Sendable]] = []
        var totalProcessed = 0

        for try await (expression, filenames) in iterator {
            try Task.checkCancellation()

            let filesJSON: String
            do {
                let data = try JSONEncoder().encode(filenames)
                filesJSON = String(data: data, encoding: .utf8) ?? "[]"
            } catch {
                filesJSON = "[]"
            }

            batch.append([
                "id": UUID(),
                "sourceID": sourceID,
                "expression": expression,
                "files": filesJSON,
            ])

            if batch.count >= Self.batchSize {
                totalProcessed += try await insertBatch(batch, entityName: "AudioHeadword", context: context)
                batch.removeAll(keepingCapacity: true)
            }
        }

        // Insert remaining entries
        if !batch.isEmpty {
            totalProcessed += try await insertBatch(batch, entityName: "AudioHeadword", context: context)
        }

        return totalProcessed
    }

    /// Process all file entries from the index.
    private func processFiles(context: NSManagedObjectContext) async throws -> Int {
        let iterator = StreamingAudioSourceFileIterator(fileURL: indexURL)
        var batch: [[String: any Sendable]] = []
        var totalProcessed = 0

        for try await (filename, info) in iterator {
            try Task.checkCancellation()

            let normalizedReading = normalizeReading(info.kanaReading)

            batch.append([
                "id": UUID(),
                "sourceID": sourceID,
                "name": filename,
                "kanaReading": info.kanaReading,
                "normalizedReading": normalizedReading,
                "pitchPattern": info.pitchPattern ?? "",
                "pitchNumber": info.pitchNumber ?? "",
            ])

            if batch.count >= Self.batchSize {
                totalProcessed += try await insertBatch(batch, entityName: "AudioFile", context: context)
                batch.removeAll(keepingCapacity: true)
            }
        }

        // Insert remaining entries
        if !batch.isEmpty {
            totalProcessed += try await insertBatch(batch, entityName: "AudioFile", context: context)
        }

        return totalProcessed
    }

    /// Insert a batch of entries using NSBatchInsertRequest.
    private func insertBatch(_ batch: [[String: any Sendable]], entityName: String, context: NSManagedObjectContext) async throws -> Int {
        try await context.perform {
            let batchInsert = NSBatchInsertRequest(entityName: entityName, objects: batch)
            batchInsert.resultType = .count
            let result = try context.execute(batchInsert) as? NSBatchInsertResult
            return result?.result as? Int ?? 0
        }
    }

    /// Normalize a kana reading for matching purposes.
    /// Converts to hiragana and applies Unicode NFC normalization.
    private func normalizeReading(_ reading: String) -> String {
        // Apply NFC normalization
        let normalized = reading.precomposedStringWithCanonicalMapping

        // Convert katakana to hiragana
        var result = ""
        for scalar in normalized.unicodeScalars {
            // Katakana range: 0x30A1-0x30F6
            // Hiragana range: 0x3041-0x3096
            // Offset: 0x60
            if scalar.value >= 0x30A1, scalar.value <= 0x30F6 {
                let hiraganaValue = scalar.value - 0x60
                if let hiragana = UnicodeScalar(hiraganaValue) {
                    result.append(Character(hiragana))
                } else {
                    result.append(Character(scalar))
                }
            } else {
                result.append(Character(scalar))
            }
        }

        return result
    }
}
