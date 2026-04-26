// GrammarDictionaryIndex.swift
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

struct GrammarDictionaryIndex: Decodable {
    static let packageType = "maru-grammar-dictionary"
    static let supportedFormat = 1

    let type: String
    let format: Int
    let title: String
    let revision: String?
    let author: String?
    let attribution: String?
    let description: String?
    let license: String?
    let indexUrl: String?
    let downloadUrl: String?
    let isUpdatable: Bool?
    let entries: [GrammarDictionaryIndexEntry]
    let formTags: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case type
        case format
        case title
        case revision
        case author
        case attribution
        case description
        case license
        case indexUrl
        case downloadUrl
        case isUpdatable
        case entries
        case formTags
    }
}

struct GrammarDictionaryIndexEntry: Decodable {
    let id: String
    let title: String
    let path: String
    let summary: String?
}
