//
//  StreamingBankIterator.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
internal import JsonStream
import os.log

/// A generic streaming iterator for dictionary bank JSON files.
/// Uses JsonStream to parse JSON without loading entire files into memory.
struct StreamingBankIterator<Entry: DictionaryDataBankEntry>: AsyncSequence {
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
        private var decoder = JSONDecoder()
        private var isInArray = false
        private var arrayDepth = 0
        private var objectDepth = 0
        private var tokenBuffer: [JsonToken] = []
        private var isCollectingElement = false

        private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "StreamingBankAsyncIterator")

        init(bankURLs: [URL]) {
            self.bankURLs = bankURLs
        }

        mutating func next() async throws -> Entry? {
            while currentFileIndex < bankURLs.count {
                // Initialize stream for new file if needed
                if currentInputStream == nil {
                    do {
                        currentInputStream = try JsonInputStream(filePath: bankURLs[currentFileIndex].path)
                        isInArray = false
                        arrayDepth = 0
                        objectDepth = 0
                        tokenBuffer.removeAll()
                        isCollectingElement = false
                    } catch {
                        throw DictionaryImportError.invalidData
                    }
                }

                // Try to get next entry from current file
                if let entry = try getNextEntry() {
                    return entry
                } else {
                    // Move to next file
                    currentFileIndex += 1
                    currentInputStream = nil
                }
            }

            return nil
        }

        private mutating func getNextEntry() throws -> Entry? {
            guard let stream = currentInputStream else { return nil }

            while let token = try stream.read() {
                switch token {
                case let .startArray(key) where key == nil && arrayDepth == 0:
                    // This is the root array
                    isInArray = true
                    arrayDepth = 1

                case .startArray(_) where isInArray:
                    // Start of an array element (entries are arrays in both V1 and V3)
                    if arrayDepth == 1, objectDepth == 0 {
                        isCollectingElement = true
                        tokenBuffer.removeAll()
                    }
                    if isCollectingElement {
                        tokenBuffer.append(token)
                        arrayDepth += 1
                    }

                case .endArray(_) where isInArray:
                    if isCollectingElement {
                        tokenBuffer.append(token)
                        arrayDepth -= 1

                        // Check if we finished collecting an element
                        if arrayDepth == 1, objectDepth == 0 {
                            isCollectingElement = false

                            // Convert tokens back to JSON and decode
                            do {
                                let jsonData = try tokensToJSON(tokenBuffer)
                                let entry = try decoder.decode(Entry.self, from: jsonData)
                                tokenBuffer.removeAll()
                                return entry
                            } catch {
                                let currentArrayDepth = arrayDepth
                                let currentObjectDepth = objectDepth
                                let bufferCount = tokenBuffer.count
                                let fileName = bankURLs[currentFileIndex].lastPathComponent
                                logger.error("Decoding failed for entry in file \(fileName): \(error.localizedDescription)")
                                logger.debug("Current arrayDepth: \(currentArrayDepth), objectDepth: \(currentObjectDepth), tokenBuffer count: \(bufferCount)")
                                throw DictionaryImportError.invalidData
                            }
                        }
                    } else if arrayDepth == 1 {
                        // End of root array
                        return nil
                    }

                case .startObject(_) where isInArray && arrayDepth == 1 && objectDepth == 0:
                    // Object at top level of array - this is invalid for term/kanji banks
                    throw DictionaryImportError.invalidData

                case .startObject(_) where isCollectingElement:
                    tokenBuffer.append(token)
                    objectDepth += 1

                case .endObject(_) where isCollectingElement:
                    tokenBuffer.append(token)
                    objectDepth -= 1

                case .string(_, _), .number(_, _), .bool(_, _), .null:
                    if isCollectingElement {
                        tokenBuffer.append(token)
                    }

                default:
                    if isCollectingElement {
                        tokenBuffer.append(token)
                    }
                }
            }

            return nil
        }

        private func tokensToJSON(_ tokens: [JsonToken]) throws -> Data {
            var json = ""
            var containerStack: [ContainerType] = []

            for token in tokens {
                switch token {
                case let .startObject(key):
                    // Add key if we're in an object
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    json.append("{")
                    containerStack.append(.object)
                case .endObject:
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("}")
                    _ = containerStack.popLast()
                    // Add comma if we're inside another container
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case let .startArray(key):
                    // Add key if we're in an object
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    json.append("[")
                    containerStack.append(.array)
                case .endArray:
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("]")
                    _ = containerStack.popLast()
                    // Add comma if we're inside another container
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case let .string(key, value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    json.append("\"\(escapeString(value))\",")
                case let .number(key, value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    switch value {
                    case let .int(n):
                        json.append("\(n),")
                    case let .double(d):
                        json.append("\(d),")
                    case let .decimal(dec):
                        json.append("\(dec),")
                    }
                case let .bool(key, value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    json.append("\(value),")
                case let .null(key):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyDescription(key)))\":")
                    }
                    json.append("null,")
                }
            }

            // Remove trailing comma if present
            if json.last == "," {
                json.removeLast()
            }

            guard let data = json.data(using: .utf8) else {
                throw DictionaryImportError.invalidData
            }

            return data
        }

        private func keyDescription(_ key: JsonKey) -> String {
            switch key {
            case let .name(name):
                name
            case .index:
                ""
            }
        }

        private func escapeString(_ str: String) -> String {
            var result = ""
            for scalar in str.unicodeScalars {
                switch scalar {
                case "\\": result += "\\\\"
                case "\"": result += "\\\""
                case "\n": result += "\\n"
                case "\r": result += "\\r"
                case "\t": result += "\\t"
                case "\u{08}": result += "\\b" // backspace
                case "\u{0C}": result += "\\f" // form feed
                case "\u{00}" ... "\u{1F}":
                    // Other control characters - use unicode escape
                    let hex = String(scalar.value, radix: 16)
                    result += "\\u" + hex.padding(toLength: 4, withPad: "0", startingAt: 0)
                default:
                    result.append(Character(scalar))
                }
            }
            return result
        }
    }
}

enum ContainerType {
    case array
    case object
}
