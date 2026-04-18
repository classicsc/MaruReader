// UnifiedTokenizerDictionaryManagementRow.swift
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

struct UnifiedTokenizerDictionaryManagementRow: View {
    let tokenizerDictionary: TokenizerDictionary
    let onUpdate: () -> Void

    @State private var isMetadataExpanded = false

    private var hasMetadata: Bool {
        (tokenizerDictionary.version?.isEmpty == false)
            || (tokenizerDictionary.attribution?.isEmpty == false)
            || (tokenizerDictionary.indexURL?.isEmpty == false)
            || (tokenizerDictionary.downloadURL?.isEmpty == false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tokenizerDictionary.name ?? String(localized: "Tokenizer Dictionary"))
                        .font(.headline)
                }
                .transaction { transaction in
                    // Prevent the title text from bouncing when the disclosure group expands/collapses
                    transaction.animation = .none
                }

                Spacer(minLength: 12)

                if tokenizerDictionary.updateReady {
                    Button("Update", action: onUpdate)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if hasMetadata {
                DisclosureGroup("Details", isExpanded: $isMetadataExpanded) {
                    UnifiedTokenizerDictionaryManagementMetadataView(tokenizerDictionary: tokenizerDictionary)
                }
                .font(.caption)
                .tint(.secondary)
                .transaction { transaction in
                    transaction.animation = .none
                }
            }
        }

        .padding(.vertical, 2)
    }
}
