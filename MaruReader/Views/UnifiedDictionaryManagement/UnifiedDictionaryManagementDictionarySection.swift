// UnifiedDictionaryManagementDictionarySection.swift
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

import MaruDictionaryManagement
import MaruReaderCore
import SwiftUI

struct UnifiedDictionaryManagementDictionarySection<RankingPicker: View>: View {
    let title: LocalizedStringKey
    let dictionaries: [Dictionary]
    let footer: LocalizedStringKey
    let onStartUpdate: (Dictionary) -> Void
    let onDelete: (Dictionary) -> Void
    let onMove: (IndexSet, Int) -> Void
    @ViewBuilder let rankingPicker: RankingPicker

    var body: some View {
        if !dictionaries.isEmpty {
            Section {
                ForEach(dictionaries, id: \.objectID) { dictionary in
                    UnifiedDictionaryManagementCompletedDictionaryRow(
                        dictionary: dictionary,
                        onUpdate: { onStartUpdate(dictionary) }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(dictionary)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: onMove)

                rankingPicker
            } header: {
                Text(title)
            } footer: {
                Text(footer)
            }
        }
    }

    private func deleteDictionary(at offsets: IndexSet) {
        guard let index = offsets.first, dictionaries.indices.contains(index) else { return }
        onDelete(dictionaries[index])
    }
}

extension UnifiedDictionaryManagementDictionarySection where RankingPicker == EmptyView {
    init(
        title: LocalizedStringKey,
        dictionaries: [Dictionary],
        footer: LocalizedStringKey,
        onStartUpdate: @escaping (Dictionary) -> Void,
        onDelete: @escaping (Dictionary) -> Void,
        onMove: @escaping (IndexSet, Int) -> Void
    ) {
        self.init(
            title: title,
            dictionaries: dictionaries,
            footer: footer,
            onStartUpdate: onStartUpdate,
            onDelete: onDelete,
            onMove: onMove
        ) {
            EmptyView()
        }
    }
}
