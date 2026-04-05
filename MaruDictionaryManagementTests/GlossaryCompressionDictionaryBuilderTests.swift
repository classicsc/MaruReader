// GlossaryCompressionDictionaryBuilderTests.swift
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
@testable import MaruDictionaryManagement
import MaruReaderCore
import Testing

private let minimumTrainableCorpusBytes = 32 * 1024

struct GlossaryCompressionDictionaryBuilderTests {
    @Test func windowedGlossaryJSONSamples_runtimeProfile_samplesExpectedWindow() async throws {
        let zipURL = try await makeMockDictionaryArchive(entryCount: 128, glossaryRepeatCount: 24)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let samples = try await GlossaryCompressionDictionaryBuilder.windowedGlossaryJSONSamples(
            fromArchive: zipURL,
            format: .v3,
            termBankPaths: ["term_bank_1.json"],
            targetTrainingCorpusBytes: GlossaryCompressionTrainingProfile.runtime.targetTrainingCorpusBytes,
            windowStride: GlossaryCompressionTrainingProfile.runtime.windowStride,
            windowLength: GlossaryCompressionTrainingProfile.runtime.windowLength
        )

        #expect(samples.sampleCount == 32)
        #expect(samples.samples.count == 32)
        #expect(samples.totalSampleBytes > 0)
    }

    @Test func sampledTrainingCorpus_doesNotPadWhenSourceCorpusRunsOut() async throws {
        let zipURL = try await makeMockDictionaryArchive(entryCount: 128, glossaryRepeatCount: 24)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let runtimeCorpus = try await GlossaryCompressionDictionaryBuilder.sampledTrainingCorpus(
            fromArchives: [zipURL],
            profile: .runtime
        )
        let starterCorpus = try await GlossaryCompressionDictionaryBuilder.sampledTrainingCorpus(
            fromArchives: [zipURL],
            profile: .starterdict
        )

        #expect(runtimeCorpus.totalSampleBytes > 0)
        #expect(runtimeCorpus.totalSampleBytes < GlossaryCompressionTrainingProfile.runtime.targetTrainingCorpusBytes)
        #expect(starterCorpus.totalSampleBytes < GlossaryCompressionTrainingProfile.starterdict.targetTrainingCorpusBytes)
        #expect(starterCorpus.totalSampleBytes == runtimeCorpus.totalSampleBytes)
        #expect(starterCorpus.sampleCount == runtimeCorpus.sampleCount)
    }

    @Test func sampledTrainingCorpus_profilesDivergeWhenAdditionalArchivesProvideRealData() async throws {
        let firstArchive = try await makeMockDictionaryArchive(entryCount: 4096, glossaryRepeatCount: 256)
        let secondArchive = try await makeMockDictionaryArchive(entryCount: 4096, glossaryRepeatCount: 256)
        defer { try? FileManager.default.removeItem(at: firstArchive.deletingLastPathComponent()) }
        defer { try? FileManager.default.removeItem(at: secondArchive.deletingLastPathComponent()) }

        let runtimeCorpus = try await GlossaryCompressionDictionaryBuilder.sampledTrainingCorpus(
            fromArchives: [firstArchive, secondArchive],
            profile: .runtime
        )
        let starterCorpus = try await GlossaryCompressionDictionaryBuilder.sampledTrainingCorpus(
            fromArchives: [firstArchive, secondArchive],
            profile: .starterdict
        )

        #expect(runtimeCorpus.totalSampleBytes > 0)
        #expect(starterCorpus.totalSampleBytes > runtimeCorpus.totalSampleBytes)
        #expect(starterCorpus.sampleCount > runtimeCorpus.sampleCount)
    }

    @Test func buildRuntimeImportZSTDDictionary_smallCorpusThrowsInsufficientTrainingCorpus() async throws {
        let zipURL = try await makeMockDictionaryArchive(
            entryCount: 4096,
            glossaryRepeatCount: 1,
            glossaryText: "x"
        )
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        do {
            _ = try await GlossaryCompressionDictionaryBuilder.buildRuntimeImportZSTDDictionary(
                named: "tiny",
                fromArchive: zipURL,
                format: .v3,
                termBankPaths: ["term_bank_1.json"]
            )
            Issue.record("Expected insufficient training corpus error")
        } catch let error as GlossaryCompressionDictionaryBuildError {
            switch error {
            case let .insufficientTrainingCorpus(sampleCount, totalSampleBytes):
                #expect(sampleCount == 512)
                #expect(totalSampleBytes < minimumTrainableCorpusBytes)
            default:
                Issue.record("Expected insufficientTrainingCorpus, got \(String(describing: error))")
            }
        }
    }

    @Test func buildRuntimeImportZSTDDictionary_largeCorpusBuildsWithoutPadding() async throws {
        let zipURL = try await makeMockDictionaryArchive(entryCount: 512, glossaryRepeatCount: 64)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let result = try await GlossaryCompressionDictionaryBuilder.buildRuntimeImportZSTDDictionary(
            named: "large",
            fromArchive: zipURL,
            format: .v3,
            termBankPaths: ["term_bank_1.json"]
        )

        #expect(!result.dictionary.data.isEmpty)
        #expect(result.sampleCount == 64)
        #expect(result.totalSampleBytes >= minimumTrainableCorpusBytes)
        #expect(result.totalSampleBytes < GlossaryCompressionTrainingProfile.runtime.targetTrainingCorpusBytes)
    }

    private func makeMockDictionaryArchive(
        entryCount: Int,
        glossaryRepeatCount: Int,
        glossaryText: String? = nil
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let indexJSON = """
        {
            "title": "BuilderTest",
            "revision": "1.0",
            "format": 3
        }
        """
        try Data(indexJSON.utf8).write(to: contentsDir.appendingPathComponent("index.json"))

        let termRows = (0 ..< entryCount).map { index in
            let glossarySeed = glossaryText ?? "structured-definition-\(index)-"
            let glossary = String(repeating: glossarySeed, count: glossaryRepeatCount)
            return #"["単語\#(index)","たんご\#(index)","","",\#(1000 - index),["\#(glossary)"],\#(index),""]"#
        }
        let termJSON = """
        [
        \(termRows.joined(separator: ",\n"))
        ]
        """
        try Data(termJSON.utf8).write(to: contentsDir.appendingPathComponent("term_bank_1.json"))

        let zipURL = tempDir.appendingPathComponent("mock.zip")
        try await createArchive(from: contentsDir, zipURL: zipURL)
        return zipURL
    }

    private func createArchive(from rootURL: URL, zipURL: URL) async throws {
        let archive = try await Archive(url: zipURL, accessMode: .create)
        let rootPath = rootURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath {
                continue
            }
            let relativePath = fileURL.path.replacingOccurrences(of: rootPrefix, with: "")
            try await archive.addEntry(with: relativePath, relativeTo: rootURL)
        }
    }
}
