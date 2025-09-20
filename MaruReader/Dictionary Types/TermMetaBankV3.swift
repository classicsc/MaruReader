//
//  TermMetaBankV3.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

/// One entry: [term, type, data]
struct TermMetaBankV3Entry: Codable {
    let term: String
    let kind: Kind
    let data: TermMetaEntryData

    enum Kind: String, Codable {
        case freq
        case pitch
        case ipa
    }

    // Custom decoding: since schema is an array, not an object
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

    // Schema allows number OR string as shorthand
    init(from decoder: Decoder) throws {
        if let num = try? decoder.singleValueContainer().decode(Double.self) {
            self.value = num
            self.displayValue = nil
        } else if let str = try? decoder.singleValueContainer().decode(String.self),
                  let num = Double(str)
        {
            self.value = num
            self.displayValue = str
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

struct PitchAccent: Codable {
    let position: PitchPosition
    let nasal: [Int]?
    let devoice: [Int]?
    let tags: [String]?

    enum PitchPosition: Codable {
        case mora(Int)
        case pattern(String) // e.g. "HHLL"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let num = try? container.decode(Int.self) {
                self = .mora(num)
            } else {
                self = try .pattern(container.decode(String.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .mora(n): try container.encode(n)
            case let .pattern(p): try container.encode(p)
            }
        }
    }

    // nasal/devoice can be int or array
    private enum CodingKeys: String, CodingKey {
        case position, nasal, devoice, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.position = try c.decode(PitchPosition.self, forKey: .position)

        func decodeIntOrArray(for key: CodingKeys) throws -> [Int]? {
            if let n = try? c.decode(Int.self, forKey: key) {
                return [n]
            } else if let arr = try? c.decode([Int].self, forKey: key) {
                return arr
            }
            return nil
        }

        self.nasal = try decodeIntOrArray(for: .nasal)
        self.devoice = try decodeIntOrArray(for: .devoice)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags)
    }
}

struct IPAData: Codable {
    let reading: String
    let transcriptions: [Transcription]

    struct Transcription: Codable {
        let ipa: String
        let tags: [String]?
    }
}
