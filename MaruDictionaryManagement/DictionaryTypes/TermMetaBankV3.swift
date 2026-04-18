// TermMetaBankV3.swift
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

/// One entry: [term, type, data]
struct TermMetaBankV3Entry: DictionaryDataBankEntry {
    let term: String
    let kind: Kind
    let data: TermMetaEntryData

    enum Kind: String, Codable {
        case freq
        case pitch
        case ipa
    }

    /// Custom decoding: since schema is an array, not an object
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 3 else {
            throw DictionaryImportError.invalidData
        }

        let term = try container.decode(String.self)
        let kind = try container.decode(Kind.self)

        switch kind {
        case .freq:
            // freq can be FrequencyData OR ReadingFrequencyData
            if let freq = try? container.decode(FrequencyData.self) {
                self.data = .frequency(freq)
            } else {
                let freqReading = try container.decode(ReadingFrequencyData.self)
                self.data = .frequencyWithReading(freqReading)
            }
        case .pitch:
            let pitchData = try container.decode(PitchData.self)
            self.data = .pitch(pitchData)
        case .ipa:
            let ipaData = try container.decode(IPAData.self)
            self.data = .ipa(ipaData)
        }

        self.term = term
        self.kind = kind
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(term)
        try container.encode(kind)
        switch data {
        case let .frequency(freq):
            try container.encode(freq)
        case let .frequencyWithReading(rf):
            try container.encode(rf)
        case let .pitch(pitch):
            try container.encode(pitch)
        case let .ipa(ipa):
            try container.encode(ipa)
        }
    }

    func toDataDictionary(
        dictionaryID: UUID,
        glossaryCompressionVersion _: GlossaryCompressionCodecVersion,
        glossaryCompressionBaseDirectory _: URL?,
        glossaryZSTDCompressionLevel _: Int32? = nil
    ) throws -> (DictionaryDataType, [String: any Sendable]) {
        let encoder = JSONEncoder()
        switch data {
        case let .frequency(freq):
            return (.termFrequencyEntry, [
                "dictionaryID": dictionaryID,
                "expression": term,
                "reading": "",
                "value": freq.value,
                "displayValue": freq.displayValue ?? "",
                "id": UUID(),
            ])
        case let .frequencyWithReading(rf):
            return (.termFrequencyEntry, [
                "dictionaryID": dictionaryID,
                "expression": term,
                "reading": rf.reading,
                "value": rf.frequency.value,
                "displayValue": rf.frequency.displayValue ?? "",
                "id": UUID(),
            ])
        case let .pitch(pitch):
            let pitchesData = (try? encoder.encode(pitch.pitches)) ?? Data()
            let pitchesString = String(data: pitchesData, encoding: .utf8) ?? "[]"
            return (.pitchAccentEntry, [
                "dictionaryID": dictionaryID,
                "expression": term,
                "reading": pitch.reading,
                "pitches": pitchesString,
                "id": UUID(),
            ])
        case let .ipa(ipa):
            let transcriptionsData = (try? encoder.encode(ipa.transcriptions)) ?? Data()
            let transcriptionsString = String(data: transcriptionsData, encoding: .utf8) ?? "[]"
            return (.ipaEntry, [
                "dictionaryID": dictionaryID,
                "expression": term,
                "reading": ipa.reading,
                "transcriptions": transcriptionsString,
                "id": UUID(),
            ])
        }
    }
}

enum TermMetaEntryData: Codable {
    case frequency(FrequencyData)
    case frequencyWithReading(ReadingFrequencyData)
    case pitch(PitchData)
    case ipa(IPAData)
}

struct FrequencyData: Codable, Comparable {
    let value: Double
    let displayValue: String?

    /// Schema allows number OR string as shorthand
    init(from decoder: Decoder) throws {
        if let num = try? decoder.singleValueContainer().decode(Double.self) {
            self.value = num
            self.displayValue = nil
        } else if let str = try? decoder.singleValueContainer().decode(String.self) {
            if let num = Double(str) {
                self.value = num
                self.displayValue = str
            } else {
                // String that can't be parsed as number - use as display value with default numeric value
                self.value = 0.0
                self.displayValue = str
            }
        } else {
            let obj = try decoder.singleValueContainer().decode(FrequencyObject.self)
            self.value = obj.value
            self.displayValue = obj.displayValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let display = displayValue {
            try container.encode(FrequencyObject(value: value, displayValue: display))
        } else {
            try container.encode(value)
        }
    }

    static func < (lhs: FrequencyData, rhs: FrequencyData) -> Bool {
        lhs.value < rhs.value
    }

    private struct FrequencyObject: Codable {
        let value: Double
        let displayValue: String?
    }
}

struct ReadingFrequencyData: Codable {
    let reading: String
    let frequency: FrequencyData
}

struct PitchData: Codable {
    let reading: String
    let pitches: [PitchAccent]
}

struct IPAData: Codable {
    let reading: String
    let transcriptions: [IPATranscription]
}
