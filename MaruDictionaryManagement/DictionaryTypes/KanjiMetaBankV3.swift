// KanjiMetaBankV3.swift
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
import MaruReaderCore

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
struct KanjiMetaBankV3Entry: DictionaryDataBankEntry {
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

    func toDataDictionary(
        dictionaryID: UUID,
        glossaryCompressionVersion _: GlossaryCompressionCodecVersion,
        glossaryCompressionBaseDirectory _: URL?,
        glossaryZSTDCompressionLevel _: Int32? = nil
    ) throws -> (DictionaryDataType, [String: any Sendable]) {
        (.kanjiFrequencyEntry, [
            "character": kanji,
            "displayFrequency": {
                switch frequency {
                case let .number(num):
                    String(num)
                case let .string(str):
                    str
                case let .object(_, displayValue):
                    displayValue ?? String(describing: frequency)
                }
            }(),
            "frequencyValue": {
                switch frequency {
                case let .number(num):
                    num
                case let .string(str):
                    Double(str) ?? 0
                case let .object(value, _):
                    value
                }
            }(),
            "dictionaryID": dictionaryID,
            "id": UUID(),
        ])
    }
}
