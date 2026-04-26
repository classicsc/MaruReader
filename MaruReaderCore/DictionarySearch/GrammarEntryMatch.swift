// GrammarEntryMatch.swift
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

public struct GrammarEntryLink: Identifiable, Hashable, Sendable {
    public let dictionaryID: UUID
    public let dictionaryTitle: String
    public let entryID: String
    public let entryTitle: String

    public var id: String {
        "\(dictionaryID)|\(entryID)"
    }

    public init(
        dictionaryID: UUID,
        dictionaryTitle: String,
        entryID: String,
        entryTitle: String
    ) {
        self.dictionaryID = dictionaryID
        self.dictionaryTitle = dictionaryTitle
        self.entryID = entryID
        self.entryTitle = entryTitle
    }
}

public struct GrammarEntryMatch: Identifiable, Hashable, Sendable {
    public let formTag: String
    public let entries: [GrammarEntryLink]

    public var id: String {
        formTag
    }

    public init(formTag: String, entries: [GrammarEntryLink]) {
        self.formTag = formTag
        self.entries = entries
    }
}
