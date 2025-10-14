//
//  DictionaryDataBankEntry.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/14/25.
//

import Foundation

protocol DictionaryDataBankEntry: Codable, Sendable {
    func toDataDictionary(dictionaryID: UUID) -> (DictionaryDataType, [String: Sendable])
}

enum DictionaryDataType {
    case dictionaryTagMeta
    case ipaEntry
    case kanjiEntry
    case kanjiFrequencyEntry
    case pitchAccentEntry
    case termEntry
    case termFrequencyEntry

    var coreDataEntityName: String {
        switch self {
        case .dictionaryTagMeta:
            "DictionaryTagMeta"
        case .ipaEntry:
            "IPAEntry"
        case .kanjiEntry:
            "KanjiEntry"
        case .kanjiFrequencyEntry:
            "KanjiFrequencyEntry"
        case .pitchAccentEntry:
            "PitchAccentEntry"
        case .termEntry:
            "TermEntry"
        case .termFrequencyEntry:
            "TermFrequencyEntry"
        }
    }
}
