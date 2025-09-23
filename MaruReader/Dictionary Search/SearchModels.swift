//
//  SearchModels.swift
//  MaruReader
//
//  Data models for dictionary search functionality.
//

import Foundation

// MARK: - SearchQuery

/// Parameters for a dictionary search operation
struct SearchQuery: Sendable {
    /// The original text to search for
    let text: String
    /// Maximum depth for deinflection processing
    let maxDeinflectionDepth: Int
    /// Maximum number of text preprocessing variants
    let maxPreprocessorVariants: Int
    /// Limit on number of results to return
    let resultLimit: Int?
    /// Whether to include disabled dictionaries in results
    let includeDisabledDictionaries: Bool

    init(
        text: String,
        maxDeinflectionDepth: Int = 10,
        maxPreprocessorVariants: Int = 5,
        resultLimit: Int? = nil,
        includeDisabledDictionaries: Bool = false
    ) {
        self.text = text
        self.maxDeinflectionDepth = maxDeinflectionDepth
        self.maxPreprocessorVariants = maxPreprocessorVariants
        self.resultLimit = resultLimit
        self.includeDisabledDictionaries = includeDisabledDictionaries
    }
}

// MARK: - SearchResult

/// A ranked dictionary search result containing a term and its matching entries
struct SearchResult: Sendable, Identifiable {
    let id = UUID()

    /// The matched term
    let term: TermDTO
    /// Enabled entries for this term, sorted by display priority
    let entries: [TermEntryDTO]
    /// The lookup candidate that matched this term
    let matchingCandidate: LookupCandidate
    /// Frequency information for ranking
    let frequencyEntries: [TermFrequencyEntryDTO]
    /// Combined ranking score (lower is better)
    let rankingScore: Double

    // MARK: - Ranking Components

    /// Length of the original substring that produced this result
    let sourceTermLength: Int
    /// Total length of text processing chains
    let processingChainLength: Int
    /// Total length of deinflection chains
    let deinflectionChainLength: Int
    /// Whether this candidate exactly matches a deinflection
    let hasExactMatch: Bool
    /// Best frequency score from enabled frequency entries
    let frequencyScore: Double?
    /// Dictionary display priority (higher is better)
    let dictionaryPriority: Int64
    /// Term score from dictionary (higher is better)
    let termScore: Double

    init(
        term: TermDTO,
        entries: [TermEntryDTO],
        matchingCandidate: LookupCandidate,
        frequencyEntries: [TermFrequencyEntryDTO],
        rankingScore: Double,
        sourceTermLength: Int,
        processingChainLength: Int,
        deinflectionChainLength: Int,
        hasExactMatch: Bool,
        frequencyScore: Double?,
        dictionaryPriority: Int64,
        termScore: Double
    ) {
        self.term = term
        self.entries = entries
        self.matchingCandidate = matchingCandidate
        self.frequencyEntries = frequencyEntries
        self.rankingScore = rankingScore
        self.sourceTermLength = sourceTermLength
        self.processingChainLength = processingChainLength
        self.deinflectionChainLength = deinflectionChainLength
        self.hasExactMatch = hasExactMatch
        self.frequencyScore = frequencyScore
        self.dictionaryPriority = dictionaryPriority
        self.termScore = termScore
    }
}

// MARK: - RankingContext

/// Context information used for calculating search result rankings
struct RankingContext: Sendable {
    /// All enabled dictionaries with their frequency modes
    let enabledDictionaries: [DictionaryDTO]
    /// Mapping of dictionary ID to frequency mode
    let frequencyModes: [UUID: String]

    init(enabledDictionaries: [DictionaryDTO]) {
        self.enabledDictionaries = enabledDictionaries
        self.frequencyModes = Swift.Dictionary(
            uniqueKeysWithValues: enabledDictionaries.compactMap { dict in
                guard let mode = dict.frequencyMode else { return nil }
                return (dict.id, mode)
            }
        )
    }
}

// MARK: - SearchProgress

/// Progress information for ongoing search operations
struct SearchProgress: Sendable {
    /// Current substring being processed
    let currentSubstring: String
    /// Number of candidates generated so far
    let candidatesGenerated: Int
    /// Number of database queries completed
    let queriesCompleted: Int
    /// Number of results found so far
    let resultsFound: Int
    /// Whether the search is complete
    let isComplete: Bool

    init(
        currentSubstring: String,
        candidatesGenerated: Int = 0,
        queriesCompleted: Int = 0,
        resultsFound: Int = 0,
        isComplete: Bool = false
    ) {
        self.currentSubstring = currentSubstring
        self.candidatesGenerated = candidatesGenerated
        self.queriesCompleted = queriesCompleted
        self.resultsFound = resultsFound
        self.isComplete = isComplete
    }
}
