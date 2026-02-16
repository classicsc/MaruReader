// LookupCandidate.swift
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

/// A string candidate for dictionary lookup, along with metadata about its origin.
public struct LookupCandidate: Sendable {
    /// The candidate string to look up.
    public let text: String
    /// The original text from which this candidate was derived.
    public let originalSubstring: String
    /// The preprocessing rule chains that produced this candidate.
    public let preprocessorRules: [[String]]
    /// The deinflection rule chains that produced this candidate.
    public let deinflectionInputRules: [[String]]
    /// The deinflection output rules for matching the `rules` attribute of dictionary entries.
    public let deinflectionOutputRules: [String]

    public init(from text: String) {
        self.text = text
        self.originalSubstring = text
        self.preprocessorRules = []
        self.deinflectionInputRules = []
        self.deinflectionOutputRules = []
    }

    public init(text: String, originalSubstring: String, preprocessorRules: [[String]], deinflectionInputRules: [[String]], deinflectionOutputRules: [String]) {
        self.text = text
        self.originalSubstring = originalSubstring
        self.preprocessorRules = preprocessorRules
        self.deinflectionInputRules = deinflectionInputRules
        self.deinflectionOutputRules = deinflectionOutputRules
    }
}
