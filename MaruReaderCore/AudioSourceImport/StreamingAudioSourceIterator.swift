//
//  StreamingAudioSourceIterator.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import Foundation
internal import JsonStream
import os.log

/// A streaming iterator for audio source index JSON files.
///
/// Unlike dictionary banks which are arrays of arrays, audio source indices
/// are objects with nested dictionaries for headwords and files. This iterator
/// streams entries from either the "headwords" or "files" section without
/// loading the entire file into memory.
///
/// Usage:
/// ```swift
/// // Stream headword entries
/// let headwordIterator = StreamingAudioSourceHeadwordIterator(fileURL: indexURL)
/// for try await (expression, filenames) in headwordIterator {
///     // Process headword
/// }
///
/// // Stream file entries
/// let fileIterator = StreamingAudioSourceFileIterator(fileURL: indexURL)
/// for try await (filename, info) in fileIterator {
///     // Process file info
/// }
/// ```

// MARK: - Headword Iterator

/// Streams entries from the "headwords" section of an audio source index.
/// Each entry is a tuple of (expression, [filenames]).
struct StreamingAudioSourceHeadwordIterator: AsyncSequence {
    typealias Element = (expression: String, filenames: [String])

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(fileURL: fileURL)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private let fileURL: URL
        private var stream: JsonInputStream?
        private var isInitialized = false
        private var isInHeadwords = false
        private var objectDepth = 0
        private var decoder = JSONDecoder()

        private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "StreamingAudioSourceHeadwordIterator")

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        mutating func next() async throws -> Element? {
            if !isInitialized {
                do {
                    stream = try JsonInputStream(filePath: fileURL.path)
                    isInitialized = true
                } catch {
                    throw AudioSourceImportError.fileAccessDenied
                }
            }

            guard let stream else { return nil }

            while let token = try stream.read() {
                switch token {
                case let .startObject(key):
                    if case let .name(name) = key, name == "headwords", objectDepth == 1 {
                        isInHeadwords = true
                        objectDepth += 1
                    } else {
                        objectDepth += 1
                    }

                case .endObject:
                    objectDepth -= 1
                    if isInHeadwords, objectDepth == 1 {
                        // Exiting headwords section
                        return nil
                    }

                case let .startArray(key):
                    if isInHeadwords, objectDepth == 2, let key {
                        // This is a headword entry: key is the expression, value is array of filenames
                        let expression = keyName(key)
                        var filenames: [String] = []

                        // Read all strings in the array
                        while let arrayToken = try stream.read() {
                            switch arrayToken {
                            case let .string(_, value):
                                filenames.append(value)
                            case .endArray:
                                return (expression, filenames)
                            default:
                                continue
                            }
                        }
                    }

                default:
                    continue
                }
            }

            return nil
        }

        private func keyName(_ key: JsonKey) -> String {
            switch key {
            case let .name(name):
                name
            case .index:
                ""
            }
        }
    }
}

// MARK: - File Info Iterator

/// Streams entries from the "files" section of an audio source index.
/// Each entry is a tuple of (filename, AudioFileInfo).
struct StreamingAudioSourceFileIterator: AsyncSequence {
    typealias Element = (filename: String, info: AudioFileInfo)

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(fileURL: fileURL)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private let fileURL: URL
        private var stream: JsonInputStream?
        private var isInitialized = false
        private var isInFiles = false
        private var objectDepth = 0
        private var decoder = JSONDecoder()
        private var tokenBuffer: [JsonToken] = []
        private var isCollectingEntry = false
        private var currentFilename: String = ""

        private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "StreamingAudioSourceFileIterator")

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        mutating func next() async throws -> Element? {
            if !isInitialized {
                do {
                    stream = try JsonInputStream(filePath: fileURL.path)
                    isInitialized = true
                } catch {
                    throw AudioSourceImportError.fileAccessDenied
                }
            }

            guard let stream else { return nil }

            while let token = try stream.read() {
                switch token {
                case let .startObject(key):
                    if case let .name(name) = key, name == "files", objectDepth == 1 {
                        isInFiles = true
                        objectDepth += 1
                    } else if isInFiles, objectDepth == 2, let key {
                        // Starting a file info object
                        isCollectingEntry = true
                        currentFilename = keyName(key)
                        tokenBuffer.removeAll()
                        tokenBuffer.append(token)
                        objectDepth += 1
                    } else {
                        if isCollectingEntry {
                            tokenBuffer.append(token)
                        }
                        objectDepth += 1
                    }

                case .endObject:
                    objectDepth -= 1

                    if isCollectingEntry {
                        tokenBuffer.append(token)

                        if objectDepth == 2 {
                            // Finished collecting a file info entry
                            isCollectingEntry = false
                            let filename = currentFilename

                            do {
                                let jsonData = try tokensToJSON(tokenBuffer)
                                let info = try decoder.decode(AudioFileInfo.self, from: jsonData)
                                tokenBuffer.removeAll()
                                return (filename, info)
                            } catch {
                                logger.error("Failed to decode file info for \(filename): \(error.localizedDescription)")
                                throw AudioSourceImportError.invalidData
                            }
                        }
                    } else if isInFiles, objectDepth == 1 {
                        // Exiting files section
                        return nil
                    }

                default:
                    if isCollectingEntry {
                        tokenBuffer.append(token)
                    }
                }
            }

            return nil
        }

        private func keyName(_ key: JsonKey) -> String {
            switch key {
            case let .name(name):
                name
            case .index:
                ""
            }
        }

        private func tokensToJSON(_ tokens: [JsonToken]) throws -> Data {
            var json = ""
            var containerStack: [AudioJSONContainerType] = []

            for token in tokens {
                switch token {
                case let .startObject(key):
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
                    }
                    json.append("{")
                    containerStack.append(.object)
                case .endObject:
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("}")
                    _ = containerStack.popLast()
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case let .startArray(key):
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
                    }
                    json.append("[")
                    containerStack.append(.array)
                case .endArray:
                    if json.last == "," {
                        json.removeLast()
                    }
                    json.append("]")
                    _ = containerStack.popLast()
                    if !containerStack.isEmpty {
                        json.append(",")
                    }
                case let .string(key, value):
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
                    }
                    json.append("\"\(escapeString(value))\",")
                case let .number(key, value):
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
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
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
                    }
                    json.append("\(value),")
                case let .null(key):
                    if case .object = containerStack.last, let key {
                        json.append("\"\(escapeString(keyName(key)))\":")
                    }
                    json.append("null,")
                }
            }

            if json.last == "," {
                json.removeLast()
            }

            guard let data = json.data(using: .utf8) else {
                throw AudioSourceImportError.invalidData
            }

            return data
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
                case "\u{08}": result += "\\b"
                case "\u{0C}": result += "\\f"
                case "\u{00}" ... "\u{1F}":
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

// MARK: - Helper Types

private enum AudioJSONContainerType {
    case array
    case object
}

// MARK: - Meta Parser

/// Parses only the "meta" section from an audio source index JSON file.
/// This can be done with full loading since meta is expected to be small.
enum AudioSourceMetaParser {
    /// Parse the meta section from the given file URL.
    /// - Parameter fileURL: URL to the audio source index JSON file.
    /// - Returns: The parsed AudioSourceMeta.
    static func parse(from fileURL: URL) throws -> AudioSourceMeta {
        let stream = try JsonInputStream(filePath: fileURL.path)
        var objectDepth = 0
        var isInMeta = false
        var tokenBuffer: [JsonToken] = []
        let decoder = JSONDecoder()

        while let token = try stream.read() {
            switch token {
            case let .startObject(key):
                if case let .name(name) = key, name == "meta", objectDepth == 1 {
                    isInMeta = true
                    tokenBuffer.append(token)
                } else if isInMeta {
                    tokenBuffer.append(token)
                }
                objectDepth += 1

            case .endObject:
                objectDepth -= 1
                if isInMeta {
                    tokenBuffer.append(token)
                    if objectDepth == 1 {
                        // Finished collecting meta
                        let jsonData = try tokensToJSON(tokenBuffer)
                        return try decoder.decode(AudioSourceMeta.self, from: jsonData)
                    }
                }

            default:
                if isInMeta {
                    tokenBuffer.append(token)
                }
            }
        }

        throw AudioSourceImportError.invalidFormat
    }

    private static func tokensToJSON(_ tokens: [JsonToken]) throws -> Data {
        var json = ""
        var containerStack: [AudioJSONContainerType] = []

        for token in tokens {
            switch token {
            case let .startObject(key):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
                }
                json.append("{")
                containerStack.append(.object)
            case .endObject:
                if json.last == "," {
                    json.removeLast()
                }
                json.append("}")
                _ = containerStack.popLast()
                if !containerStack.isEmpty {
                    json.append(",")
                }
            case let .startArray(key):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
                }
                json.append("[")
                containerStack.append(.array)
            case .endArray:
                if json.last == "," {
                    json.removeLast()
                }
                json.append("]")
                _ = containerStack.popLast()
                if !containerStack.isEmpty {
                    json.append(",")
                }
            case let .string(key, value):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
                }
                json.append("\"\(escapeString(value))\",")
            case let .number(key, value):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
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
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
                }
                json.append("\(value),")
            case let .null(key):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyName(key)))\":")
                }
                json.append("null,")
            }
        }

        if json.last == "," {
            json.removeLast()
        }

        guard let data = json.data(using: .utf8) else {
            throw AudioSourceImportError.invalidData
        }

        return data
    }

    private static func keyName(_ key: JsonKey) -> String {
        switch key {
        case let .name(name):
            name
        case .index:
            ""
        }
    }

    private static func escapeString(_ str: String) -> String {
        var result = ""
        for scalar in str.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            case "\u{00}" ... "\u{1F}":
                let hex = String(scalar.value, radix: 16)
                result += "\\u" + hex.padding(toLength: 4, withPad: "0", startingAt: 0)
            default:
                result.append(Character(scalar))
            }
        }
        return result
    }
}
