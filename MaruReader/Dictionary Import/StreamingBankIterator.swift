//
//  StreamingBankIterator.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
import JsonStream

/// A generic streaming iterator for dictionary bank JSON files.
/// Uses JsonStream to parse JSON without loading entire files into memory.
struct StreamingBankIterator<Entry: Decodable>: AsyncSequence {
    typealias Element = Entry

    private let bankURLs: [URL]
    private let dataFormat: Int

    init(bankURLs: [URL], dataFormat: Int) {
        self.bankURLs = bankURLs
        self.dataFormat = dataFormat
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bankURLs: bankURLs, dataFormat: dataFormat)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private let bankURLs: [URL]
        private let dataFormat: Int

        private var currentFileIndex: Int = 0
        private var currentInputStream: JsonInputStream?
        private var decoder = JSONDecoder()
        private var isInArray = false
        private var arrayDepth = 0
        private var objectDepth = 0
        private var tokenBuffer: [JsonToken] = []
        private var isCollectingElement = false

        init(bankURLs: [URL], dataFormat: Int) {
            self.bankURLs = bankURLs
            self.dataFormat = dataFormat
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
                case .startArray(let key) where key == nil && arrayDepth == 0:
                    // This is the root array
                    isInArray = true
                    arrayDepth = 1

                case .startArray(_) where isInArray:
                    // Start of an array element (entries are arrays in both V1 and V3)
                    if arrayDepth == 1 && objectDepth == 0 {
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
                        if arrayDepth == 1 && objectDepth == 0 {
                            isCollectingElement = false

                            // Convert tokens back to JSON and decode
                            let jsonData = try tokensToJSON(tokenBuffer)
                            let entry = try decoder.decode(Entry.self, from: jsonData)
                            tokenBuffer.removeAll()
                            return entry
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

                case .string(_, _), .number(_, _), .bool(_, _), .null(_):
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
                case .startObject(_):
                    json.append("{")
                    containerStack.append(.object)
                case .endObject(_):
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("}")
                    _ = containerStack.popLast()
                    // Add comma if we're inside another container
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case .startArray(_):
                    json.append("[")
                    containerStack.append(.array)
                case .endArray(_):
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("]")
                    _ = containerStack.popLast()
                    // Add comma if we're inside another container
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case .string(let key, let value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key = key {
                        json.append("\"\(keyDescription(key))\":")
                    }
                    json.append("\"\(escapeString(value))\",")
                case .number(let key, let value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key = key {
                        json.append("\"\(keyDescription(key))\":")
                    }
                    switch value {
                    case .int(let n):
                        json.append("\(n),")
                    case .double(let d):
                        json.append("\(d),")
                    case .decimal(let dec):
                        json.append("\(dec),")
                    }
                case .bool(let key, let value):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key = key {
                        json.append("\"\(keyDescription(key))\":")
                    }
                    json.append("\(value),")
                case .null(let key):
                    // Only add key if we're in an object, not an array
                    if case .object = containerStack.last, let key = key {
                        json.append("\"\(keyDescription(key))\":")
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
            case .name(let name):
                return name
            case .index(_):
                return ""
            }
        }

        private func escapeString(_ str: String) -> String {
            return str
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
        }
    }
}

enum ContainerType {
    case array
    case object
}
