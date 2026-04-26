#!/usr/bin/env swift

// generate-deconjugation-rules.swift
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

import Foundation

private struct SourceRule: Decodable {
    let type: String
    let contextRule: String?
    let decEnd: [String]
    let conEnd: [String]
    let decTag: [String]?
    let conTag: [String]?
    let detail: String

    private enum CodingKeys: String, CodingKey {
        case type
        case contextRule = "contextrule"
        case decEnd = "dec_end"
        case conEnd = "con_end"
        case decTag = "dec_tag"
        case conTag = "con_tag"
        case detail
    }
}

private struct GeneratedRule {
    let type: String
    let contextRule: String?
    let decEnd: String
    let conEnd: String
    let decTag: String?
    let conTag: String?
    let detail: String
}

private enum GeneratorError: LocalizedError {
    case invalidArguments
    case emptyArray(ruleIndex: Int, field: String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Usage: swift scripts/generate-deconjugation-rules.swift <deconjugator.json> <output.swift>"
        case let .emptyArray(ruleIndex, field):
            "Rule \(ruleIndex) has an empty \(field) array."
        }
    }
}

private func element(_ values: [String], at index: Int, ruleIndex: Int, field: String) throws -> String {
    guard let first = values.first else {
        throw GeneratorError.emptyArray(ruleIndex: ruleIndex, field: field)
    }
    return index < values.count ? values[index] : first
}

private func optionalElement(_ values: [String]?, at index: Int) -> String? {
    guard let values, let first = values.first else { return nil }
    return index < values.count ? values[index] : first
}

private func swiftString(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
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
        default:
            result.unicodeScalars.append(scalar)
        }
    }
    result += "\""
    return result
}

private func swiftOptionalString(_ value: String?) -> String {
    value.map(swiftString) ?? "nil"
}

private func strictJSONData(from data: Data) -> Data {
    let source = String(decoding: data, as: UTF8.self)
    var withoutComments = ""
    var index = source.startIndex
    var inString = false
    var escaping = false

    while index < source.endIndex {
        let character = source[index]
        let nextIndex = source.index(after: index)

        if inString {
            withoutComments.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            index = nextIndex
            continue
        }

        if character == "\"" {
            inString = true
            withoutComments.append(character)
            index = nextIndex
            continue
        }

        if character == "/", nextIndex < source.endIndex, source[nextIndex] == "/" {
            index = nextIndex
            while index < source.endIndex, source[index] != "\n" {
                index = source.index(after: index)
            }
            continue
        }

        withoutComments.append(character)
        index = nextIndex
    }

    var withoutTrailingCommas = ""
    var pendingComma = false
    inString = false
    escaping = false

    for character in withoutComments {
        if inString {
            withoutTrailingCommas.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            continue
        }

        if character == "\"" {
            if pendingComma {
                withoutTrailingCommas.append(",")
                pendingComma = false
            }
            inString = true
            withoutTrailingCommas.append(character)
            continue
        }

        if pendingComma {
            if character.isWhitespace {
                withoutTrailingCommas.append(character)
                continue
            }
            if character != "]", character != "}" {
                withoutTrailingCommas.append(",")
            }
            pendingComma = false
        }

        if character == "," {
            pendingComma = true
        } else {
            withoutTrailingCommas.append(character)
        }
    }

    if pendingComma {
        withoutTrailingCommas.append(",")
    }

    return Data(withoutTrailingCommas.utf8)
}

do {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else {
        throw GeneratorError.invalidArguments
    }

    let inputURL = URL(fileURLWithPath: arguments[1])
    let outputURL = URL(fileURLWithPath: arguments[2])
    let data = try strictJSONData(from: Data(contentsOf: inputURL))

    let decoder = JSONDecoder()
    let sourceRules = try decoder.decode([SourceRule].self, from: data)
    var generatedRules: [GeneratedRule] = []

    for (ruleIndex, rule) in sourceRules.enumerated() {
        let count = max(rule.decEnd.count, rule.conEnd.count, rule.decTag?.count ?? 0, rule.conTag?.count ?? 0)
        for index in 0 ..< count {
            try generatedRules.append(GeneratedRule(
                type: rule.type,
                contextRule: rule.contextRule,
                decEnd: element(rule.decEnd, at: index, ruleIndex: ruleIndex, field: "dec_end"),
                conEnd: element(rule.conEnd, at: index, ruleIndex: ruleIndex, field: "con_end"),
                decTag: optionalElement(rule.decTag, at: index),
                conTag: optionalElement(rule.conTag, at: index),
                detail: rule.detail
            ))
        }
    }

    let body = generatedRules.enumerated().map { index, rule in
        """
            JapaneseDeconjugationRule(
                type: \(swiftString(rule.type)),
                contextRule: \(swiftOptionalString(rule.contextRule)),
                decEnd: \(swiftString(rule.decEnd)),
                conEnd: \(swiftString(rule.conEnd)),
                decTag: \(swiftOptionalString(rule.decTag)),
                conTag: \(swiftOptionalString(rule.conTag)),
                detail: \(swiftString(rule.detail)),
                ordinal: \(index)
            )
        """
    }.joined(separator: ",\n")

    let output = """
    // DeconjugationRules.swift
    // Generated by scripts/generate-deconjugation-rules.swift. Do not edit by hand.

    import Foundation

    extension JapaneseDeconjugationRule {
        static let generated: [JapaneseDeconjugationRule] = [
    \(body)
        ]
    }

    """

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try output.write(to: outputURL, atomically: true, encoding: .utf8)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
