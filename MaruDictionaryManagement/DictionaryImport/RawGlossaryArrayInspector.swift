// RawGlossaryArrayInspector.swift
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

private enum RawGlossaryASCII {
    static let quote: UInt8 = 34
    static let comma: UInt8 = 44
    static let minus: UInt8 = 45
    static let dot: UInt8 = 46
    static let zero: UInt8 = 48
    static let nine: UInt8 = 57
    static let colon: UInt8 = 58
    static let leftSquare: UInt8 = 91
    static let backslash: UInt8 = 92
    static let rightSquare: UInt8 = 93
    static let leftBrace: UInt8 = 123
    static let rightBrace: UInt8 = 125
    static let space: UInt8 = 32
    static let tab: UInt8 = 9
    static let lf: UInt8 = 10
    static let cr: UInt8 = 13
    static let e: UInt8 = 101
    static let E: UInt8 = 69
    static let n: UInt8 = 110
    static let t: UInt8 = 116
    static let f: UInt8 = 102
    static let plus: UInt8 = 43
}

enum RawGlossaryArrayInspector {
    static func inspect(_ data: Data, allowedKinds: Set<JsonRawValueKind>? = nil) throws -> Int {
        let bytes = Array(data)
        guard bytes.first == RawGlossaryASCII.leftSquare else {
            throw DictionaryImportError.invalidData
        }

        var index = 1
        var count = 0
        skipWhitespace(in: bytes, index: &index)

        if index == bytes.count {
            throw DictionaryImportError.invalidData
        }

        if bytes[index] == RawGlossaryASCII.rightSquare {
            index += 1
            skipWhitespace(in: bytes, index: &index)
            guard index == bytes.count else {
                throw DictionaryImportError.invalidData
            }
            return 0
        }

        while true {
            let kind = try scanValue(in: bytes, index: &index)
            if let allowedKinds, !allowedKinds.contains(kind) {
                throw DictionaryImportError.invalidData
            }
            count += 1

            skipWhitespace(in: bytes, index: &index)
            guard index < bytes.count else {
                throw DictionaryImportError.invalidData
            }

            let byte = bytes[index]
            if byte == RawGlossaryASCII.comma {
                index += 1
                skipWhitespace(in: bytes, index: &index)
                guard index < bytes.count, bytes[index] != RawGlossaryASCII.rightSquare else {
                    throw DictionaryImportError.invalidData
                }
                continue
            }

            guard byte == RawGlossaryASCII.rightSquare else {
                throw DictionaryImportError.invalidData
            }

            index += 1
            skipWhitespace(in: bytes, index: &index)
            guard index == bytes.count else {
                throw DictionaryImportError.invalidData
            }
            return count
        }
    }

    private static func scanValue(in bytes: [UInt8], index: inout Int) throws -> JsonRawValueKind {
        guard index < bytes.count else {
            throw DictionaryImportError.invalidData
        }

        let byte = bytes[index]
        switch byte {
        case RawGlossaryASCII.quote:
            try scanString(in: bytes, index: &index)
            return .string
        case RawGlossaryASCII.leftBrace:
            try scanComposite(in: bytes, index: &index, opening: RawGlossaryASCII.leftBrace)
            return .object
        case RawGlossaryASCII.leftSquare:
            try scanComposite(in: bytes, index: &index, opening: RawGlossaryASCII.leftSquare)
            return .array
        case RawGlossaryASCII.n:
            try scanLiteral(in: bytes, index: &index, suffix: "ull")
            return .null
        case RawGlossaryASCII.t:
            try scanLiteral(in: bytes, index: &index, suffix: "rue")
            return .bool
        case RawGlossaryASCII.f:
            try scanLiteral(in: bytes, index: &index, suffix: "alse")
            return .bool
        case RawGlossaryASCII.minus, RawGlossaryASCII.zero ... RawGlossaryASCII.nine:
            try scanNumber(in: bytes, index: &index)
            return .number
        default:
            throw DictionaryImportError.invalidData
        }
    }

    private static func scanString(in bytes: [UInt8], index: inout Int) throws {
        index += 1
        var escaping = false

        while index < bytes.count {
            let byte = bytes[index]
            index += 1

            if escaping {
                escaping = false
                continue
            }

            if byte == RawGlossaryASCII.backslash {
                escaping = true
                continue
            }

            if byte == RawGlossaryASCII.quote {
                return
            }

            if (0 ... 0x1F).contains(byte) {
                throw DictionaryImportError.invalidData
            }
        }

        throw DictionaryImportError.invalidData
    }

    private static func scanComposite(in bytes: [UInt8], index: inout Int, opening: UInt8) throws {
        var stack = [opening]
        var escaping = false
        var inString = false
        index += 1

        while index < bytes.count {
            let byte = bytes[index]
            index += 1

            if inString {
                if escaping {
                    escaping = false
                    continue
                }

                if byte == RawGlossaryASCII.backslash {
                    escaping = true
                    continue
                }

                if byte == RawGlossaryASCII.quote {
                    inString = false
                    continue
                }

                if (0 ... 0x1F).contains(byte) {
                    throw DictionaryImportError.invalidData
                }

                continue
            }

            switch byte {
            case RawGlossaryASCII.quote:
                inString = true
            case RawGlossaryASCII.leftBrace, RawGlossaryASCII.leftSquare:
                stack.append(byte)
            case RawGlossaryASCII.rightBrace:
                guard stack.last == RawGlossaryASCII.leftBrace else {
                    throw DictionaryImportError.invalidData
                }
                stack.removeLast()
            case RawGlossaryASCII.rightSquare:
                guard stack.last == RawGlossaryASCII.leftSquare else {
                    throw DictionaryImportError.invalidData
                }
                stack.removeLast()
            default:
                break
            }

            if stack.isEmpty {
                return
            }
        }

        throw DictionaryImportError.invalidData
    }

    private static func scanLiteral(in bytes: [UInt8], index: inout Int, suffix: String) throws {
        index += 1
        for expected in suffix.utf8 {
            guard index < bytes.count, bytes[index] == expected else {
                throw DictionaryImportError.invalidData
            }
            index += 1
        }
    }

    private static func scanNumber(in bytes: [UInt8], index: inout Int) throws {
        guard index < bytes.count else {
            throw DictionaryImportError.invalidData
        }

        if bytes[index] == RawGlossaryASCII.minus {
            index += 1
            guard index < bytes.count else {
                throw DictionaryImportError.invalidData
            }
        }

        guard index < bytes.count else {
            throw DictionaryImportError.invalidData
        }

        let firstDigit = bytes[index]
        guard isDigit(firstDigit) else {
            throw DictionaryImportError.invalidData
        }

        index += 1

        if firstDigit == RawGlossaryASCII.zero {
            if index < bytes.count, isDigit(bytes[index]) {
                throw DictionaryImportError.invalidData
            }
        } else {
            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }

        if index < bytes.count, bytes[index] == RawGlossaryASCII.dot {
            index += 1
            guard index < bytes.count, isDigit(bytes[index]) else {
                throw DictionaryImportError.invalidData
            }

            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }

        if index < bytes.count, bytes[index] == RawGlossaryASCII.e || bytes[index] == RawGlossaryASCII.E {
            index += 1

            if index < bytes.count, bytes[index] == RawGlossaryASCII.minus || bytes[index] == RawGlossaryASCII.plus {
                index += 1
            }

            guard index < bytes.count, isDigit(bytes[index]) else {
                throw DictionaryImportError.invalidData
            }

            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }
    }

    private static func skipWhitespace(in bytes: [UInt8], index: inout Int) {
        while index < bytes.count {
            let byte = bytes[index]
            if byte == RawGlossaryASCII.space || byte == RawGlossaryASCII.lf || byte == RawGlossaryASCII.tab || byte == RawGlossaryASCII.cr {
                index += 1
            } else {
                return
            }
        }
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        RawGlossaryASCII.zero ... RawGlossaryASCII.nine ~= byte
    }
}
