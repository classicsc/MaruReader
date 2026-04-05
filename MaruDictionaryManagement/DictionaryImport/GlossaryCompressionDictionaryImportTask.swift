// GlossaryCompressionDictionaryImportTask.swift
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
import MaruReaderCore
import os

struct GlossaryCompressionDictionaryImportTask {
    let jobID: NSManagedObjectID
    let dictionaryID: UUID
    let archiveURL: URL
    let bankPaths: DictionaryBankPaths
    let glossaryCompressionVersion: GlossaryCompressionCodecVersion
    let glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile
    let baseDirectory: URL?
    let persistentContainer: NSPersistentContainer

    private let logger = Logger.maru(category: "GlossaryCompressionDictionaryImport")

    init(
        jobID: NSManagedObjectID,
        dictionaryID: UUID,
        archiveURL: URL,
        bankPaths: DictionaryBankPaths,
        glossaryCompressionVersion: GlossaryCompressionCodecVersion,
        glossaryCompressionTrainingProfile: GlossaryCompressionTrainingProfile,
        baseDirectory: URL?,
        container: NSPersistentContainer
    ) {
        self.jobID = jobID
        self.dictionaryID = dictionaryID
        self.archiveURL = archiveURL
        self.bankPaths = bankPaths
        self.glossaryCompressionVersion = glossaryCompressionVersion
        self.glossaryCompressionTrainingProfile = glossaryCompressionTrainingProfile
        self.baseDirectory = baseDirectory
        self.persistentContainer = container
    }

    func start() async throws -> GlossaryCompressionCodecVersion {
        guard glossaryCompressionVersion == .zstdRuntimeV1 else {
            return glossaryCompressionVersion
        }

        guard !bankPaths.termBanks.isEmpty else {
            return glossaryCompressionVersion
        }

        guard let baseDirectory else {
            throw DictionaryImportError.databaseError
        }

        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let format = try await context.perform {
            guard let dictionary = try? context.existingObject(with: jobID) as? Dictionary else {
                throw DictionaryImportError.databaseError
            }

            let formatRaw = Int(dictionary.format)
            guard let format = try? DictionaryFormat.resolve(format: formatRaw, version: nil) else {
                throw DictionaryImportError.databaseError
            }

            dictionary.displayProgressMessage = FrameworkLocalization.string("Training glossary compression...")
            try context.save()
            return format
        }

        do {
            let dictionaryIdentifier = GlossaryCompressionCodec.runtimeZSTDDictionaryIdentifier(for: dictionaryID)
            let buildResult = try await GlossaryCompressionDictionaryBuilder.buildRuntimeImportZSTDDictionary(
                named: dictionaryIdentifier,
                fromArchive: archiveURL,
                format: format,
                termBankPaths: bankPaths.termBanks,
                profile: glossaryCompressionTrainingProfile,
                scratchSpace: ImportScratchSpace(kind: .dictionary, jobUUID: dictionaryID)
            )

            try Task.checkCancellation()
            let destinationURL = GlossaryCompressionCodec.zstdDictionaryURL(dictionaryID: dictionaryID, in: baseDirectory)
            try writeZSTDDictionary(buildResult.dictionary, to: destinationURL)

            logger.debug("Trained runtime glossary dictionary \(dictionaryIdentifier, privacy: .public) from \(buildResult.sampleCount, privacy: .public) samples (\(buildResult.totalSampleBytes, privacy: .public) bytes)")
            return .zstdRuntimeV1
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.warning("Runtime glossary compression training failed for \(dictionaryID.uuidString, privacy: .public); falling back to zstd-v1: \(error.localizedDescription, privacy: .public)")
            return .zstdV1
        }
    }

    private func writeZSTDDictionary(
        _ dictionary: GlossaryCompressionZSTDDictionary,
        to destinationURL: URL
    ) throws {
        let fileManager = FileManager.default
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try dictionary.data.write(to: destinationURL, options: .atomic)
    }
}
