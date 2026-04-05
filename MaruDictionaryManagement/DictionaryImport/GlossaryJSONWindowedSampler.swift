// GlossaryJSONWindowedSampler.swift
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

enum GlossaryJSONWindowedSampler {
    static func collectGlossarySamples(
        from bankURL: URL,
        format: DictionaryFormat,
        windowStride: Int,
        windowLength: Int,
        maximumTotalBytes: Int
    ) throws -> [Data] {
        guard maximumTotalBytes > 0 else {
            return []
        }

        var parser = Parser(
            format: format,
            windowStride: max(1, windowStride),
            windowLength: max(1, windowLength),
            maximumTotalBytes: maximumTotalBytes
        )
        return try parser.collect(from: bankURL)
    }

    private struct Parser {
        let format: DictionaryFormat
        let windowStride: Int
        let windowLength: Int
        let maximumTotalBytes: Int

        private var samples: [Data] = []
        private var totalSampleBytes = 0

        private var isInRootArray = false
        private var isInsideEntry = false
        private var entryIndex = 0
        private var entryDepth = 0
        private var topLevelElementIndex = 0
        private var sampleCurrentEntry = false
        private var captureNestingDepth = 0
        private var captureBuffer: [JsonToken] = []
        private var capturedGlossaryValue: Data?
        private var capturedV1GlossaryElements: [Data] = []

        init(
            format: DictionaryFormat,
            windowStride: Int,
            windowLength: Int,
            maximumTotalBytes: Int
        ) {
            self.format = format
            self.windowStride = windowStride
            self.windowLength = windowLength
            self.maximumTotalBytes = maximumTotalBytes
        }

        mutating func collect(from bankURL: URL) throws -> [Data] {
            let stream = try JsonInputStream(filePath: bankURL.path)

            while let token = try stream.read() {
                try process(token)

                if totalSampleBytes >= maximumTotalBytes, !samples.isEmpty {
                    break
                }
            }

            return samples
        }

        private mutating func process(_ token: JsonToken) throws {
            if !isInRootArray {
                if case let .startArray(key) = token, key == nil {
                    isInRootArray = true
                }
                return
            }

            if !isInsideEntry {
                switch token {
                case .startArray:
                    startEntry()
                case .endArray:
                    isInRootArray = false
                default:
                    break
                }
                return
            }

            switch token {
            case .startArray, .startObject:
                let startsTopLevelValue = entryDepth == 1
                if startsTopLevelValue, shouldCaptureTopLevelValue(at: topLevelElementIndex) {
                    captureBuffer = [token]
                    captureNestingDepth = 1
                } else if captureNestingDepth > 0 {
                    captureBuffer.append(token)
                    captureNestingDepth += 1
                }
                entryDepth += 1

            case .endArray, .endObject:
                if captureNestingDepth > 0 {
                    captureBuffer.append(token)
                    captureNestingDepth -= 1

                    if captureNestingDepth == 0 {
                        try finishCapturedValue()
                    }
                }

                entryDepth -= 1

                if entryDepth == 0 {
                    try finishEntry()
                    return
                }

                if entryDepth == 1 {
                    topLevelElementIndex += 1
                }

            case .string, .number, .bool, .null:
                if entryDepth == 1 {
                    if shouldCaptureTopLevelValue(at: topLevelElementIndex) {
                        let valueJSON = try JSONTokenSerializer.serialize([token])
                        captureScalarValue(valueJSON)
                    }
                    topLevelElementIndex += 1
                } else if captureNestingDepth > 0 {
                    captureBuffer.append(token)
                }
            }
        }

        private mutating func startEntry() {
            isInsideEntry = true
            entryDepth = 1
            topLevelElementIndex = 0
            sampleCurrentEntry = (entryIndex % windowStride) < windowLength
            captureNestingDepth = 0
            captureBuffer.removeAll(keepingCapacity: true)
            capturedGlossaryValue = nil
            capturedV1GlossaryElements.removeAll(keepingCapacity: true)
        }

        private func shouldCaptureTopLevelValue(at index: Int) -> Bool {
            guard sampleCurrentEntry else {
                return false
            }

            switch format {
            case .v1:
                return index >= 5
            case .v3:
                return index == 5
            }
        }

        private mutating func captureScalarValue(_ valueJSON: Data) {
            switch format {
            case .v1:
                capturedV1GlossaryElements.append(valueJSON)
            case .v3:
                capturedGlossaryValue = valueJSON
            }
        }

        private mutating func finishCapturedValue() throws {
            let valueJSON = try JSONTokenSerializer.serialize(captureBuffer)
            captureBuffer.removeAll(keepingCapacity: true)
            captureScalarValue(valueJSON)
        }

        private mutating func finishEntry() throws {
            defer {
                isInsideEntry = false
                entryIndex += 1
                entryDepth = 0
                captureNestingDepth = 0
                captureBuffer.removeAll(keepingCapacity: true)
                capturedGlossaryValue = nil
                capturedV1GlossaryElements.removeAll(keepingCapacity: true)
            }

            guard sampleCurrentEntry else {
                return
            }

            let glossaryJSON: Data? = switch format {
            case .v1:
                JSONTokenSerializer.serializeArray(from: capturedV1GlossaryElements)
            case .v3:
                capturedGlossaryValue
            }

            guard let glossaryJSON else {
                return
            }

            if samples.isEmpty || totalSampleBytes + glossaryJSON.count <= maximumTotalBytes {
                samples.append(glossaryJSON)
                totalSampleBytes += glossaryJSON.count
            }
        }
    }
}

private enum JSONTokenSerializer {
    static func serialize(_ tokens: [JsonToken]) throws -> Data {
        var json = ""
        var containerStack: [ContainerType] = []

        for token in tokens {
            switch token {
            case let .startObject(key):
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
                if !containerStack.isEmpty {
                    json.append(",")
                }

            case let .startArray(key):
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
                if !containerStack.isEmpty {
                    json.append(",")
                }

            case let .string(key, value):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyDescription(key)))\":")
                }
                json.append("\"\(escapeString(value))\",")

            case let .number(key, value):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyDescription(key)))\":")
                }
                switch value {
                case let .int(number):
                    json.append("\(number),")
                case let .double(number):
                    json.append("\(number),")
                case let .decimal(number):
                    json.append("\(number),")
                }

            case let .bool(key, value):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyDescription(key)))\":")
                }
                json.append("\(value),")

            case let .null(key):
                if case .object = containerStack.last, let key {
                    json.append("\"\(escapeString(keyDescription(key)))\":")
                }
                json.append("null,")
            }
        }

        if json.last == "," {
            json.removeLast()
        }

        guard let data = json.data(using: .utf8) else {
            throw DictionaryImportError.invalidData
        }

        return data
    }

    static func serializeArray(from elements: [Data]) -> Data? {
        guard !elements.isEmpty else {
            return nil
        }

        var data = Data("[".utf8)
        for (index, element) in elements.enumerated() {
            if index > 0 {
                data.append(Data(",".utf8))
            }
            data.append(element)
        }
        data.append(Data("]".utf8))
        return data
    }

    private static func keyDescription(_ key: JsonKey) -> String {
        switch key {
        case let .name(name):
            name
        case .index:
            ""
        }
    }

    private static func escapeString(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            case "\u{08}":
                result += "\\b"
            case "\u{0C}":
                result += "\\f"
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
