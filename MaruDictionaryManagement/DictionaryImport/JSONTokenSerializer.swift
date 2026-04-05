// JSONTokenSerializer.swift
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

enum JSONTokenSerializer {
    static func serialize(_ tokens: [JsonToken]) throws -> Data {
        var json = ""
        var serializer = ValueSerializer()
        try serializer.append(tokens, to: &json)
        try serializer.finish(json: &json)

        guard let data = json.data(using: .utf8) else {
            throw DictionaryImportError.invalidData
        }

        return data
    }

    static func appendValue(from stream: JsonInputStream, firstToken: JsonToken, to json: inout String) throws {
        var serializer = ValueSerializer()
        try serializer.append(firstToken, to: &json)

        while !serializer.isComplete {
            guard let token = try stream.read() else {
                throw DictionaryImportError.invalidData
            }

            try serializer.append(token, to: &json)
        }

        try serializer.finish(json: &json)
    }

    static func serializeArray(from elements: [Data]) -> Data? {
        guard !elements.isEmpty else {
            return nil
        }

        let totalElementBytes = elements.reduce(into: 0) { total, element in
            total += element.count
        }

        var data = Data()
        data.reserveCapacity(totalElementBytes + elements.count + 1)
        data.append(contentsOf: "[".utf8)
        for (index, element) in elements.enumerated() {
            if index > 0 {
                data.append(contentsOf: ",".utf8)
            }
            data.append(element)
        }
        data.append(contentsOf: "]".utf8)
        return data
    }

    private enum ContainerType {
        case array
        case object
    }

    private struct ValueSerializer {
        private(set) var isComplete = false
        private var hasWrittenToken = false
        private var containerStack: [ContainerType] = []

        mutating func append(_ tokens: [JsonToken], to json: inout String) throws {
            for token in tokens {
                try append(token, to: &json)
            }
        }

        mutating func append(_ token: JsonToken, to json: inout String) throws {
            guard !isComplete else {
                throw DictionaryImportError.invalidData
            }

            hasWrittenToken = true

            switch token {
            case let .startObject(key):
                appendKeyIfNeeded(key, to: &json)
                json.append("{")
                containerStack.append(.object)

            case .endObject:
                guard containerStack.popLast() == .object else {
                    throw DictionaryImportError.invalidData
                }
                removeTrailingCommaIfNeeded(from: &json)
                json.append("}")
                finishCurrentValueIfNeeded(in: &json)

            case let .startArray(key):
                appendKeyIfNeeded(key, to: &json)
                json.append("[")
                containerStack.append(.array)

            case .endArray:
                guard containerStack.popLast() == .array else {
                    throw DictionaryImportError.invalidData
                }
                removeTrailingCommaIfNeeded(from: &json)
                json.append("]")
                finishCurrentValueIfNeeded(in: &json)

            case let .string(key, value):
                appendKeyIfNeeded(key, to: &json)
                appendQuotedString(value, to: &json)
                finishScalarValue(in: &json)

            case let .number(key, value):
                appendKeyIfNeeded(key, to: &json)
                switch value {
                case let .int(number):
                    json.append("\(number)")
                case let .double(number):
                    json.append("\(number)")
                case let .decimal(number):
                    json.append("\(number)")
                }
                finishScalarValue(in: &json)

            case let .bool(key, value):
                appendKeyIfNeeded(key, to: &json)
                if value {
                    json.append("true")
                } else {
                    json.append("false")
                }
                finishScalarValue(in: &json)

            case let .null(key):
                appendKeyIfNeeded(key, to: &json)
                json.append("null")
                finishScalarValue(in: &json)
            }
        }

        mutating func finish(json: inout String) throws {
            guard hasWrittenToken, isComplete else {
                throw DictionaryImportError.invalidData
            }

            removeTrailingCommaIfNeeded(from: &json)
        }

        private func appendKeyIfNeeded(_ key: JsonKey?, to json: inout String) {
            guard case .object = containerStack.last, let key else {
                return
            }

            appendQuotedString(JSONTokenSerializer.keyDescription(key), to: &json)
            json.append(":")
        }

        private func appendQuotedString(_ value: String, to json: inout String) {
            json.append("\"")
            json.append(JSONTokenSerializer.escapeString(value))
            json.append("\"")
        }

        private mutating func finishScalarValue(in json: inout String) {
            if containerStack.isEmpty {
                isComplete = true
                return
            }

            json.append(",")
        }

        private mutating func finishCurrentValueIfNeeded(in json: inout String) {
            if containerStack.isEmpty {
                isComplete = true
                return
            }

            json.append(",")
        }

        private func removeTrailingCommaIfNeeded(from json: inout String) {
            if json.last == "," {
                json.removeLast()
            }
        }
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
