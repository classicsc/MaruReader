// TokenizerDictionaryIndex.swift
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

struct TokenizerDictionaryIndex: Codable {
    static let supportedFormat = 1
    static let packageType = "tokenizer-dictionary"

    let type: String
    let format: Int
    let name: String
    let version: String
    let isUpdatable: Bool
    let attribution: String?
    let indexUrl: String?
    let downloadUrl: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case format
        case name
        case version
        case isUpdatable
        case attribution
        case indexUrl
        case downloadUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let format = try container.decode(Int.self, forKey: .format)
        let name = try container.decode(String.self, forKey: .name)
        let version = try container.decode(String.self, forKey: .version)
        let isUpdatable = try container.decode(Bool.self, forKey: .isUpdatable)
        let attribution = try container.decodeIfPresent(String.self, forKey: .attribution)
        let indexUrl = try container.decodeIfPresent(String.self, forKey: .indexUrl)
        let downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)

        guard type == Self.packageType else {
            throw TokenizerDictionaryImportError.notATokenizerDictionary
        }
        guard format == Self.supportedFormat else {
            throw TokenizerDictionaryImportError.unsupportedFormat
        }
        guard !name.isEmpty, !version.isEmpty else {
            throw TokenizerDictionaryImportError.invalidData
        }
        if isUpdatable, indexUrl == nil || downloadUrl == nil {
            throw TokenizerDictionaryImportError.invalidData
        }

        self.type = type
        self.format = format
        self.name = name
        self.version = version
        self.isUpdatable = isUpdatable
        self.attribution = attribution
        self.indexUrl = indexUrl
        self.downloadUrl = downloadUrl
    }
}
