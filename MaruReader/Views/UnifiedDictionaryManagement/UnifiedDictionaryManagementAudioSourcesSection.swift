// UnifiedDictionaryManagementAudioSourcesSection.swift
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

struct UnifiedDictionaryManagementAudioSourcesSection: View {
    let audioSources: [AudioSource]
    let onDelete: (AudioSource) -> Void
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        if !audioSources.isEmpty {
            Section {
                ForEach(audioSources, id: \.objectID) { audioSource in
                    UnifiedDictionaryManagementCompletedAudioSourceRow(source: audioSource)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(audioSource)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: onMove)
            } header: {
                Text("Audio Sources")
            } footer: {
                Text("Order determines audio lookup priority.")
            }
        }
    }

    private func deleteAudioSource(at offsets: IndexSet) {
        guard let index = offsets.first, audioSources.indices.contains(index) else { return }
        onDelete(audioSources[index])
    }
}
