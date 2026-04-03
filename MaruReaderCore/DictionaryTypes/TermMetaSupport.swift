// TermMetaSupport.swift
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

public struct PitchAccent: Codable, Sendable {
    public let position: PitchPosition
    public let nasal: [Int]?
    public let devoice: [Int]?
    public let tags: [String]?

    public enum PitchPosition: Codable, Sendable {
        case mora(Int)
        case pattern(String)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let num = try? container.decode(Int.self) {
                self = .mora(num)
            } else {
                self = try .pattern(container.decode(String.self))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .mora(value):
                try container.encode(value)
            case let .pattern(pattern):
                try container.encode(pattern)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case position, nasal, devoice, tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(PitchPosition.self, forKey: .position)
        nasal = try Self.decodeIntOrArray(from: container, forKey: .nasal)
        devoice = try Self.decodeIntOrArray(from: container, forKey: .devoice)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
    }

    public init(position: PitchPosition, nasal: [Int]? = nil, devoice: [Int]? = nil, tags: [String]? = nil) {
        self.position = position
        self.nasal = nasal
        self.devoice = devoice
        self.tags = tags
    }

    private static func decodeIntOrArray(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [Int]? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return [value]
        }
        if let values = try? container.decode([Int].self, forKey: key) {
            return values
        }
        return nil
    }
}

public extension PitchAccent {
    var downstepString: String? {
        switch position {
        case let .mora(value):
            return String(value)
        case let .pattern(pattern):
            let characters = Array(pattern.uppercased())
            guard characters.count > 1 else {
                return characters.first == "H" ? "0" : nil
            }
            for index in 0 ..< (characters.count - 1) {
                if characters[index] == "H", characters[index + 1] == "L" {
                    return String(index + 1)
                }
            }
            if characters.allSatisfy({ $0 == "H" }) {
                return "0"
            }
            return nil
        }
    }
}

public struct IPATranscription: Codable, Sendable {
    public let ipa: String
    public let tags: [String]?

    public init(ipa: String, tags: [String]? = nil) {
        self.ipa = ipa
        self.tags = tags
    }
}
