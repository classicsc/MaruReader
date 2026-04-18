// ImportScratchSpace.swift
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

enum ImportScratchKind {
    case dictionary
    case audio
    case tokenizer

    fileprivate var prefix: String {
        switch self {
        case .dictionary:
            "MaruDictionaryImport"
        case .audio:
            "MaruAudioImport"
        case .tokenizer:
            "MaruTokenizerImport"
        }
    }
}

struct ImportScratchSpace {
    let kind: ImportScratchKind
    let jobUUID: UUID
    private let fileManager: FileManager

    init(kind: ImportScratchKind, jobUUID: UUID, fileManager: FileManager = .default) {
        self.kind = kind
        self.jobUUID = jobUUID
        self.fileManager = fileManager
    }

    var rootURL: URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("\(kind.prefix)-\(jobUUID.uuidString)", isDirectory: true)
    }

    func ensureExists() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func makeUniqueFileURL(pathExtension: String? = nil) throws -> URL {
        try ensureExists()

        var fileURL = rootURL.appendingPathComponent(UUID().uuidString)
        if let pathExtension, !pathExtension.isEmpty {
            fileURL.appendPathExtension(pathExtension)
        }
        return fileURL
    }

    func cleanupBestEffort() {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        try? fileManager.removeItem(at: rootURL)
    }
}

private actor ArchiveDataAccumulator {
    private var data = Data()

    func append(_ chunk: Data) {
        data.append(chunk)
    }

    func result() -> Data {
        data
    }
}

extension Archive {
    func extractData(
        _ entry: Entry,
        bufferSize: Int? = nil,
        skipCRC32: Bool = false,
        progress: Progress? = nil
    ) async throws -> Data {
        let accumulator = ArchiveDataAccumulator()
        _ = try await extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32, progress: progress) { chunk in
            await accumulator.append(chunk)
        }
        return await accumulator.result()
    }
}
