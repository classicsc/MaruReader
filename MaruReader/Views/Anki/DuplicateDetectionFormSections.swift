// DuplicateDetectionFormSections.swift
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

import MaruAnki
import SwiftUI

struct DuplicateDetectionFormSections: View {
    @Binding var duplicateScope: DuplicateNoteScope
    @Binding var duplicateDeckName: String?
    @Binding var duplicateIncludeChildDecks: Bool
    @Binding var duplicateCheckAllModels: Bool
    let decks: [AnkiDeckMeta]
    let selectedDeckName: String?

    var body: some View {
        Section {
            Picker("Duplicate Check Scope", selection: $duplicateScope) {
                Text("Allow Duplicates").tag(DuplicateNoteScope.none)
                Text("Check in Deck").tag(DuplicateNoteScope.deck)
                Text("Check Entire Collection").tag(DuplicateNoteScope.collection)
            }
        } footer: {
            switch duplicateScope {
            case .none:
                Text("Duplicate notes will be created without warning.")
            case .deck:
                Text("Notes with matching content in the specified deck will be rejected.")
            case .collection:
                Text("Notes with matching content anywhere in your collection will be rejected.")
            @unknown default:
                EmptyView()
            }
        }

        if duplicateScope == .deck {
            Section {
                Picker("Deck", selection: $duplicateDeckName) {
                    Text("Target Deck (\(selectedDeckName ?? ""))").tag(nil as String?)
                    ForEach(decks, id: \.name) { deck in
                        Text(deck.name).tag(deck.name as String?)
                    }
                }

                Toggle("Include Child Decks", isOn: $duplicateIncludeChildDecks)
            } header: {
                Text("Deck to Check")
            } footer: {
                Text("When enabled, child decks of the selected deck will also be checked for duplicates.")
            }
        }

        Section {
            Toggle("Check All Note Types", isOn: $duplicateCheckAllModels)
        } footer: {
            if duplicateCheckAllModels {
                Text("Duplicates will be detected across all note types in your collection.")
            } else {
                Text("Only notes of the same type will be checked for duplicates.")
            }
        }
    }
}
