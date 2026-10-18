// AnkiNoteServiceDuplicateScopeTests.swift
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

import Foundation
@testable import MaruAnki
import Testing

/// The local record check mirrors how Anki scopes duplicates: by deck (optionally with children) and note type.
struct AnkiNoteServiceDuplicateScopeTests {
    @Test func noteExistsFollowsDuplicateScope() async throws {
        let service = AnkiNoteService(persistence: makeAnkiPersistenceController())
        try await service.recordNote(
            expression: "猫", reading: "ねこ", profileName: "Default",
            deckName: "Japanese::Vocab", modelName: "Basic", fields: [:], ankiID: 1
        )

        func exists(_ scope: DuplicateNoteScope, deck: String? = nil, children: Bool = false, allModels: Bool = false, targetDeck: String = "Japanese::Vocab", model: String = "Basic") async -> Bool {
            await service.noteExists(
                expression: "猫", reading: "ねこ", profileName: "Default",
                deckName: targetDeck, modelName: model,
                options: DuplicateDetectionOptions(scope: scope, deckName: deck, includeChildDecks: children, checkAllModels: allModels)
            )
        }

        #expect(await exists(.deck))
        #expect(await exists(.deck, targetDeck: "Other") == false)
        #expect(await exists(.deck, deck: "Japanese", targetDeck: "Other") == false)
        #expect(await exists(.deck, deck: "Japanese", children: true, targetDeck: "Other"))
        #expect(await exists(.deck, model: "Cloze") == false)
        #expect(await exists(.deck, allModels: true, model: "Cloze"))
        #expect(await exists(.collection, targetDeck: "Other"))
        #expect(await exists(.collection, model: "Cloze") == false)
        #expect(await exists(.none) == false)
    }
}
