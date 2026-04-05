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

    private enum ContainerType {
        case array
        case object
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
