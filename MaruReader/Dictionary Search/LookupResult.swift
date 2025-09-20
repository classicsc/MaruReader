//
//  LookupResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/16/25.
//

import CoreData
import Foundation

/// A result with a term/reading pair and definitions grouped by dictionary.
struct LookupResult: Identifiable {
    /// Unique identifier for the group
    let id: UUID = .init()
    /// Expression to display
    let expression: String
    /// Reading to display
    let reading: String?
    /// The original text before any processing.
    let originalSubstring: String?
    /// Deinflection input rules, if any.
    let deinflectionTransforms: [String]?
    /// Deinflection output rules, if any.
    let deinflectionConditions: [String]?
    /// Preprocessor rules applied, if any.
    let preprocessorRules: [String]?
    /// The frequency ranking of the group, if available
    let frequency: FrequencyRanking?
    /// Definitions grouped by dictionary
    let definitionsByDictionary: [NSManagedObjectID: [Definition]]
}
