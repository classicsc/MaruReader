//
//  TermBankIterator.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation

/// Helper class for streaming JSON array parsing
private class JSONStreamDecoder {
    private let data: Data
    private var currentOffset: Int = 0
    private var isFirstElement = true
    private var arrayStarted = false

    init(data: Data) {
        self.data = data
    }

    func nextArrayElement() -> Data? {
        // Skip whitespace and find array start if needed
        if !arrayStarted {
            skipWhitespace()
            guard currentOffset < data.count,
                  data[currentOffset] == UInt8(ascii: "[") else { return nil }
            currentOffset += 1
            arrayStarted = true
        }

        skipWhitespace()

        // Check for array end
        if currentOffset < data.count, data[currentOffset] == UInt8(ascii: "]") {
            return nil
        }

        // Skip comma if not first element
        if !isFirstElement {
            guard currentOffset < data.count,
                  data[currentOffset] == UInt8(ascii: ",") else { return nil }
            currentOffset += 1
            skipWhitespace()
        }
        isFirstElement = false

        // Find the end of this element
        let elementStart = currentOffset
        var depth = 0
        var inString = false
        var escaped = false

        while currentOffset < data.count {
            let byte = data[currentOffset]

            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
            } else {
                switch byte {
                case UInt8(ascii: "\""):
                    inString = true
                case UInt8(ascii: "["), UInt8(ascii: "{"):
                    depth += 1
                case UInt8(ascii: "]"), UInt8(ascii: "}"):
                    depth -= 1
                case UInt8(ascii: ","):
                    if depth == 0 {
                        let elementData = data.subdata(in: elementStart ..< currentOffset)
                        return elementData
                    }
                default:
                    break
                }

                // Check for array end
                if depth == -1 {
                    if elementStart < currentOffset {
                        let elementData = data.subdata(in: elementStart ..< currentOffset)
                        return elementData
                    }
                    return nil
                }
            }

            currentOffset += 1
        }

        // Return remaining data if we hit the end
        if elementStart < currentOffset {
            return data.subdata(in: elementStart ..< currentOffset)
        }
        return nil
    }

    private func skipWhitespace() {
        while currentOffset < data.count {
            let byte = data[currentOffset]
            if byte != UInt8(ascii: " "),
               byte != UInt8(ascii: "\t"),
               byte != UInt8(ascii: "\n"),
               byte != UInt8(ascii: "\r")
            {
                break
            }
            currentOffset += 1
        }
    }
}

/// Iterates over the terms in the provided Term Bank JSON files.
struct TermBankIterator: AsyncSequence {
    private let termBankURLs: [URL]
    private let dataFormat: Int

    init(termBankURLs: [URL], dataFormat: Int) {
        self.termBankURLs = termBankURLs
        self.dataFormat = dataFormat
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(termBankURLs: termBankURLs, dataFormat: dataFormat)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private let termBankURLs: [URL]
        private let dataFormat: Int

        private var currentFileIndex: Int = 0
        private var currentFileData: Data?
        private var currentDecoder: JSONDecoder?
        private var currentStream: JSONStreamDecoder?
        private var hasStartedCurrentFile: Bool = false
        private var parseError: Error?

        init(termBankURLs: [URL], dataFormat: Int) {
            self.termBankURLs = termBankURLs
            self.dataFormat = dataFormat
        }

        mutating func next() async throws -> ParsedTerm? {
            // If we've had a parsing error, throw it
            if let error = parseError {
                throw error
            }

            while currentFileIndex < termBankURLs.count {
                if !hasStartedCurrentFile {
                    // Load the next file
                    do {
                        currentFileData = try Data(contentsOf: termBankURLs[currentFileIndex])
                        currentDecoder = JSONDecoder()
                        currentStream = JSONStreamDecoder(data: currentFileData!)
                        hasStartedCurrentFile = true
                    } catch {
                        parseError = DictionaryImportError.invalidData
                        throw parseError!
                    }
                }

                // Try to get the next term from the current file
                do {
                    if let nextTerm = try getNextTermFromCurrentFile() {
                        return nextTerm
                    } else {
                        // Move to the next file
                        currentFileIndex += 1
                        hasStartedCurrentFile = false
                        currentFileData = nil
                        currentDecoder = nil
                        currentStream = nil
                    }
                } catch {
                    parseError = error
                    throw error
                }
            }

            return nil
        }

        private mutating func getNextTermFromCurrentFile() throws -> ParsedTerm? {
            guard let stream = currentStream,
                  let decoder = currentDecoder else { return nil }

            if let entryData = stream.nextArrayElement() {
                switch dataFormat {
                case 1:
                    let entry = try decoder.decode(TermBankV1Entry.self, from: entryData)
                    return ParsedTerm(from: entry)
                case 3:
                    let entry = try decoder.decode(TermBankV3Entry.self, from: entryData)
                    return ParsedTerm(from: entry)
                default:
                    throw DictionaryImportError.unsupportedFormat
                }
            } else {
                return nil
            }
        }
    }
}
