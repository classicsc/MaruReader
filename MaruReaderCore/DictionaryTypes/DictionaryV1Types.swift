//
//  DictionaryV1Types.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

struct DictionaryIndex: Codable {
    let attribution: String?
    let downloadUrl: String?
    let url: String?
    let description: String?
    let frequencyMode: DictionaryFrequencyMode?
    let sequenced: Bool?
    let author: String?
    let indexUrl: String?
    let isUpdatable: Bool?
    let minimumYomitanVersion: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let title: String
    let revision: String?
    let format: Int?
    let version: Int?
    let tagMeta: [String: TagMetaEntry]?

    private enum CodingKeys: String, CodingKey {
        case attribution
        case downloadUrl
        case url
        case description
        case frequencyMode
        case sequenced
        case author
        case indexUrl
        case isUpdatable
        case minimumYomitanVersion
        case sourceLanguage
        case targetLanguage
        case title
        case revision
        case format
        case version
        case tagMeta
    }

    init(attribution: String?, downloadUrl: String?, url: String?, description: String?, frequencyMode: DictionaryFrequencyMode?, sequenced: Bool?, author: String?, indexUrl: String?, isUpdatable: Bool?, minimumYomitanVersion: String?, sourceLanguage: String?, targetLanguage: String?, title: String, revision: String?, format: Int?, version: Int?, tagMeta: [String: TagMetaEntry]?) {
        self.attribution = attribution
        self.downloadUrl = downloadUrl
        self.url = url
        self.description = description
        self.frequencyMode = frequencyMode
        self.sequenced = sequenced
        self.author = author
        self.indexUrl = indexUrl
        self.isUpdatable = isUpdatable
        self.minimumYomitanVersion = minimumYomitanVersion
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.title = title
        self.revision = revision
        self.format = format
        self.version = version
        self.tagMeta = tagMeta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Required field per schema
        let title = try container.decode(String.self, forKey: .title)
        let revision = try container.decode(String.self, forKey: .revision)

        let attribution = try container.decodeIfPresent(String.self, forKey: .attribution)
        let downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        let url = try container.decodeIfPresent(String.self, forKey: .url)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        let frequencyMode = try container.decodeIfPresent(DictionaryFrequencyMode.self, forKey: .frequencyMode)
        let sequenced = try container.decodeIfPresent(Bool.self, forKey: .sequenced)
        let author = try container.decodeIfPresent(String.self, forKey: .author)
        let indexUrl = try container.decodeIfPresent(String.self, forKey: .indexUrl)
        let isUpdatable = try container.decodeIfPresent(Bool.self, forKey: .isUpdatable)
        let minimumYomitanVersion = try container.decodeIfPresent(String.self, forKey: .minimumYomitanVersion)
        let sourceLanguage = try container.decodeIfPresent(String.self, forKey: .sourceLanguage)
        let targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage)
        let format = try container.decodeIfPresent(Int.self, forKey: .format)
        let version = try container.decodeIfPresent(Int.self, forKey: .version)
        let tagMeta = try container.decodeIfPresent([String: TagMetaEntry].self, forKey: .tagMeta)

        // 1. At least one of format or version must be provided
        guard format != nil || version != nil else { throw DictionaryImportError.invalidData }
        // 2. If isUpdatable == true then indexUrl & downloadUrl must be present
        if isUpdatable == true, indexUrl == nil || downloadUrl == nil {
            throw DictionaryImportError.invalidData
        }

        self.init(attribution: attribution,
                  downloadUrl: downloadUrl,
                  url: url,
                  description: description,
                  frequencyMode: frequencyMode,
                  sequenced: sequenced,
                  author: author,
                  indexUrl: indexUrl,
                  isUpdatable: isUpdatable,
                  minimumYomitanVersion: minimumYomitanVersion,
                  sourceLanguage: sourceLanguage,
                  targetLanguage: targetLanguage,
                  title: title,
                  revision: revision,
                  format: format,
                  version: version,
                  tagMeta: tagMeta)
    }
}

enum DictionaryFrequencyMode: String, Codable {
    case occurrence = "occurrence-based"
    case rank = "rank-based"
}

struct TagMetaEntry: Codable {
    let category: String?
    let order: Double?
    let notes: String?
    let score: Double?
}

// MARK: - Kanji Bank Entry Models

/// Represents a single entry in a kanji_bank v1 file.
/// Layout (array-based):
/// 0: character (String)
/// 1: space-separated onyomi readings (String, may be empty)
/// 2: space-separated kunyomi readings (String, may be empty)
/// 3: space-separated tags (String, may be empty)
/// 4+: meanings (String, optional, zero or more)
struct KanjiBankV1Entry: DictionaryDataBankEntry {
    let character: String
    let onyomi: [String]
    let kunyomi: [String]
    let tags: [String]
    let meanings: [String]

    init(character: String, onyomi: [String], kunyomi: [String], tags: [String], meanings: [String]) {
        self.character = character
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.tags = tags
        self.meanings = meanings
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard !container.isAtEnd else { throw DictionaryImportError.invalidData }
        let character = try container.decode(String.self)
        let onyomiRaw = try container.decode(String.self)
        let kunyomiRaw = try container.decode(String.self)
        let tagsRaw = try container.decode(String.self)
        var meanings: [String] = []
        while !container.isAtEnd {
            // Remaining items are meanings as raw strings
            if let meaning = try? container.decode(String.self) {
                meanings.append(meaning)
            } else {
                // If an item isn't a string, treat as corruption
                throw DictionaryImportError.invalidData
            }
        }
        self.character = character
        self.onyomi = KanjiBankV1Entry.splitSpaceSeparated(onyomiRaw)
        self.kunyomi = KanjiBankV1Entry.splitSpaceSeparated(kunyomiRaw)
        self.tags = KanjiBankV1Entry.splitSpaceSeparated(tagsRaw)
        self.meanings = meanings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(character)
        try container.encode(onyomi.joined(separator: " "))
        try container.encode(kunyomi.joined(separator: " "))
        try container.encode(tags.joined(separator: " "))
        for meaning in meanings {
            try container.encode(meaning)
        }
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

        let statsData = (try? encoder.encode([String: String]())) ?? Data()
        let statsString = String(data: statsData, encoding: .utf8) ?? "{}"

        return (.kanjiEntry, [
            "character": character,
            "onyomi": onyomiString,
            "kunyomi": kunyomiString,
            "tags": tagsString,
            "meanings": meaningsString,
            "dictionaryID": dictionaryID,
            "id": UUID(),
            "stats": statsString,
        ])
    }

    private static func splitSpaceSeparated(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }
            .map { String($0) }
    }
}

struct TermBankV1Entry: DictionaryDataBankEntry {
    let expression: String
    let reading: String
    let definitionTags: [String]
    let rules: [String]
    let score: Double
    let glossary: [Definition]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard !container.isAtEnd else { throw DictionaryImportError.invalidData }
        self.expression = try container.decode(String.self)
        self.reading = try container.decode(String.self)
        let definitionTagsRaw = try container.decode(String.self)
        let rulesRaw = try container.decode(String.self)
        self.score = try container.decode(Double.self)
        var glossary: [Definition] = []
        while !container.isAtEnd {
            // Remaining items are glossary entries as raw strings
            if let meaning = try? container.decode(String.self) {
                glossary.append(Definition.text(meaning))
            } else {
                // If an item isn't a string, treat as corruption
                throw DictionaryImportError.invalidData
            }
        }
        self.definitionTags = TermBankV1Entry.splitSpaceSeparated(definitionTagsRaw)
        self.rules = TermBankV1Entry.splitSpaceSeparated(rulesRaw)
        self.glossary = glossary
    }

    func toDataDictionary(dictionaryID: UUID) -> (DictionaryDataType, [String: any Sendable]) {
        let encoder = JSONEncoder()

        let definitionTagsData = (try? encoder.encode(definitionTags)) ?? Data()
        let definitionTagsString = String(data: definitionTagsData, encoding: .utf8) ?? "[]"

        let glossaryData = (try? encoder.encode(glossary)) ?? Data()
        let glossaryString = String(data: glossaryData, encoding: .utf8) ?? "[]"

        let rulesData = (try? encoder.encode(rules)) ?? Data()
        let rulesString = String(data: rulesData, encoding: .utf8) ?? "[]"

        return (.termEntry, [
            "expression": expression,
            "reading": reading,
            "definitionTags": definitionTagsString,
            "dictionaryID": dictionaryID,
            "glossary": glossaryString,
            "id": UUID(),
            "rules": rulesString,
            "score": score,
            "sequence": 0,
            "termTags": "[]",
        ])
    }

    private static func splitSpaceSeparated(_ s: String) -> [String] {
        s.split { $0 == " " || $0 == "\t" || $0 == "\n" }
            .map { String($0) }
    }
}
