//
//  LookupCandidate.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/15/25.
//

/// Struct representing a candidate for dictionary lookup.
struct LookupCandidate {
    /// The text of the candidate.
    let expression: String
    /// The original text before any processing.
    let originalSubstring: String
    /// Deinflection input rules, if any.
    let deinflectionTransforms: [String]?
    /// Deinflection output rules, if any.
    let deinflectionConditions: [String]?
    /// Preprocessor rules applied, if any.
    let preprocessorRules: [String]?
}
