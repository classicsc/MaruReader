// TermFetcherTests.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
@testable import MaruReaderCore
import Testing

struct TermFetcherTests {
    @Test func performFetch_multipleMatchingCandidates_decodesGlossaryOncePerEntry() async throws {
        let persistenceController = DictionaryPersistenceController(inMemory: true)
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
