// TagBankV3Entry.swift
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
import MaruReaderCore

struct TagBankV3Entry: DictionaryDataBankEntry {
    let name: String
    let category: String
    let order: Double
    let notes: String
    let score: Double

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 5 else { throw DictionaryImportError.invalidData }
        self.name = try container.decode(String.self)
        self.category = try container.decode(String.self)
        self.order = try container.decode(Double.self)
        self.notes = try container.decode(String.self)
        self.score = try container.decode(Double.self)
    }

    func toDataDictionary(
        dictionaryID: UUID,
        glossaryCompressionVersion _: GlossaryCompressionCodecVersion,
        glossaryCompressionBaseDirectory _: URL?,
        glossaryZSTDCompressionLevel _: Int32? = nil
    ) throws -> (DictionaryDataType, [String: any Sendable]) {
        (
            .dictionaryTagMeta, [
                "id": UUID(),
                "dictionaryID": dictionaryID,
                "name": name,
                "category": category,
                "order": order,
                "notes": notes,
                "score": score,
            ]
        )
    }
}
