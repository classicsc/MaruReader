//
//  DictionaryImportTypes.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/6/25.
//

enum DictionaryImportError: Error {
    case notADictionary
    case unsupportedFormat
    case importNotFound
    case dictionaryCreationFailed
}

struct DictionaryIndex: Codable, Sendable {
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
}

enum DictionaryFrequencyMode: String, Sendable, Codable {
    case occurrence = "occurrence-based"
    case rank = "rank-based"
}

struct TagMetaEntry: Codable {
    let category: String?
    let order: Double?
    let notes: String?
    let score: Double?
}
