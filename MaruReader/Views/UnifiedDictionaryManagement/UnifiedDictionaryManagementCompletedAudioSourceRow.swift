// UnifiedDictionaryManagementCompletedAudioSourceRow.swift
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

struct UnifiedDictionaryManagementCompletedAudioSourceRow: View {
    let source: AudioSource

    @State private var isMetadataExpanded = false

    private var typeDescription: String {
        if source.indexedByHeadword {
            return source.isLocal ? String(localized: "Indexed (Local ZIP)") : String(localized: "Indexed (Online)")
        }

        if source.urlPatternReturnsJSON {
            return String(localized: "URL Pattern (JSON)")
        }

        return String(localized: "URL Pattern")
    }

    private var hasMetadata: Bool {
        (source.attribution?.isEmpty == false)
            || (source.urlPattern?.isEmpty == false)
            || (source.baseRemoteURL?.isEmpty == false)
            || (source.audioFileExtensions?.isEmpty == false)
            || (source.isLocal && source.file != nil)
            || source.version > 0
            || source.year > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: source.name ?? AppLocalization.unknownSource)
                    .font(.headline)

                Text(typeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .transaction { transaction in
                // Prevent the title text from bouncing when the disclosure group expands/collapses
                transaction.animation = .none
            }

            if hasMetadata {
                DisclosureGroup("Details", isExpanded: $isMetadataExpanded) {
                    UnifiedDictionaryManagementAudioSourceMetadataView(source: source)
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
