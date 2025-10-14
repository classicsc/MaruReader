//
//  TagBankV3Entry.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/7/25.
//

import Foundation

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

    func toDataDictionary(dictionaryID: UUID) -> (DictionaryDataType, [String: any Sendable]) {
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
