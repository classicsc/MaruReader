// MecabIPADicDictionary.swift
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

internal import Dictionary
import Foundation

private enum MecabIPADicDictionaryError: LocalizedError {
    case missingBundledDictionary

    var errorDescription: String? {
        switch self {
        case .missingBundledDictionary:
            "Bundled IPADic directory was not found in MaruReaderCore resources."
        }
    }
}

struct MecabIPADicDictionary: DictionaryProviding {
    let url: URL

    init(bundle: Bundle = .framework) throws {
        guard let url = bundle.url(forResource: "ipadic dictionary", withExtension: nil) else {
            throw MecabIPADicDictionaryError.missingBundledDictionary
        }
        self.url = url
    }

    var dictionaryFormIndex: Int {
        6
    }

    var readingIndex: Int {
        7
    }

    var pronunciationIndex: Int {
        8
    }

    func partOfSpeech(posID: UInt16) -> PartOfSpeech {
        switch posID {
        case 3 ... 9:
            .symbol
        case 10 ... 12:
            .adverb
        case 13 ... 24:
            .particle
        case 27 ... 30:
            .prefix
        case 31 ... 33:
            .verb
        case 34 ... 35:
            .adverb
        case 36 ... 67:
            .noun
        default:
            .unknown
        }
    }
}
