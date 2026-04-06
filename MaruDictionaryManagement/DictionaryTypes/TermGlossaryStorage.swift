// TermGlossaryStorage.swift
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

struct TermGlossaryStorage {
    private let decodedDefinitions: [Definition]?
    private let rawGlossaryJSON: Data?
    let definitionCount: Int

    init(definitions: [Definition]) {
        self.decodedDefinitions = definitions
        self.rawGlossaryJSON = nil
        self.definitionCount = definitions.count
    }

    init(glossaryJSON: Data, definitionCount: Int) {
        self.decodedDefinitions = nil
        self.rawGlossaryJSON = glossaryJSON
        self.definitionCount = definitionCount
    }

    func glossary() throws -> [Definition] {
        if let decodedDefinitions {
            return decodedDefinitions
        }

        guard let rawGlossaryJSON else {
            return []
        }

        return try (JSONDecoder().decode([Definition].self, from: rawGlossaryJSON))
    }

    func glossaryJSONData() -> Data {
        if let rawGlossaryJSON {
            return rawGlossaryJSON
        }

        return (try? JSONEncoder().encode(decodedDefinitions ?? [])) ?? Data("[]".utf8)
    }
}
