// KanjiBankV3.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// Represents a single entry in a kanji_bank v3 file.
/// Layout (array-based):
/// 0: character (String)
/// 1: space-separated onyomi readings (String, may be empty)
/// 2: space-separated kunyomi readings (String, may be empty)
/// 3: space-separated tags (String, may be empty)
/// 4: meanings array ([String])
/// 5: stats object ([String: String])
struct KanjiBankV3Entry: DictionaryDataBankEntry {
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

    func toDataDictionary(dictionaryID: UUID) -> (DictionaryDataType, [String: any Sendable]) {
        let encoder = JSONEncoder()

        let onyomiData = (try? encoder.encode(onyomi)) ?? Data()
        let onyomiString = String(data: onyomiData, encoding: .utf8) ?? "[]"

        let kunyomiData = (try? encoder.encode(kunyomi)) ?? Data()
        let kunyomiString = String(data: kunyomiData, encoding: .utf8) ?? "[]"

        let tagsData = (try? encoder.encode(tags)) ?? Data()
        let tagsString = String(data: tagsData, encoding: .utf8) ?? "[]"

        let meaningsData = (try? encoder.encode(meanings)) ?? Data()
        let meaningsString = String(data: meaningsData, encoding: .utf8) ?? "[]"

        let statsData = (try? encoder.encode(stats)) ?? Data()
        let statsString = String(data: statsData, encoding: .utf8) ?? "{}"

        return (.kanjiEntry, [
            "character": character,
            "onyomi": onyomiString,
            "kunyomi": kunyomiString,
            "tags": tagsString,
            "meanings": meaningsString,
            "stats": statsString,
            "dictionaryID": dictionaryID,
            "id": UUID(),
        ])
    }

    private static func splitSpaceSeparated(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }
            .map { String($0) }
    }
}
