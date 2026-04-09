// UnifiedDictionaryManagementCompletedDictionaryRow.swift
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

struct UnifiedDictionaryManagementCompletedDictionaryRow: View {
    let dictionary: Dictionary
    let onUpdate: () -> Void

    @State private var isMetadataExpanded = false

    private var typeDescriptions: [(label: String, systemImage: String)] {
        [
            (
                label: AppLocalization.dictionaryTermsCount(dictionary.termCount),
                systemImage: "textformat",
                isPresent: dictionary.termCount > 0
            ),
            (
                label: AppLocalization.dictionaryKanjiCount(dictionary.kanjiCount),
                systemImage: "character.zh",
                isPresent: dictionary.kanjiCount > 0
            ),
            (
                label: AppLocalization.dictionaryFrequencyCount(dictionary.termFrequencyCount),
                systemImage: "chart.line.uptrend.xyaxis",
                isPresent: dictionary.termFrequencyCount > 0
            ),
            (
                label: AppLocalization.dictionaryKanjiFrequencyCount(dictionary.kanjiFrequencyCount),
                systemImage: "chart.bar",
                isPresent: dictionary.kanjiFrequencyCount > 0
            ),
            (
                label: AppLocalization.dictionaryPitchCount(dictionary.pitchesCount),
                systemImage: "waveform",
                isPresent: dictionary.pitchesCount > 0
            ),
            (
                label: AppLocalization.dictionaryIPACount(dictionary.ipaCount),
                systemImage: "speaker.wave.2",
                isPresent: dictionary.ipaCount > 0
            ),
        ]
        .filter(\.isPresent)
        .map { ($0.label, $0.systemImage) }
    }

    private var hasMetadata: Bool {
        (dictionary.author?.isEmpty == false)
            || (dictionary.attribution?.isEmpty == false)
            || (dictionary.displayDescription?.isEmpty == false)
            || (dictionary.revision?.isEmpty == false)
            || (dictionary.url.flatMap(URL.init(string:)) != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.title ?? AppLocalization.unknownDictionary)
                        .font(.headline)

                    if let sourceLanguage = dictionary.sourceLanguage,
                       let targetLanguage = dictionary.targetLanguage
                    {
                        Text(AppLocalization.languagePair(source: sourceLanguage, target: targetLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let errorMessage = dictionary.errorMessage, !errorMessage.isEmpty {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else {
                            ForEach(typeDescriptions, id: \.label) { item in
                                Label(item.label, systemImage: item.systemImage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .transaction { transaction in
                    // Prevent the title text from bouncing when the disclosure group expands/collapses
                    transaction.animation = .none
                }

                Spacer(minLength: 12)

                if dictionary.updateReady {
                    Button("Update", action: onUpdate)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if hasMetadata {
                DisclosureGroup("Details", isExpanded: $isMetadataExpanded) {
                    UnifiedDictionaryManagementDictionaryMetadataView(dictionary: dictionary)
                }
                .font(.caption)
                .tint(.secondary)
                .transaction { transaction in
                    // Prevent the "Details" text from bouncing when the disclosure group expands/collapses
                    transaction.animation = .none
                }
            }
        }
        .padding(.vertical, 2)
    }
}
