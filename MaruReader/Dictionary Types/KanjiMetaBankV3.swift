//
//  KanjiMetaBankV3.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

/// Represents the frequency metadata for a kanji character.
/// Can be a simple number/string, or an object with `value` and `displayValue`.
enum KanjiFrequency: Codable {
    case number(Double)
    case string(String)
    case object(value: Double, displayValue: String?)

    private enum CodingKeys: String, CodingKey {
        case value
        case displayValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try number
        if let num = try? container.decode(Double.self) {
            self = .number(num)
            return
        }
        // Try string
        if let str = try? container.decode(String.self) {
            self = .string(str)
            return
        }
        // Try object
        if let obj = try? decoder.container(keyedBy: CodingKeys.self) {
            let value = try obj.decode(Double.self, forKey: .value)
            let displayValue = try obj.decodeIfPresent(String.self, forKey: .displayValue)
            self = .object(value: value, displayValue: displayValue)
            return
        }
        throw DecodingError.typeMismatch(
            KanjiFrequency.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "Unsupported frequency format")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .number(num):
            var container = encoder.singleValueContainer()
            try container.encode(num)
        case let .string(str):
            var container = encoder.singleValueContainer()
            try container.encode(str)
        case let .object(value, displayValue):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
            try container.encodeIfPresent(displayValue, forKey: .displayValue)
        }
    }
}

/// Represents a single entry in the Kanji Meta Bank V3 schema.
struct KanjiMetaBankV3Entry: Codable {
    let kanji: String
    let type: String
    let frequency: KanjiFrequency

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 3 else {
            throw DictionaryImportError.invalidData
        }

        self.kanji = try container.decode(String.self)
        self.type = try container.decode(String.self)
        self.frequency = try container.decode(KanjiFrequency.self)

        guard type == "freq" else {
            throw DictionaryImportError.invalidData
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(kanji)
        try container.encode(type)
        try container.encode(frequency)
    }
}
