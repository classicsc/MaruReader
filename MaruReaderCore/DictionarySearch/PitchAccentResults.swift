// PitchAccentResults.swift
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

public struct PitchAccentResults: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryID: UUID
    public let priority: Int
    public let pitches: [PitchAccent]

    public var id: String { "\(dictionaryID)" }

    public init(dictionaryTitle: String, dictionaryID: UUID, priority: Int, pitches: [PitchAccent]) {
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryID = dictionaryID
        self.priority = priority
        self.pitches = pitches
    }
}
