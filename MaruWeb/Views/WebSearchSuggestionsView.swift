// WebSearchSuggestionsView.swift
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

import SwiftUI

struct WebSearchSuggestionsView: View {
    let suggestions: [String]
    let isLoading: Bool
    let onSelect: (String) -> Void

    var body: some View {
        let enumeratedSuggestions = Array(suggestions.enumerated())

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(enumeratedSuggestions, id: \.offset) { index, suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text(suggestion)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    if index < suggestions.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .overlay {
            if suggestions.isEmpty, isLoading {
                ProgressView()
            }
        }
    }
}
