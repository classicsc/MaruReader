//
//  LookupCandidate.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/22/25.
//

/// A string candidate for dictionary lookup, along with metadata about its origin.
struct LookupCandidate {
    /// The candidate string to look up.
    let text: String
    /// The original text from which this candidate was derived.
    let originalSubstring: String
    /// The preprocessing rule chains that produced this candidate.
    let preprocessorRules: [[String]]
    /// The deinflection rule chains that produced this candidate.
    let deinflectionInputRules: [[String]]
    /// The deinflection output rules for matching the `rules` attribute of dictionary entries.
    let deinflectionOutputRules: [String]

    init(from text: String) {
        self.text = text
        self.originalSubstring = text
        self.preprocessorRules = []
        self.deinflectionInputRules = []
        self.deinflectionOutputRules = []
    }

    init(text: String, originalSubstring: String, preprocessorRules: [[String]], deinflectionInputRules: [[String]], deinflectionOutputRules: [String]) {
        self.text = text
        self.originalSubstring = originalSubstring
        self.preprocessorRules = preprocessorRules
        self.deinflectionInputRules = deinflectionInputRules
        self.deinflectionOutputRules = deinflectionOutputRules
    }
}
