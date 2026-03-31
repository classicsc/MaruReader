// TermFetcherTests.swift
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

struct TermFetcherTests {
    @Test func performFetch_multipleMatchingCandidates_decodesGlossaryOncePerEntry() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let dictionaryID = UUID()
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            let termEntry = TermEntry(context: context)
            termEntry.id = UUID()
            termEntry.dictionaryID = dictionaryID
            termEntry.expression = "食べる"
            termEntry.reading = "たべる"
            termEntry.definitionTags = "[]"
            termEntry.termTags = "[]"
            termEntry.rules = "[]"
            termEntry.score = 100
            termEntry.sequence = 1

            let glossaryJSON = try JSONEncoder().encode([Definition.text("to eat")])
            termEntry.glossary = GlossaryCompressionCodec.encodeGlossaryJSON(glossaryJSON)

            try context.save()
        }

        let dictionaryMetadata: [UUID: DictionaryMetadata] = [
            dictionaryID: DictionaryMetadata(
                id: dictionaryID,
                title: "Test Dictionary",
                termDisplayPriority: 0,
                termFrequencyDisplayPriority: 0,
                pitchDisplayPriority: 0,
                frequencyMode: nil,
                termResultsEnabled: true,
                termFrequencyEnabled: false,
                pitchAccentEnabled: false
            ),
        ]

        let candidates = [
            LookupCandidate(from: "食べる"),
            LookupCandidate(from: "たべる"),
        ]

        let decodeCounter = DecodeCounter()
        let fetchContext = persistenceController.newBackgroundContext()
        let results = try await TermFetcher.performFetch(
            candidates: candidates,
            dictionaryMetadata: dictionaryMetadata,
            context: fetchContext,
            decodeDefinitions: { payload in
                decodeCounter.increment()
                return GlossaryCompressionCodec.decodeDefinitions(from: payload)
            }
        )

        #expect(decodeCounter.value == 1)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.term == "食べる" })
    }

    @Test func performFetch_usesExactTermReadingPairsForFrequencyAndPitchAccentMetadata() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let dictionaryID = UUID()
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "A",
                reading: "a",
                definition: "definition A",
                sequence: 1
            )
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "B",
                reading: "b",
                definition: "definition B",
                sequence: 2
            )

            insertFrequencyEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "A",
                reading: "a",
                value: 10
            )
            insertFrequencyEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "B",
                reading: "b",
                value: 20
            )
            insertFrequencyEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "A",
                reading: "b",
                value: 999
            )
            insertFrequencyEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "B",
                reading: "a",
                value: 999
            )

            try insertPitchAccentEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "A",
                reading: "a",
                positions: [1]
            )
            try insertPitchAccentEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "B",
                reading: "b",
                positions: [2]
            )
            try insertPitchAccentEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "A",
                reading: "b",
                positions: [9]
            )
            try insertPitchAccentEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "B",
                reading: "a",
                positions: [9]
            )

            try context.save()
        }

        let candidates = [
            LookupCandidate(from: "A"),
            LookupCandidate(from: "B"),
        ]

        let fetchContext = persistenceController.newBackgroundContext()
        let results = try await TermFetcher.performFetch(
            candidates: candidates,
            dictionaryMetadata: makeDictionaryMetadata(dictionaryID: dictionaryID),
            context: fetchContext
        )

        #expect(results.count == 2)

        let resultA = try #require(results.first(where: { $0.term == "A" }))
        #expect(resultA.reading == "a")
        #expect(resultA.frequency == 10.0)
        #expect(resultA.frequencies.count == 1)
        #expect(resultA.frequencies.map(\.value) == [10.0])
        #expect(resultA.pitchAccents.count == 1)
        let pitchA = try #require(resultA.pitchAccents.first)
        let accentA = try #require(pitchA.pitches.first)
        switch accentA.position {
        case let .mora(position):
            #expect(position == 1)
        case .pattern:
            #expect(Bool(false), "Expected mora pitch accent for A")
        }

        let resultB = try #require(results.first(where: { $0.term == "B" }))
        #expect(resultB.reading == "b")
        #expect(resultB.frequency == 20.0)
        #expect(resultB.frequencies.count == 1)
        #expect(resultB.frequencies.map(\.value) == [20.0])
        #expect(resultB.pitchAccents.count == 1)
        let pitchB = try #require(resultB.pitchAccents.first)
        let accentB = try #require(pitchB.pitches.first)
        switch accentB.position {
        case let .mora(position):
            #expect(position == 2)
        case .pattern:
            #expect(Bool(false), "Expected mora pitch accent for B")
        }
    }

    @Test func performFetch_dedupedPairBatchingPreservesDuplicateTermEntries() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let dictionaryID = UUID()
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "重複",
                reading: "ちょうふく",
                definition: "duplicate one",
                sequence: 1
            )
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "重複",
                reading: "ちょうふく",
                definition: "duplicate two",
                sequence: 2
            )
            insertFrequencyEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "重複",
                reading: "ちょうふく",
                value: 42
            )
            try insertPitchAccentEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "重複",
                reading: "ちょうふく",
                positions: [3]
            )

            try context.save()
        }

        let fetchContext = persistenceController.newBackgroundContext()
        let results = try await TermFetcher.performFetch(
            candidates: [LookupCandidate(from: "重複")],
            dictionaryMetadata: makeDictionaryMetadata(dictionaryID: dictionaryID),
            context: fetchContext
        )

        #expect(results.count == 2)
        #expect(Set(results.map(\.sequence)) == Set<Int64>([1, 2]))
        #expect(results.allSatisfy { $0.term == "重複" })
        #expect(results.allSatisfy { $0.reading == "ちょうふく" })
        #expect(results.allSatisfy { $0.frequency == 42.0 })
        #expect(results.allSatisfy { $0.frequencies.map(\.value) == [42.0] })
        #expect(results.allSatisfy { $0.pitchAccents.count == 1 })
        #expect(results.allSatisfy { $0.pitchAccents.first?.pitches.count == 1 })
    }

    @Test func performFetch_matchesHierarchicalRulesAndRanksUsingValidatedChains() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let dictionaryID = UUID()
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "行く",
                reading: "いく",
                definition: "to go",
                sequence: 1,
                rules: ["v5"]
            )
            try context.save()
        }

        let candidate = LookupCandidate(
            text: "行く",
            originalSubstring: "行きましょう",
            preprocessorRules: [[]],
            deinflectionInputRules: [["continuative"], ["volitional", "-ます"]],
            deinflectionOutputRulesPerChain: [["v1d"], ["v5d"]]
        )

        let fetchContext = persistenceController.newBackgroundContext()
        let results = try await TermFetcher.performFetch(
            candidates: [candidate],
            dictionaryMetadata: makeDictionaryMetadata(dictionaryID: dictionaryID),
            context: fetchContext
        )

        #expect(results.count == 1)

        let result = try #require(results.first)
        #expect(result.deinflectionRules == [["volitional", "-ます"]])
        #expect(result.rankingCriteria.inflectionChainLength == 2)
        #expect(result.rankingCriteria.deinflectionChainCount == 1)
    }

    @Test func performFetch_prefersLongerSourceChainForGroupedDeinflectionDisplay() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let dictionaryID = UUID()
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            try insertTermEntry(
                in: context,
                dictionaryID: dictionaryID,
                expression: "行く",
                reading: "いく",
                definition: "to go",
                sequence: 1,
                rules: ["v5"]
            )
            try context.save()
        }

        let generator = DictionaryCandidateGenerator()
        let candidates = generator.generateCandidates(from: "行きましょう")

        let fetchContext = persistenceController.newBackgroundContext()
        let results = try await TermFetcher.performFetch(
            candidates: candidates,
            dictionaryMetadata: makeDictionaryMetadata(dictionaryID: dictionaryID),
            context: fetchContext
        )

        let grouped = DictionarySearchService.groupResults(results)

        #expect(grouped.count == 1)
        let firstGroup = try #require(grouped.first)
        #expect(firstGroup.expression == "行く")
        #expect(firstGroup.deinflectionInfo == "volitional → -ます")
    }

    private func makeDictionaryMetadata(dictionaryID: UUID) -> [UUID: DictionaryMetadata] {
        [
            dictionaryID: DictionaryMetadata(
                id: dictionaryID,
                title: "Test Dictionary",
                termDisplayPriority: 0,
                termFrequencyDisplayPriority: 0,
                pitchDisplayPriority: 0,
                frequencyMode: "rank-based",
                termResultsEnabled: true,
                termFrequencyEnabled: true,
                pitchAccentEnabled: true
            ),
        ]
    }

    private func insertTermEntry(
        in context: NSManagedObjectContext,
        dictionaryID: UUID,
        expression: String,
        reading: String,
        definition: String,
        sequence: Int64,
        rules: [String] = []
    ) throws {
        let termEntry = TermEntry(context: context)
        termEntry.id = UUID()
        termEntry.dictionaryID = dictionaryID
        termEntry.expression = expression
        termEntry.reading = reading
        termEntry.definitionTags = "[]"
        termEntry.termTags = "[]"
        termEntry.rules = try String(data: JSONEncoder().encode(rules), encoding: .utf8)
        termEntry.score = 100
        termEntry.sequence = sequence

        let glossaryJSON = try JSONEncoder().encode([Definition.text(definition)])
        termEntry.glossary = GlossaryCompressionCodec.encodeGlossaryJSON(glossaryJSON)
    }

    private func insertFrequencyEntry(
        in context: NSManagedObjectContext,
        dictionaryID: UUID,
        expression: String,
        reading: String,
        value: Double
    ) {
        let entry = TermFrequencyEntry(context: context)
        entry.id = UUID()
        entry.dictionaryID = dictionaryID
        entry.expression = expression
        entry.reading = reading
        entry.value = value
        entry.displayValue = nil
    }

    private func insertPitchAccentEntry(
        in context: NSManagedObjectContext,
        dictionaryID: UUID,
        expression: String,
        reading: String,
        positions: [Int]
    ) throws {
        let entry = PitchAccentEntry(context: context)
        entry.id = UUID()
        entry.dictionaryID = dictionaryID
        entry.expression = expression
        entry.reading = reading
        entry.pitches = try String(
            data: JSONEncoder().encode(positions.map { PitchAccent(position: .mora($0)) }),
            encoding: .utf8
        )
    }
}

private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func increment() {
        lock.lock()
        storedValue += 1
        lock.unlock()
    }
}
