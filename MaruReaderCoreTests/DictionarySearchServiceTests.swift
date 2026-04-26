// DictionarySearchServiceTests.swift
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

import CoreData
import Foundation
@testable import MaruReaderCore
import Testing

struct DictionarySearchServiceTests {
    @Test func groupResults_mergesGrammarMatchesAcrossTermDictionaries() {
        let formTag = "passive"
        let grammarEntry = GrammarEntryLink(
            dictionaryID: UUID(),
            dictionaryTitle: "Grammar",
            entryID: "passive",
            entryTitle: "Passive"
        )
        let resultA = makeSearchResult(
            dictionaryTitle: "TermDictA",
            sequence: 0,
            grammarMatches: [GrammarEntryMatch(formTag: formTag, entries: [grammarEntry])]
        )
        let resultB = makeSearchResult(
            dictionaryTitle: "TermDictB",
            sequence: 1,
            grammarMatches: [GrammarEntryMatch(formTag: formTag, entries: [grammarEntry])]
        )

        let grouped = DictionarySearchService.groupResults([resultA, resultB])

        #expect(grouped.count == 1)
        #expect(grouped[0].grammarMatches.count == 1)
        #expect(grouped[0].grammarMatches[0].formTag == formTag)
        #expect(grouped[0].grammarMatches[0].entries == [grammarEntry])
    }

    @Test func fetchGrammarEntryMap_matchesCompleteGrammarDictionariesByExactFormTag() async throws {
        let persistenceController = makeDictionaryPersistenceController(baseDirectory: nil)
        let writeContext = persistenceController.newBackgroundContext()
        let dictionaryID = UUID()
        let inactiveDictionaryID = UUID()

        try await writeContext.perform {
            let dictionary = GrammarDictionary(context: writeContext)
            dictionary.id = dictionaryID
            dictionary.title = "Grammar"
            dictionary.format = 1
            dictionary.entryCount = 2
            dictionary.formTagCount = 2
            dictionary.isComplete = true
            dictionary.pendingDeletion = false

            let inactiveDictionary = GrammarDictionary(context: writeContext)
            inactiveDictionary.id = inactiveDictionaryID
            inactiveDictionary.title = "Inactive Grammar"
            inactiveDictionary.format = 1
            inactiveDictionary.entryCount = 1
            inactiveDictionary.formTagCount = 1
            inactiveDictionary.isComplete = false
            inactiveDictionary.pendingDeletion = false

            let passiveEntry = GrammarDictionaryEntry(context: writeContext)
            passiveEntry.id = UUID()
            passiveEntry.dictionaryID = dictionaryID
            passiveEntry.entryID = "passive"
            passiveEntry.title = "Passive"
            passiveEntry.path = "passive.md"
            passiveEntry.formTags = "passive\npast"

            let passivePotentialEntry = GrammarDictionaryEntry(context: writeContext)
            passivePotentialEntry.id = UUID()
            passivePotentialEntry.dictionaryID = dictionaryID
            passivePotentialEntry.entryID = "passive-potential"
            passivePotentialEntry.title = "Passive Potential"
            passivePotentialEntry.path = "passive-potential.md"
            passivePotentialEntry.formTags = "passive/potential"

            let inactiveEntry = GrammarDictionaryEntry(context: writeContext)
            inactiveEntry.id = UUID()
            inactiveEntry.dictionaryID = inactiveDictionaryID
            inactiveEntry.entryID = "inactive"
            inactiveEntry.title = "Inactive"
            inactiveEntry.path = "inactive.md"
            inactiveEntry.formTags = "passive"

            try writeContext.save()
        }

        let backgroundContext = persistenceController.newBackgroundContext()
        let map = try await TermFetcher.fetchGrammarEntryMap(
            formTags: ["passive"],
            context: backgroundContext
        )

        #expect(map["passive"] == [
            GrammarEntryLink(
                dictionaryID: dictionaryID,
                dictionaryTitle: "Grammar",
                entryID: "passive",
                entryTitle: "Passive"
            ),
        ])
    }

    @Test func groupResults_deduplicatesPitchAccentsAcrossTermDictionaries() {
        let candidate = LookupCandidate(from: "neko")
        let pitchDictionaryID = UUID()
        let pitch = PitchAccent(position: .mora(1))
        let pitchResults = [
            PitchAccentResults(dictionaryTitle: "PitchDict", dictionaryID: pitchDictionaryID, priority: 0, pitches: [pitch]),
        ]

        let definitions: [Definition] = [.text("definition")]

        let rankingA = RankingCriteria(
            sourceTermLength: 4,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "TermDictA",
            definitionCount: definitions.count,
            term: "neko"
        )

        let rankingB = RankingCriteria(
            sourceTermLength: 4,
            textProcessingChainLength: 0,
            inflectionChainLength: 0,
            deinflectionChainCount: 0,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: "TermDictB",
            definitionCount: definitions.count,
            term: "猫"
        )

        let resultA = SearchResult(
            candidate: candidate,
            term: "neko",
            reading: "neko",
            definitions: definitions,
            frequency: nil,
            frequencies: [],
            pitchAccents: pitchResults,
            dictionaryTitle: "TermDictA",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: rankingA,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 0,
            score: 0
        )

        let resultB = SearchResult(
            candidate: candidate,
            term: "neko",
            reading: "neko",
            definitions: definitions,
            frequency: nil,
            frequencies: [],
            pitchAccents: pitchResults,
            dictionaryTitle: "TermDictB",
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: rankingB,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [],
            sequence: 1,
            score: 0
        )

        let grouped = DictionarySearchService.groupResults([resultA, resultB])

        #expect(grouped.count == 1)
        #expect(grouped[0].pitchAccentResults.count == 1)
        #expect(grouped[0].pitchAccentResults.first?.pitches.count == 1)
        #expect(grouped[0].pitchAccentResults.first?.dictionaryID == pitchDictionaryID)
    }

    @Test func groupMatches_prefersLongerGeneratedTermFromSameSourceSubstring() {
        let dictionaryID = UUID()
        let source = "住んでいる"
        let sumuPath = LookupCandidateDeconjugation(
            process: ["teiru", "(te form)", "(unstressed infinitive)"],
            tags: ["v1", "stem-te", "stem-te-verbal", "stem-ren-less-v", "v5m"],
            priority: 3
        )
        let overStrippedPath = LookupCandidateDeconjugation(
            process: ["teiru", "(te form)", "slurred negative"],
            tags: ["v1", "stem-te", "adj-i", "stem-mizenkei"],
            priority: 3
        )
        let sumuCandidate = LookupCandidate(
            text: "住む",
            originalSubstring: source,
            preprocessorRules: [],
            deconjugationPaths: [sumuPath]
        )
        let shortCandidate = LookupCandidate(
            text: "住",
            originalSubstring: source,
            preprocessorRules: [],
            deconjugationPaths: [overStrippedPath]
        )
        let sumuRanking = RankingCriteria(
            candidate: sumuCandidate,
            validatedDeconjugationPaths: [sumuPath],
            term: "住む",
            termScore: 0,
            definitionCount: 1,
            frequency: (nil, nil),
            dictionaryTitle: "TermDict",
            dictionaryPriority: 0
        )
        let shortRanking = RankingCriteria(
            candidate: shortCandidate,
            validatedDeconjugationPaths: [overStrippedPath],
            term: "住",
            termScore: 0,
            definitionCount: 1,
            frequency: (nil, nil),
            dictionaryTitle: "TermDict",
            dictionaryPriority: 0
        )
        let shortMatch = makeTermMatch(
            candidate: shortCandidate,
            term: "住",
            dictionaryID: dictionaryID,
            rankingCriteria: shortRanking,
            deconjugationPath: overStrippedPath
        )
        let sumuMatch = makeTermMatch(
            candidate: sumuCandidate,
            term: "住む",
            dictionaryID: dictionaryID,
            rankingCriteria: sumuRanking,
            deconjugationPath: sumuPath
        )

        let grouped = DictionarySearchService.groupMatches([shortMatch, sumuMatch])

        #expect(grouped.first?.expression == "住む")
    }

    private func makeTermMatch(
        candidate: LookupCandidate,
        term: String,
        dictionaryID: UUID,
        rankingCriteria: RankingCriteria,
        deconjugationPath: LookupCandidateDeconjugation
    ) -> TermMatch {
        TermMatch(
            candidate: candidate,
            term: term,
            reading: nil,
            glossaryData: Data(),
            definitionCount: 1,
            rankingFrequency: nil,
            dictionaryTitle: "TermDict",
            dictionaryUUID: dictionaryID,
            displayPriority: 0,
            rankingCriteria: rankingCriteria,
            termTagsRaw: nil,
            definitionTagsRaw: nil,
            deinflectionRules: [deconjugationPath.process],
            deconjugationPaths: [deconjugationPath],
            sequence: 0,
            score: 0
        )
    }

    private func makeSearchResult(
        dictionaryTitle: String,
        sequence: Int64,
        grammarMatches: [GrammarEntryMatch]
    ) -> SearchResult {
        let candidate = LookupCandidate(from: "taberareru")
        let definitions: [Definition] = [.text("definition")]
        let ranking = RankingCriteria(
            sourceTermLength: 10,
            textProcessingChainLength: 0,
            inflectionChainLength: 1,
            deinflectionChainCount: 1,
            frequencyValue: nil,
            frequencyMode: nil,
            dictionaryPriority: 0,
            termScore: 0,
            dictionaryTitle: dictionaryTitle,
            definitionCount: definitions.count,
            term: "食べる"
        )

        return SearchResult(
            candidate: candidate,
            term: "食べる",
            reading: "たべる",
            definitions: definitions,
            frequency: nil,
            frequencies: [],
            pitchAccents: [],
            dictionaryTitle: dictionaryTitle,
            dictionaryUUID: UUID(),
            displayPriority: 0,
            rankingCriteria: ranking,
            termTags: [],
            definitionTags: [],
            deinflectionRules: [["passive"]],
            grammarMatches: grammarMatches,
            sequence: sequence,
            score: 0
        )
    }
}
