// UnifiedGrammarDictionaryManagementRow.swift
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

import MaruReaderCore
import SwiftUI

struct UnifiedGrammarDictionaryManagementRow: View {
    let grammarDictionary: GrammarDictionary

    @State private var isMetadataExpanded = false

    private var hasMetadata: Bool {
        (grammarDictionary.author?.isEmpty == false)
            || (grammarDictionary.attribution?.isEmpty == false)
            || (grammarDictionary.license?.isEmpty == false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(grammarDictionary.title ?? String(localized: "Unknown Grammar Dictionary"))
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(grammarDictionary.entryCount.formatted()) entries", systemImage: "doc.text")
                Label("\(grammarDictionary.formTagCount.formatted()) form tags", systemImage: "tag")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if hasMetadata {
                DisclosureGroup("Details", isExpanded: $isMetadataExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let author = grammarDictionary.author, !author.isEmpty {
                            UnifiedDictionaryManagementMetadataField("Author", value: author)
                        }

                        if let attribution = grammarDictionary.attribution, !attribution.isEmpty {
                            UnifiedDictionaryManagementMetadataField("Attribution", value: attribution)
                        }

                        if let license = grammarDictionary.license, !license.isEmpty {
                            UnifiedDictionaryManagementMetadataField("License", value: license)
                        }
                    }
                    .font(.caption)
                    .padding(.top, 4)
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
