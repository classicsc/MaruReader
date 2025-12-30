//
//  LookupCandidate.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/22/25.
//

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
