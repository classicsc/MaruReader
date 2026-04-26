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
public struct LookupCandidateDeconjugation: Sendable, Hashable {
    public let process: [String]
    public let tags: [String]
    public let priority: Int

    public init(process: [String], tags: [String], priority: Int) {
        self.process = process
        self.tags = tags
        self.priority = priority
    }
}

public struct LookupCandidate: Sendable {
    /// The candidate string to look up.
    public let text: String
    /// The original text from which this candidate was derived.
    public let originalSubstring: String
    /// The preprocessing rule chains that produced this candidate.
    public let preprocessorRules: [[String]]
    /// The deconjugation paths that produced this candidate.
    public let deconjugationPaths: [LookupCandidateDeconjugation]

    public init(from text: String) {
        self.text = text
        self.originalSubstring = text
        self.preprocessorRules = []
        self.deconjugationPaths = []
    }

    public init(
        text: String,
        originalSubstring: String,
        preprocessorRules: [[String]],
        deconjugationPaths: [LookupCandidateDeconjugation]
    ) {
        self.text = text
        self.originalSubstring = originalSubstring
        self.preprocessorRules = preprocessorRules
        self.deconjugationPaths = deconjugationPaths
    }
}
