// DictionaryDataBankEntry.swift
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
