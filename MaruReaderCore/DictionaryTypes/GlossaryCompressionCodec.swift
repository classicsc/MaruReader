// GlossaryCompressionCodec.swift
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

internal import LRUCache
internal import SwiftZSTD
import Foundation

public struct GlossaryCompressionZSTDDictionary: Sendable, Equatable {
    public let identifier: String
    public let data: Data

    public init(identifier: String, data: Data) {
        self.identifier = identifier
        self.data = data
    }
}

public enum GlossaryCompressionCodecVersion: String, Sendable, Equatable, CaseIterable {
    case uncompressedV1 = "uncompressed-v1"
    case lzfseV1 = "lzfse-v1"
    case zstdV1 = "zstd-v1"
    case zstdRuntimeV1 = "zstd-runtime-v1"

    fileprivate var magic: Data {
        switch self {
        case .uncompressedV1:
            Data("MRG0".utf8)
        case .lzfseV1:
            Data("MRG1".utf8)
        case .zstdV1:
            Data("MRG2".utf8)
        case .zstdRuntimeV1:
            Data("MRG5".utf8)
        }
    }

    fileprivate var zstdCompressionLevel: Int32? {
        switch self {
        case .uncompressedV1, .lzfseV1:
            nil
        case .zstdV1, .zstdRuntimeV1:
            3
        }
    }
}

private enum GlossaryCompressionCodecError: Error, LocalizedError {
    case missingRuntimeZSTDDictionary(String)
    case missingRuntimeZSTDDictionaryID
    case lzfseCompressionFailed

    var errorDescription: String? {
        switch self {
        case let .missingRuntimeZSTDDictionary(identifier):
            "Missing glossary compression dictionary: \(identifier)"
        case .missingRuntimeZSTDDictionaryID:
            "Missing glossary compression dictionary ID"
        case .lzfseCompressionFailed:
            "Failed to encode glossary payload with LZFSE"
        }
    }
}

private let glossaryCompressionProcessorPoolWidth = max(
    1,
    min(ProcessInfo.processInfo.activeProcessorCount, 8)
)

private let glossaryCompressionDictionaryCacheCostLimit = 32_000_000
private let glossaryCompressionDictionaryCacheCountLimit = 16
private let glossaryCompressionProcessorCacheCountLimit = 16

private final class GlossaryCompressionZSTDDictionaryCache: @unchecked Sendable {
    private let cachedByIdentifier: LRUCache<String, Data>

    init(
        totalCostLimit: Int = glossaryCompressionDictionaryCacheCostLimit,
        countLimit: Int = glossaryCompressionDictionaryCacheCountLimit
    ) {
        cachedByIdentifier = LRUCache(
            totalCostLimit: totalCostLimit,
            countLimit: countLimit
        )
    }

    func data(for identifiers: [String]) -> Data? {
        for identifier in identifiers {
            if let dictionary = cachedByIdentifier.value(forKey: identifier) {
                return dictionary
            }
        }

        return nil
    }

    func cache(_ dictionary: Data, for identifiers: [String]) {
        for identifier in identifiers {
            cachedByIdentifier.setValue(dictionary, forKey: identifier, cost: dictionary.count)
        }
    }

    func remove(identifiers: [String]) {
        for identifier in identifiers {
            cachedByIdentifier.removeValue(forKey: identifier)
        }
    }

    func count() -> Int {
        cachedByIdentifier.count
    }

    func clear() {
        cachedByIdentifier.removeAll()
    }
}

final class ReusableZSTDProcessorPool<Processor>: @unchecked Sendable {
    typealias Factory = () throws -> Processor

    private let maximumRetainedProcessors: Int
    private let makeProcessor: Factory
    private let condition = NSCondition()
    private var availableProcessors: [Processor] = []
    private var createdProcessorCount = 0

    init(
        maximumRetainedProcessors: Int = glossaryCompressionProcessorPoolWidth,
        makeProcessor: @escaping Factory
    ) {
        self.maximumRetainedProcessors = max(1, maximumRetainedProcessors)
        self.makeProcessor = makeProcessor
    }

    func withProcessor<T>(_ operation: (Processor) throws -> T) throws -> T {
        let processor = try borrowProcessor()
        defer { returnProcessor(processor) }
        return try operation(processor)
    }

    private func borrowProcessor() throws -> Processor {
        while true {
            condition.lock()

            if let processor = availableProcessors.popLast() {
                condition.unlock()
                return processor
            }

            if createdProcessorCount < maximumRetainedProcessors {
                createdProcessorCount += 1
                condition.unlock()

                do {
                    return try makeProcessor()
                } catch {
                    condition.lock()
                    createdProcessorCount -= 1
                    condition.signal()
                    condition.unlock()
                    throw error
                }
            }

            condition.wait()
            condition.unlock()
        }
    }

    private func returnProcessor(_ processor: Processor) {
        condition.lock()
        availableProcessors.append(processor)
        condition.signal()
        condition.unlock()
    }
}

private final class DictionaryZSTDProcessorPool: @unchecked Sendable {
    private let compressionPool: ReusableZSTDProcessorPool<DictionaryZSTDProcessor>
    private let decompressionPool: ReusableZSTDProcessorPool<DictionaryZSTDProcessor>

    init(
        dictionaryData: Data,
        compressionLevel: Int32,
        maximumRetainedProcessors: Int = glossaryCompressionProcessorPoolWidth
    ) {
        let makeProcessor = {
            guard let processor = DictionaryZSTDProcessor(
                withDictionary: dictionaryData,
                andCompressionLevel: compressionLevel
            ) else {
                throw ZSTDError.invalidCompressionLevel(cl: compressionLevel)
            }

            return processor
        }

        compressionPool = ReusableZSTDProcessorPool(
            maximumRetainedProcessors: maximumRetainedProcessors,
            makeProcessor: makeProcessor
        )
        decompressionPool = ReusableZSTDProcessorPool(
            maximumRetainedProcessors: maximumRetainedProcessors,
            makeProcessor: makeProcessor
        )
    }

    func compress(_ data: Data) throws -> Data {
        try compressionPool.withProcessor { processor in
            try processor.compressBufferUsingDict(data)
        }
    }

    func decompress(_ data: Data) throws -> Data {
        try decompressionPool.withProcessor { processor in
            try processor.decompressFrameUsingDict(data)
        }
    }
}

private final class RawZSTDProcessorPool: @unchecked Sendable {
    private let compressionPool: ReusableZSTDProcessorPool<ZSTDProcessor>
    private let decompressionPool: ReusableZSTDProcessorPool<ZSTDProcessor>

    init(maximumRetainedProcessors: Int = glossaryCompressionProcessorPoolWidth) {
        compressionPool = ReusableZSTDProcessorPool(
            maximumRetainedProcessors: maximumRetainedProcessors
        ) {
            ZSTDProcessor(useContext: true)
        }
        decompressionPool = ReusableZSTDProcessorPool(
            maximumRetainedProcessors: maximumRetainedProcessors
        ) {
            ZSTDProcessor(useContext: true)
        }
    }

    func compress(_ data: Data, compressionLevel: Int32) throws -> Data {
        try compressionPool.withProcessor { processor in
            try processor.compressBuffer(data, compressionLevel: compressionLevel)
        }
    }

    func decompress(_ data: Data) throws -> Data {
        try decompressionPool.withProcessor { processor in
            try processor.decompressFrame(data)
        }
    }
}

private final class GlossaryCompressionZSTDProcessorCache: @unchecked Sendable {
    private let maximumRetainedProcessors: Int

    private let lock = NSLock()
    private var rawProcessorPool: RawZSTDProcessorPool
    private let dictionaryProcessorPools: LRUCache<String, DictionaryZSTDProcessorPool>

    init(
        maximumRetainedProcessors: Int = glossaryCompressionProcessorPoolWidth,
        countLimit: Int = glossaryCompressionProcessorCacheCountLimit
    ) {
        self.maximumRetainedProcessors = max(1, maximumRetainedProcessors)
        rawProcessorPool = RawZSTDProcessorPool(
            maximumRetainedProcessors: self.maximumRetainedProcessors
        )
        dictionaryProcessorPools = LRUCache(countLimit: countLimit)
    }

    func dictionaryProcessor(
        cacheKey: String,
        dictionaryData: Data,
        compressionLevel: Int32
    ) -> DictionaryZSTDProcessorPool {
        if let cachedProcessor = dictionaryProcessorPools.value(forKey: cacheKey) {
            return cachedProcessor
        }

        let processorPool = DictionaryZSTDProcessorPool(
            dictionaryData: dictionaryData,
            compressionLevel: compressionLevel,
            maximumRetainedProcessors: maximumRetainedProcessors
        )

        lock.lock()
        defer { lock.unlock() }

        if let cachedProcessor = dictionaryProcessorPools.value(forKey: cacheKey) {
            return cachedProcessor
        }

        dictionaryProcessorPools.setValue(processorPool, forKey: cacheKey)
        return processorPool
    }

    func removeDictionaryProcessor(cacheKey: String) {
        dictionaryProcessorPools.removeValue(forKey: cacheKey)
    }

    func count() -> Int {
        dictionaryProcessorPools.count
    }

    func clear() {
        lock.lock()
        rawProcessorPool = RawZSTDProcessorPool(
            maximumRetainedProcessors: maximumRetainedProcessors
        )
        dictionaryProcessorPools.removeAll()
        lock.unlock()
    }

    func compressRaw(_ data: Data, compressionLevel: Int32) throws -> Data {
        try rawProcessorPool.compress(data, compressionLevel: compressionLevel)
    }

    func decompressRaw(_ data: Data) throws -> Data {
        try rawProcessorPool.decompress(data)
    }
}

public enum GlossaryCompressionCodec {
    public static let defaultImportVersion: GlossaryCompressionCodecVersion = .zstdRuntimeV1
    public static let zstdDictionaryDirectoryName = "CompressionDictionaries"
    public static let zstdDictionaryFileExtension = "zdict"

    private static let dictionaryCache = GlossaryCompressionZSTDDictionaryCache()
    private static let processorCache = GlossaryCompressionZSTDProcessorCache()

    public static func buildZSTDDictionary(fromSamples samples: [Data]) throws -> Data {
        try buildDictionary(fromSamples: samples)
    }

    public static func runtimeZSTDDictionaryIdentifier(for dictionaryID: UUID) -> String {
        dictionaryID.uuidString.lowercased()
    }

    public static func zstdDictionaryURL(identifier: String, in baseDirectory: URL) -> URL {
        baseDirectory
            .appendingPathComponent(zstdDictionaryDirectoryName, isDirectory: true)
            .appendingPathComponent("\(identifier).\(zstdDictionaryFileExtension)")
    }

    public static func zstdDictionaryURL(dictionaryID: UUID, in baseDirectory: URL) -> URL {
        zstdDictionaryURL(
            identifier: runtimeZSTDDictionaryIdentifier(for: dictionaryID),
            in: baseDirectory
        )
    }

    public static func encodeGlossaryJSON(
        _ jsonData: Data,
        using version: GlossaryCompressionCodecVersion = defaultImportVersion,
        dictionaryID: UUID?,
        searchBaseDirectory: URL? = nil
    ) throws -> Data {
        switch version {
        case .uncompressedV1:
            return payload(magic: version.magic, contents: jsonData)
        case .lzfseV1:
            guard let compressed = try? (jsonData as NSData).compressed(using: .lzfse) as Data else {
                throw GlossaryCompressionCodecError.lzfseCompressionFailed
            }
            return payload(magic: version.magic, contents: compressed)
        case .zstdV1, .zstdRuntimeV1:
            let compressed = try compressZSTD(
                jsonData,
                using: version,
                dictionaryID: dictionaryID,
                searchBaseDirectory: searchBaseDirectory
            )
            return payload(magic: version.magic, contents: compressed)
        }
    }

    public static func decodeGlossaryJSON(
        _ payload: Data?,
        dictionaryID: UUID?,
        searchBaseDirectory: URL? = nil
    ) -> Data? {
        guard let payload, payload.count >= GlossaryCompressionCodecVersion.uncompressedV1.magic.count else {
            return nil
        }

        if payload.starts(with: GlossaryCompressionCodecVersion.uncompressedV1.magic) {
            return Data(payload.dropFirst(GlossaryCompressionCodecVersion.uncompressedV1.magic.count))
        }

        if payload.starts(with: GlossaryCompressionCodecVersion.lzfseV1.magic) {
            let compressedPayload = Data(payload.dropFirst(GlossaryCompressionCodecVersion.lzfseV1.magic.count))
            return try? (compressedPayload as NSData).decompressed(using: .lzfse) as Data
        }

        if payload.starts(with: GlossaryCompressionCodecVersion.zstdV1.magic) {
            return try? decodeRawZSTD(payload, using: .zstdV1)
        }

        if payload.starts(with: GlossaryCompressionCodecVersion.zstdRuntimeV1.magic) {
            return try? decodeRuntimeDictionaryZSTD(
                payload,
                using: .zstdRuntimeV1,
                dictionaryID: dictionaryID,
                searchBaseDirectory: searchBaseDirectory
            )
        }

        return nil
    }

    public static func decodeDefinitions(
        from payload: Data?,
        dictionaryID: UUID?,
        searchBaseDirectory: URL? = nil
    ) -> [Definition]? {
        guard let glossaryJSON = decodeGlossaryJSON(
            payload,
            dictionaryID: dictionaryID,
            searchBaseDirectory: searchBaseDirectory
        ) else {
            return nil
        }

        return try? JSONDecoder().decode([Definition].self, from: glossaryJSON)
    }

    static func resetCachesForTesting() {
        dictionaryCache.clear()
        processorCache.clear()
    }

    static func cacheEntryCountsForTesting() -> (dictionaryData: Int, processorPools: Int) {
        (
            dictionaryData: dictionaryCache.count(),
            processorPools: processorCache.count()
        )
    }

    public static func evictRuntimeZSTDDictionary(dictionaryID: UUID) {
        evictRuntimeZSTDDictionaries(
            identifiers: [runtimeZSTDDictionaryIdentifier(for: dictionaryID)]
        )
    }

    private static func compressZSTD(
        _ jsonData: Data,
        using version: GlossaryCompressionCodecVersion,
        dictionaryID: UUID?,
        searchBaseDirectory: URL? = nil
    ) throws -> Data {
        guard let compressionLevel = version.zstdCompressionLevel else {
            throw ZSTDError.invalidCompressionLevel(cl: 0)
        }

        switch version {
        case .zstdV1:
            return try processorCache.compressRaw(jsonData, compressionLevel: compressionLevel)
        case .zstdRuntimeV1:
            guard let dictionaryID else {
                throw GlossaryCompressionCodecError.missingRuntimeZSTDDictionaryID
            }

            let dictionaryIdentifier = runtimeZSTDDictionaryIdentifier(for: dictionaryID)

            guard let dictionaryData = resolveZSTDDictionary(
                identifiers: [dictionaryIdentifier],
                searchBaseDirectory: searchBaseDirectory
            ) else {
                throw GlossaryCompressionCodecError.missingRuntimeZSTDDictionary(dictionaryIdentifier)
            }

            return try processorCache.dictionaryProcessor(
                cacheKey: runtimeDictionaryCacheKey(version: version, identifier: dictionaryIdentifier),
                dictionaryData: dictionaryData,
                compressionLevel: compressionLevel
            ).compress(jsonData)
        case .uncompressedV1, .lzfseV1:
            break
        }

        preconditionFailure("Unexpected codec version without explicit dictionary requirements")
    }

    private static func decodeRawZSTD(
        _ payload: Data,
        using version: GlossaryCompressionCodecVersion
    ) throws -> Data {
        let compressedPayload = Data(payload.dropFirst(version.magic.count))
        return try processorCache.decompressRaw(compressedPayload)
    }

    private static func decodeRuntimeDictionaryZSTD(
        _ payload: Data,
        using version: GlossaryCompressionCodecVersion,
        dictionaryID: UUID?,
        searchBaseDirectory: URL? = nil
    ) throws -> Data {
        guard let dictionaryID else {
            throw GlossaryCompressionCodecError.missingRuntimeZSTDDictionaryID
        }

        let dictionaryIdentifier = runtimeZSTDDictionaryIdentifier(for: dictionaryID)
        guard let dictionaryData = resolveZSTDDictionary(
            identifiers: [dictionaryIdentifier],
            searchBaseDirectory: searchBaseDirectory
        )
        else {
            throw GlossaryCompressionCodecError.missingRuntimeZSTDDictionary(dictionaryIdentifier)
        }

        let compressedPayload = Data(payload.dropFirst(version.magic.count))
        return try processorCache.dictionaryProcessor(
            cacheKey: runtimeDictionaryCacheKey(version: version, identifier: dictionaryIdentifier),
            dictionaryData: dictionaryData,
            compressionLevel: version.zstdCompressionLevel ?? 1
        ).decompress(compressedPayload)
    }

    private static func payload(magic: Data, contents: Data) -> Data {
        var payload = Data()
        payload.reserveCapacity(magic.count + contents.count)
        payload.append(magic)
        payload.append(contents)
        return payload
    }

    private static func resolveZSTDDictionary(
        identifiers: [String],
        searchBaseDirectory: URL? = nil
    ) -> Data? {
        if let dictionary = dictionaryCache.data(for: identifiers) {
            return dictionary
        }

        for candidateURL in zstdDictionaryCandidateURLs(
            identifiers: identifiers,
            searchBaseDirectory: searchBaseDirectory
        ) {
            guard let dictionary = try? Data(contentsOf: candidateURL) else {
                continue
            }

            dictionaryCache.cache(dictionary, for: identifiers)
            return dictionary
        }

        return nil
    }

    private static func runtimeDictionaryCacheKey(
        version: GlossaryCompressionCodecVersion,
        identifier: String
    ) -> String {
        "\(version.rawValue):\(identifier)"
    }

    private static func evictRuntimeZSTDDictionaries(identifiers: [String]) {
        dictionaryCache.remove(identifiers: identifiers)

        for identifier in identifiers {
            processorCache.removeDictionaryProcessor(
                cacheKey: runtimeDictionaryCacheKey(
                    version: .zstdRuntimeV1,
                    identifier: identifier
                )
            )
        }
    }

    private static func zstdDictionaryCandidateURLs(
        identifiers: [String],
        searchBaseDirectory: URL? = nil
    ) -> [URL] {
        var candidateURLs: [URL] = []
        var seenPaths: Set<String> = []

        func appendCandidate(_ url: URL?) {
            guard let url else {
                return
            }

            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else {
                return
            }

            candidateURLs.append(url)
        }

        for identifier in identifiers {
            let filename = "\(identifier).\(zstdDictionaryFileExtension)"

            if let searchBaseDirectory {
                appendCandidate(
                    zstdDictionaryURL(identifier: identifier, in: searchBaseDirectory)
                )
            }

            if let baseDirectory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
            ) {
                appendCandidate(
                    zstdDictionaryURL(identifier: identifier, in: baseDirectory)
                )
            }

            if let starterDictionaryDirectory = Bundle.main.url(forResource: "StarterDictionary", withExtension: nil) {
                appendCandidate(
                    starterDictionaryDirectory
                        .appendingPathComponent(zstdDictionaryDirectoryName, isDirectory: true)
                        .appendingPathComponent(filename)
                )
            }
        }

        return candidateURLs
    }
}
