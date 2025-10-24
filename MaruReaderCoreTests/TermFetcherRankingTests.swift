//
//  TermFetcherRankingTests.swift
//  MaruReaderTests
//
//  Created by Claude on 9/23/25.
//

@testable import MaruReaderCore
import Testing

struct TermFetcherRankingTests {
    // MARK: - Helper Methods

    private func createLookupCandidate(
        text: String,
        originalSubstring: String,
        preprocessorRules: [[String]] = [],
        deinflectionInputRules: [[String]] = [],
        deinflectionOutputRules: [String] = []
    ) -> LookupCandidate {
        LookupCandidate(
            text: text,
            originalSubstring: originalSubstring,
            preprocessorRules: preprocessorRules,
            deinflectionInputRules: deinflectionInputRules,
            deinflectionOutputRules: deinflectionOutputRules
        )
    }

    // Helper method to create RankingCriteria directly using its initializer
    private func createRankingCriteria(
        sourceTermLength: Int,
        textProcessingChainLength: Int,
        inflectionChainLength: Int,
        deinflectionChainCount: Int,
        frequency: (value: Double?, mode: String?) = (nil, nil),
        dictionaryPriority: Int = 0,
        termScore: Double = 0.0,
        dictionaryTitle: String = "TestDict",
        definitionCount: Int = 1,
        term: String = "食べる"
    ) -> RankingCriteria {
        RankingCriteria(
            sourceTermLength: sourceTermLength,
            textProcessingChainLength: textProcessingChainLength,
            inflectionChainLength: inflectionChainLength,
            deinflectionChainCount: deinflectionChainCount,
            frequencyValue: frequency.value,
            frequencyMode: frequency.mode,
            dictionaryPriority: dictionaryPriority,
            termScore: termScore,
            dictionaryTitle: dictionaryTitle,
            definitionCount: definitionCount,
            term: term
        )
    }
}

// MARK: - Test Cases

extension TermFetcherRankingTests {
    // MARK: - Criterion 1: Source term length

    @Test func sourceTermLengthRanking() {
        let shortCriteria = createRankingCriteria(
            sourceTermLength: 2,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        let longCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        // Longer original substring should rank higher
        #expect(longCriteria > shortCriteria, "Longer source term should rank higher")
    }

    // MARK: - Criterion 2: Text processing chain length

    @Test func textProcessingChainLengthRanking() {
        let noCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        let shortCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 1,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        let longCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 2,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        // Shorter processing chain should rank higher
        #expect(noCriteria > shortCriteria, "No processing should rank higher than short processing")
        #expect(shortCriteria > longCriteria, "Short processing should rank higher than long processing")
    }

    // MARK: - Criterion 3: Inflection chain length

    @Test func inflectionChainLengthRanking() {
        let noCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        let shortCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 1,
            deinflectionChainCount: 1
        )

        let longCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 2,
            deinflectionChainCount: 1
        )

        // Shorter inflection chain should rank higher
        #expect(noCriteria > shortCriteria, "No inflection should rank higher than short inflection")
        #expect(shortCriteria > longCriteria, "Short inflection should rank higher than long inflection")
    }

    // MARK: - Criterion 4: Deinflection chain count

    @Test func deinflectionChainCountRanking() {
        let noCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0
        )

        let oneCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 1
        )

        let multiCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 2
        )

        // Exact matches (no chains) rank highest, then more chains rank higher than fewer chains
        #expect(noCriteria > multiCriteria, "Exact matches should rank higher than any chains")
        #expect(multiCriteria > oneCriteria, "More chains should rank higher than fewer chains")
    }

    // MARK: - Criterion 5: Frequency ranking

    @Test func frequencyRankingOccurrenceBased() {
        let noFreqCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequency: (nil, nil)
        )

        let lowFreqCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequency: (100.0, "occurrence-based")
        )

        let highFreqCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequency: (1000.0, "occurrence-based")
        )

        // Higher occurrence should rank higher
        #expect(highFreqCriteria > lowFreqCriteria, "Higher occurrence should rank higher")
        #expect(lowFreqCriteria > noFreqCriteria, "Any frequency should rank higher than no frequency")
    }

    @Test func frequencyRankingRankBased() {
        let rank1Criteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequency: (1.0, "rank-based") // Lower rank number = better
        )

        let rank10Criteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequency: (10.0, "rank-based")
        )

        // Lower rank number should rank higher
        #expect(rank1Criteria > rank10Criteria, "Lower rank number should rank higher")
    }

    // MARK: - Criterion 6: Dictionary priority

    @Test func dictionaryPriorityRanking() {
        let lowPriorityCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            dictionaryPriority: 1
        )

        let highPriorityCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            dictionaryPriority: 10
        )

        // Higher priority should rank higher
        #expect(highPriorityCriteria > lowPriorityCriteria, "Higher dictionary priority should rank higher")
    }

    // MARK: - Criterion 7: Term score (within same dictionary)

    @Test func termScoreRankingWithinSameDictionary() {
        let lowScoreCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            termScore: 1.0,
            dictionaryTitle: "SameDict"
        )

        let highScoreCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            termScore: 10.0,
            dictionaryTitle: "SameDict"
        )

        // Higher score should rank higher within same dictionary
        #expect(highScoreCriteria > lowScoreCriteria, "Higher term score should rank higher within same dictionary")
    }

    @Test func termScoreIgnoredAcrossDifferentDictionaries() {
        let dict1Criteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            termScore: 1.0,
            dictionaryTitle: "Dict1"
        )

        let dict2Criteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            termScore: 10.0,
            dictionaryTitle: "Dict2"
        )

        // Term scores from different dictionaries should be treated as equal
        // This should fall through to the next criterion (definition count, then term - both same)
        // so they should be equal
        #expect(dict1Criteria == dict2Criteria, "Term scores from different dictionaries should not be compared")
    }

    // MARK: - Criterion 8: Definition count

    @Test func definitionCountRanking() {
        let fewDefsCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            definitionCount: 1
        )

        let manyDefsCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            definitionCount: 5
        )

        // More definitions should rank higher
        #expect(manyDefsCriteria > fewDefsCriteria, "More definitions should rank higher")
    }

    // MARK: - Criterion 9: Lexicographic order

    @Test func lexicographicFallbackRanking() {
        let aaaCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            term: "aaa"
        )

        let zzzCriteria = createRankingCriteria(
            sourceTermLength: 3,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            term: "zzz"
        )

        // Lexicographically earlier term should rank higher (display first)
        #expect(aaaCriteria > zzzCriteria, "Lexicographically earlier term should rank higher")
    }

    // MARK: - Integration test: Multiple criteria

    @Test func multipleCriteriaIntegration() {
        // Test that higher priority criteria override lower priority ones

        // Create two criteria that differ in source term length (criterion 1)
        // but have different dictionary priorities (criterion 6)
        let shortCriteria = createRankingCriteria(
            sourceTermLength: 1, // Short source term
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            dictionaryPriority: 100 // High priority
        )

        let longCriteria = createRankingCriteria(
            sourceTermLength: 3, // Long source term
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            dictionaryPriority: 1 // Low priority
        )

        // Source term length (criterion 1) should override dictionary priority (criterion 6)
        #expect(longCriteria > shortCriteria, "Source term length should override dictionary priority")
    }
}
