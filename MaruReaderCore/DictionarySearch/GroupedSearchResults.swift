// GroupedSearchResults.swift
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

public struct GroupedSearchResults: Identifiable, Sendable {
    public let termKey: String
    public let expression: String
    public let reading: String?
    public let dictionariesResults: [DictionaryResults]
    public let pitchAccentResults: [PitchAccentResults]
    public let termTags: [Tag]
    public let deinflectionInfo: String?
    public let deinflectionInfoHTML: String?

    public var id: String {
        termKey
    }

    public var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }

    public init(
        termKey: String,
        expression: String,
        reading: String?,
        dictionariesResults: [DictionaryResults],
        pitchAccentResults: [PitchAccentResults],
        termTags: [Tag],
        deinflectionInfo: String?,
        deinflectionInfoHTML: String? = nil
    ) {
        self.termKey = termKey
        self.expression = expression
        self.reading = reading
        self.dictionariesResults = dictionariesResults
        self.pitchAccentResults = pitchAccentResults
        self.termTags = termTags
        self.deinflectionInfo = deinflectionInfo
        self.deinflectionInfoHTML = deinflectionInfoHTML
    }
}
