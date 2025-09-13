//
//  KanjiBankV3.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

/// Represents a single entry in a kanji_bank v3 file.
/// Layout (array-based):
/// 0: character (String)
/// 1: space-separated onyomi readings (String, may be empty)
/// 2: space-separated kunyomi readings (String, may be empty)
/// 3: space-separated tags (String, may be empty)
/// 4: meanings array ([String])
/// 5: stats object ([String: String])
struct KanjiBankV3Entry: Codable {
    let character: String
    let onyomi: [String]
    let kunyomi: [String]
    let tags: [String]
    let meanings: [String]
    let stats: [String: String]

    init(character: String, onyomi: [String], kunyomi: [String], tags: [String], meanings: [String], stats: [String: String]) {
        self.character = character
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.tags = tags
        self.meanings = meanings
        self.stats = stats
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard !container.isAtEnd else { throw DictionaryImportError.invalidData }
        let character = try container.decode(String.self)
        let onyomiRaw = try container.decode(String.self)
        let kunyomiRaw = try container.decode(String.self)
        let tagsRaw = try container.decode(String.self)
        let meanings = try container.decode([String].self)
        let stats = try container.decode([String: String].self)
        if !container.isAtEnd {
            throw DictionaryImportError.invalidData
        }
        self.character = character
        self.onyomi = KanjiBankV3Entry.splitSpaceSeparated(onyomiRaw)
        self.kunyomi = KanjiBankV3Entry.splitSpaceSeparated(kunyomiRaw)
        self.tags = KanjiBankV3Entry.splitSpaceSeparated(tagsRaw)
        self.meanings = meanings
        self.stats = stats
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(character)
        try container.encode(onyomi.joined(separator: " "))
        try container.encode(kunyomi.joined(separator: " "))
        try container.encode(tags.joined(separator: " "))
        try container.encode(meanings)
        try container.encode(stats)
    }

    private static func splitSpaceSeparated(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }
            .map { String($0) }
    }
}
