// StreamingBankIterator.swift
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

internal import JsonStream
import Foundation
import MaruReaderCore
import os

/// A generic streaming iterator for dictionary bank JSON files.
/// Uses JsonStream to parse JSON without loading entire files into memory.
struct StreamingBankIterator<Entry: StreamingBankTokenDecodable>: AsyncSequence {
    typealias Element = Entry

    private let bankURLs: [URL]

    init(bankURLs: [URL]) {
        self.bankURLs = bankURLs
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bankURLs: bankURLs)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private let bankURLs: [URL]

        private var currentFileIndex: Int = 0
        private var currentInputStream: JsonInputStream?
        private var isInRootArray = false

        private let logger = Logger.maru(category: "StreamingBankAsyncIterator")

        init(bankURLs: [URL]) {
            self.bankURLs = bankURLs
        }

        mutating func next() async throws -> Entry? {
            while currentFileIndex < bankURLs.count {
                // Initialize stream for new file if needed
                if currentInputStream == nil {
                    do {
                        currentInputStream = try JsonInputStream(filePath: bankURLs[currentFileIndex].path)
                        isInRootArray = false
                    } catch {
                        throw DictionaryImportError.invalidData
                    }
                }

                // Try to get next entry from current file
                do {
                    if let entry = try getNextEntry() {
                        return entry
                    } else {
                        // Move to next file
                        currentFileIndex += 1
                        currentInputStream = nil
                    }
                } catch {
                    let fileName = bankURLs[currentFileIndex].lastPathComponent
                    logger.error("Streaming decode failed for \(fileName): \(error.localizedDescription)")
                    throw DictionaryImportError.invalidData
                }
            }

            return nil
        }

        private mutating func getNextEntry() throws -> Entry? {
            guard let stream = currentInputStream else { return nil }

            while let token = try stream.read() {
                switch token {
                case .startArray(nil) where !isInRootArray:
                    isInRootArray = true

                case .endArray(nil) where isInRootArray:
                    return nil

                case .startArray(_) where isInRootArray:
                    return try Entry.decodeStreaming(from: stream, firstToken: token)

                case .startObject(_) where isInRootArray,
                     .string(_, _) where isInRootArray,
                     .number(_, _) where isInRootArray,
                     .bool(_, _) where isInRootArray,
                     .null where isInRootArray:
                    throw DictionaryImportError.invalidData

                default:
                    throw DictionaryImportError.invalidData
                }
            }

            throw DictionaryImportError.invalidData
        }
    }
}
