// GlossaryCompressionDictionaryBuilder.swift
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

internal import ReadiumZIPFoundation
import Foundation
import MaruReaderCore

private let glossaryCompressionMinimumTrainableCorpusBytes = 32 * 1024

public struct GlossaryCompressionDictionaryBuildResult: Sendable {
    public let dictionary: GlossaryCompressionZSTDDictionary
    public let sampleCount: Int
    public let totalSampleBytes: Int

    public init(dictionary: GlossaryCompressionZSTDDictionary, sampleCount: Int, totalSampleBytes: Int) {
        self.dictionary = dictionary
        self.sampleCount = sampleCount
        self.totalSampleBytes = totalSampleBytes
    }
}

public enum GlossaryCompressionTrainingProfile: String, Sendable, Equatable, CaseIterable {
    case runtime
    case starterdict

    var targetTrainingCorpusBytes: Int {
        switch self {
        case .runtime:
            16 * 1024 * 100
        case .starterdict:
            96 * 1024 * 1024
        }
    }

    var windowStride: Int {
        256
    }

    var windowLength: Int {
        32
    }
}

public enum GlossaryCompressionDictionaryBuildError: Error, LocalizedError {
    case emptyTrainingCorpus
    case insufficientTrainingCorpus(sampleCount: Int, totalSampleBytes: Int)
    case trainingFailed(sampleCount: Int, totalSampleBytes: Int, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .emptyTrainingCorpus:
            "No glossary samples were found for zstd dictionary training."
        case let .insufficientTrainingCorpus(sampleCount, totalSampleBytes):
            """
            Insufficient glossary samples for zstd dictionary training: \(sampleCount.formatted()) samples \
            (\(totalSampleBytes.formatted()) bytes). At least \(glossaryCompressionMinimumTrainableCorpusBytes.formatted()) \
            bytes of real sampled glossary data are required.
            """
        case let .trainingFailed(sampleCount, totalSampleBytes, underlyingError):
            """
            Failed to train zstd dictionary from \(sampleCount.formatted()) glossary samples \
            (\(totalSampleBytes.formatted()) bytes): \(describe(underlyingError))
            """
        }
    }

    private func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty
        {
            return description
        }

        return String(reflecting: error)
    }
}

public enum GlossaryCompressionDictionaryBuilder {
    public static func buildZSTDDictionary(
        named identifier: String,
        fromArchives archiveURLs: [URL],
        profile: GlossaryCompressionTrainingProfile
    ) async throws -> GlossaryCompressionDictionaryBuildResult {
        let trainingCorpus = try await sampledTrainingCorpus(
            fromArchives: archiveURLs,
            profile: profile
        )
        return try buildZSTDDictionary(named: identifier, trainingCorpus: trainingCorpus)
    }

    static func buildRuntimeImportZSTDDictionary(
        named identifier: String,
        fromArchive archiveURL: URL,
        format: DictionaryFormat,
        termBankPaths: [String],
        profile: GlossaryCompressionTrainingProfile = .runtime,
        scratchSpace: ImportScratchSpace? = nil
    ) async throws -> GlossaryCompressionDictionaryBuildResult {
        let sampledCorpus = try await windowedGlossaryJSONSamples(
            fromArchive: archiveURL,
            format: format,
            termBankPaths: termBankPaths,
            targetTrainingCorpusBytes: profile.targetTrainingCorpusBytes,
            windowStride: profile.windowStride,
            windowLength: profile.windowLength,
            scratchSpace: scratchSpace
        )
        return try buildZSTDDictionary(named: identifier, trainingCorpus: sampledCorpus)
    }

    private static func buildZSTDDictionary(
        named identifier: String,
        trainingCorpus: (samples: [Data], sampleCount: Int, totalSampleBytes: Int)
    ) throws -> GlossaryCompressionDictionaryBuildResult {
        let sampleCount = trainingCorpus.sampleCount
        let totalSampleBytes = trainingCorpus.totalSampleBytes

        guard !trainingCorpus.samples.isEmpty else {
            throw GlossaryCompressionDictionaryBuildError.emptyTrainingCorpus
        }
        guard totalSampleBytes >= glossaryCompressionMinimumTrainableCorpusBytes else {
            throw GlossaryCompressionDictionaryBuildError.insufficientTrainingCorpus(
                sampleCount: sampleCount,
                totalSampleBytes: totalSampleBytes
            )
        }

        let dictionaryData: Data
        do {
            dictionaryData = try GlossaryCompressionCodec.buildZSTDDictionary(fromSamples: trainingCorpus.samples)
        } catch {
            throw GlossaryCompressionDictionaryBuildError.trainingFailed(
                sampleCount: sampleCount,
                totalSampleBytes: totalSampleBytes,
                underlyingError: error
            )
        }

        return GlossaryCompressionDictionaryBuildResult(
            dictionary: GlossaryCompressionZSTDDictionary(identifier: identifier, data: dictionaryData),
            sampleCount: sampleCount,
            totalSampleBytes: totalSampleBytes
        )
    }

    static func sampledTrainingCorpus(
        fromArchives archiveURLs: [URL],
        profile: GlossaryCompressionTrainingProfile
    ) async throws -> (samples: [Data], sampleCount: Int, totalSampleBytes: Int) {
        var glossarySamples: [Data] = []
        var totalSampleBytes = 0

        for archiveURL in archiveURLs {
            let archive = try await openArchive(at: archiveURL)
            let format = try await dictionaryFormat(in: archive)
            let entries = try await archive.entries()
            let termBankPaths = bankPaths(from: entries, prefix: "term_bank_")
            guard !termBankPaths.isEmpty else {
                continue
            }

            let remainingBytes = max(0, profile.targetTrainingCorpusBytes - totalSampleBytes)
            let sampledCorpus = try await windowedGlossaryJSONSamples(
                fromArchive: archiveURL,
                format: format,
                termBankPaths: termBankPaths,
                targetTrainingCorpusBytes: remainingBytes,
                windowStride: profile.windowStride,
                windowLength: profile.windowLength
            )

            glossarySamples.append(contentsOf: sampledCorpus.samples)
            totalSampleBytes += sampledCorpus.totalSampleBytes

            if totalSampleBytes >= profile.targetTrainingCorpusBytes {
                break
            }
        }

        return (glossarySamples, glossarySamples.count, totalSampleBytes)
    }

    static func windowedGlossaryJSONSamples(
        fromArchive archiveURL: URL,
        format: DictionaryFormat,
        termBankPaths: [String],
        targetTrainingCorpusBytes: Int,
        windowStride: Int,
        windowLength: Int,
        scratchSpace: ImportScratchSpace? = nil
    ) async throws -> (samples: [Data], sampleCount: Int, totalSampleBytes: Int) {
        let archive = try await openArchive(at: archiveURL)
        var glossarySamples: [Data] = []
        glossarySamples.reserveCapacity(windowLength * max(1, termBankPaths.count))
        var totalSampleBytes = 0

        for path in termBankPaths {
            try await withExtractedEntry(
                archive: archive,
                archiveURL: archiveURL,
                entryPath: path,
                scratchSpace: scratchSpace
            ) { fileURL in
                let extractedSamples = try GlossaryJSONWindowedSampler.collectGlossarySamples(
                    from: fileURL,
                    format: format,
                    windowStride: windowStride,
                    windowLength: windowLength,
                    maximumTotalBytes: max(0, targetTrainingCorpusBytes - totalSampleBytes)
                )

                for sample in extractedSamples {
                    glossarySamples.append(sample)
                    totalSampleBytes += sample.count
                }
            }

            if totalSampleBytes >= targetTrainingCorpusBytes {
                break
            }
        }

        if glossarySamples.isEmpty {
            return ([], 0, 0)
        }

        if totalSampleBytes == 0, let firstSample = glossarySamples.first {
            return ([firstSample], 1, firstSample.count)
        }

        return (glossarySamples, glossarySamples.count, totalSampleBytes)
    }

    private static func openArchive(at archiveURL: URL) async throws -> Archive {
        let didStartAccess = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw DictionaryImportError.missingFile
        }

        do {
            return try await Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
    }

    private static func dictionaryFormat(in archive: Archive) async throws -> DictionaryFormat {
        guard let indexEntry = try await archive.get("index.json") else {
            throw DictionaryImportError.notADictionary
        }

        do {
            let indexData = try await archive.extractData(indexEntry, skipCRC32: true)
            let index = try JSONDecoder().decode(DictionaryIndex.self, from: indexData)
            guard let format = index.format, ImportManager.supportedFormats.contains(format) else {
                throw DictionaryImportError.unsupportedFormat
            }

            switch format {
            case 1:
                return .v1
            case 3:
                return .v3
            default:
                throw DictionaryImportError.unsupportedFormat
            }
        } catch let error as DictionaryImportError {
            throw error
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
    }

    private static func bankPaths(from entries: [Entry], prefix: String) -> [String] {
        entries.compactMap { entry in
            guard entry.type == .file else {
                return nil
            }

            let name = entry.path.split(separator: "/").last.map(String.init) ?? entry.path
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else {
                return nil
            }

            return entry.path
        }
    }

    private static func withExtractedEntry<T>(
        archive: Archive,
        archiveURL: URL,
        entryPath: String,
        scratchSpace: ImportScratchSpace? = nil,
        skipCRC32: Bool = true,
        body: (URL) async throws -> T
    ) async throws -> T {
        let didStartAccess = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        let entry: Entry
        do {
            guard let resolvedEntry = try await archive.get(entryPath) else {
                throw DictionaryImportError.invalidData
            }
            entry = resolvedEntry
        } catch let error as DictionaryImportError {
            throw error
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }

        let tempURL: URL
        if let scratchSpace {
            do {
                tempURL = try scratchSpace.makeUniqueFileURL(pathExtension: "json")
            } catch {
                throw DictionaryImportError.unzipFailed(underlyingError: error)
            }
        } else {
            tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        }
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await archive.extract(entry, to: tempURL, skipCRC32: skipCRC32)
            return try await body(tempURL)
        } catch let error as DictionaryImportError {
            throw error
        } catch {
            throw DictionaryImportError.unzipFailed(underlyingError: error)
        }
    }
}
