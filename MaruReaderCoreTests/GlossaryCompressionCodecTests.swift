// GlossaryCompressionCodecTests.swift
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

import Foundation
@testable import MaruReaderCore
import Testing

private let runtimeMagic = Data("MRG5".utf8)
private let plainZSTDMagic = Data("MRG2".utf8)
private let uncompressedMagic = Data("MRG0".utf8)

private final class ConcurrencyTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var maxActive = 0

    func start() {
        lock.lock()
        active += 1
        maxActive = max(maxActive, active)
        lock.unlock()
    }

    func stop() {
        lock.lock()
        active -= 1
        lock.unlock()
    }

    func maximumActive() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return maxActive
    }
}

struct GlossaryCompressionCodecTests {
    @Test func defaultImportVersion_usesRuntimeZSTDDictionaryCodec() {
        #expect(GlossaryCompressionCodec.defaultImportVersion == .zstdRuntimeV1)
    }

    @Test func encodeDecodeGlossaryJSON_uncompressedV1_roundTrip_returnsOriginalJSON() throws {
        let jsonData = Data(#"["to eat",{"type":"text","text":"Detailed definition"}]"#.utf8)

        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .uncompressedV1,
            dictionaryID: nil
        )
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(encoded, dictionaryID: nil)

        #expect(decoded == jsonData)
        #expect(encoded.starts(with: uncompressedMagic))
    }

    @Test func encodeDecodeGlossaryJSON_lzfseV1_roundTrip_returnsOriginalJSON() throws {
        let jsonData = Data(#"["to eat",{"type":"text","text":"Detailed definition"}]"#.utf8)

        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .lzfseV1,
            dictionaryID: nil
        )
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(encoded, dictionaryID: nil)

        #expect(decoded == jsonData)
    }

    @Test func encodeDecodeGlossaryJSON_zstdV1_roundTrip_returnsOriginalJSON() throws {
        let jsonData = Data(#"["to eat",{"type":"text","text":"Detailed definition"}]"#.utf8)

        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdV1,
            dictionaryID: nil
        )
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(encoded, dictionaryID: nil)

        #expect(decoded == jsonData)
        #expect(encoded.starts(with: plainZSTDMagic))
    }

    @Test func encodeDecodeGlossaryJSON_defaultVersion_roundTrip_returnsOriginalJSON() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }
        let dictionaryID = UUID()
        let identifier = GlossaryCompressionCodec.runtimeZSTDDictionaryIdentifier(for: dictionaryID)
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)

        let jsonData = Data(#"["to eat",{"type":"text","text":"Detailed definition"}]"#.utf8)
        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(
            encoded,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        #expect(decoded == jsonData)
        #expect(encoded.starts(with: runtimeMagic))

        let compressedPayload = Data(encoded.dropFirst(runtimeMagic.count))
        let legacyPayload = makeLegacyRuntimePayload(contents: compressedPayload, dictionaryIdentifier: identifier)
        #expect(legacyPayload.count - encoded.count == 38)
    }

    @Test func encodeGlossaryJSON_runtimeMissingDictionary_throws() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let jsonData = Data(#"["to eat"]"#.utf8)

        #expect(throws: Error.self) {
            try GlossaryCompressionCodec.encodeGlossaryJSON(
                jsonData,
                using: .zstdRuntimeV1,
                dictionaryID: UUID(),
                searchBaseDirectory: baseDirectory
            )
        }
    }

    @Test func encodeGlossaryJSON_runtimeMissingDictionaryID_throws() {
        let jsonData = Data(#"["to eat"]"#.utf8)

        #expect(throws: Error.self) {
            try GlossaryCompressionCodec.encodeGlossaryJSON(
                jsonData,
                using: .zstdRuntimeV1,
                dictionaryID: nil
            )
        }
    }

    @Test func decodeDefinitions_roundTrip_returnsDefinitions() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let definitions: [Definition] = [.text("to eat"), .text("to consume")]
        let jsonData = try JSONEncoder().encode(definitions)
        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        let decoded = GlossaryCompressionCodec.decodeDefinitions(
            from: encoded,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        #expect(decoded?.count == 2)
        if case let .text(firstDefinition) = decoded?[0] {
            #expect(firstDefinition == "to eat")
        } else {
            Issue.record("Expected first definition to be .text")
        }
    }

    @Test func decodeGlossaryJSON_corruptedPayload_returnsNil() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let jsonData = Data(#"["to eat"]"#.utf8)
        var encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )
        #expect(encoded.count > runtimeMagic.count + 8)

        let corruptionIndex = runtimeMagic.count + 8
        encoded[corruptionIndex] ^= 0xFF
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(
            encoded,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        #expect(decoded == nil)
    }

    @Test func decodeGlossaryJSON_runtimeMissingDictionaryID_returnsNil() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let jsonData = Data(#"["to eat"]"#.utf8)
        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(
            encoded,
            dictionaryID: nil,
            searchBaseDirectory: baseDirectory
        )

        #expect(decoded == nil)
    }

    @Test func decodeGlossaryJSON_runtimeDictionaryReload_roundTripsAfterCacheReset() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let jsonData = Data(#"["to eat",{"type":"text","text":"Runtime dictionary round trip"}]"#.utf8)
        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        GlossaryCompressionCodec.resetCachesForTesting()
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(
            encoded,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        #expect(decoded == jsonData)
    }

    @Test func evictRuntimeZSTDDictionary_removesCachedDictionaryAndProcessorEntries() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer {
            GlossaryCompressionCodec.resetCachesForTesting()
            cleanupTemporaryDirectory(baseDirectory)
        }

        GlossaryCompressionCodec.resetCachesForTesting()

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let jsonData = Data(#"["to eat",{"type":"text","text":"Eviction coverage"}]"#.utf8)
        let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )

        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(
            encoded,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )
        #expect(decoded == jsonData)
        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().dictionaryData == 1)
        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().processorPools == 1)

        GlossaryCompressionCodec.evictRuntimeZSTDDictionary(dictionaryID: dictionaryID)

        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().dictionaryData == 0)
        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().processorPools == 0)
    }

    @Test func encodeGlossaryJSON_runtimeMixedCompressionLevels_useDistinctProcessorPools() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer {
            GlossaryCompressionCodec.resetCachesForTesting()
            cleanupTemporaryDirectory(baseDirectory)
        }

        GlossaryCompressionCodec.resetCachesForTesting()

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)
        let jsonData = Data(#"["to eat",{"type":"text","text":"Mixed compression level coverage"}]"#.utf8)

        let defaultEncoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory
        )
        let maximumEncoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
            jsonData,
            using: .zstdRuntimeV1,
            dictionaryID: dictionaryID,
            searchBaseDirectory: baseDirectory,
            zstdCompressionLevel: GlossaryCompressionCodec.maximumZSTDCompressionLevel
        )

        #expect(
            GlossaryCompressionCodec.decodeGlossaryJSON(
                defaultEncoded,
                dictionaryID: dictionaryID,
                searchBaseDirectory: baseDirectory
            ) == jsonData
        )
        #expect(
            GlossaryCompressionCodec.decodeGlossaryJSON(
                maximumEncoded,
                dictionaryID: dictionaryID,
                searchBaseDirectory: baseDirectory
            ) == jsonData
        )
        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().dictionaryData == 1)
        #expect(GlossaryCompressionCodec.cacheEntryCountsForTesting().processorPools == 2)
    }

    @Test func reusableZSTDProcessorPool_borrowsProcessorsInParallelUpToConfiguredLimit() {
        let pool = ReusableZSTDProcessorPool<Int>(maximumRetainedProcessors: 4) { 1 }
        let tracker = ConcurrencyTracker()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let group = DispatchGroup()

        for _ in 0 ..< 4 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }

                try? pool.withProcessor { _ in
                    tracker.start()
                    entered.signal()
                    release.wait()
                    tracker.stop()
                }
            }
        }

        for _ in 0 ..< 4 {
            entered.wait()
        }

        #expect(tracker.maximumActive() == 4)

        for _ in 0 ..< 4 {
            release.signal()
        }

        group.wait()
    }

    @Test func encodeAndDecodeGlossaryJSON_concurrentMixedWorkloads_roundTrip() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let dictionaryID = UUID()
        try writeRuntimeDictionary(for: dictionaryID, in: baseDirectory)

        let results = try await withThrowingTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for index in 0 ..< 64 {
                group.addTask {
                    let definitions: [Definition] = [
                        .text("definition-\(index)"),
                        .text("alternate-\(index)"),
                    ]
                    let jsonData = try JSONEncoder().encode(definitions)
                    let encoded = try GlossaryCompressionCodec.encodeGlossaryJSON(
                        jsonData,
                        using: .zstdRuntimeV1,
                        dictionaryID: dictionaryID,
                        searchBaseDirectory: baseDirectory
                    )

                    guard let decodedJSON = GlossaryCompressionCodec.decodeGlossaryJSON(
                        encoded,
                        dictionaryID: dictionaryID,
                        searchBaseDirectory: baseDirectory
                    ),
                        decodedJSON == jsonData,
                        let decodedDefinitions = GlossaryCompressionCodec.decodeDefinitions(
                            from: encoded,
                            dictionaryID: dictionaryID,
                            searchBaseDirectory: baseDirectory
                        ),
                        let reencodedDefinitions = try? JSONEncoder().encode(decodedDefinitions)
                    else {
                        return false
                    }

                    return reencodedDefinitions == jsonData
                }
            }

            var results: [Bool] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // swiftformat:disable:next:preferKeyPath
        #expect(results.allSatisfy { $0 })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        return baseDirectory
    }

    private func makeLegacyRuntimePayload(contents: Data, dictionaryIdentifier: String) -> Data {
        let identifierData = Data(dictionaryIdentifier.utf8)
        let identifierLength = UInt16(identifierData.count)
        var payload = Data()
        payload.append(runtimeMagic)
        payload.append(UInt8((identifierLength >> 8) & 0xFF))
        payload.append(UInt8(identifierLength & 0xFF))
        payload.append(identifierData)
        payload.append(contents)
        return payload
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func writeRuntimeDictionary(for dictionaryID: UUID, in baseDirectory: URL) throws {
        let dictionaryURL = GlossaryCompressionCodec.zstdDictionaryURL(dictionaryID: dictionaryID, in: baseDirectory)
        let trainingSamples = (0 ..< 512).map { index in
            Data(
                """
                ["term-\(index)",{"type":"text","text":"\(String(repeating: "structured-definition-\(index)-", count: 8))"}]
                """.utf8
            )
        }
        let dictionaryData = try GlossaryCompressionCodec.buildZSTDDictionary(fromSamples: trainingSamples)

        try FileManager.default.createDirectory(
            at: dictionaryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try dictionaryData.write(to: dictionaryURL, options: .atomic)
    }
}
