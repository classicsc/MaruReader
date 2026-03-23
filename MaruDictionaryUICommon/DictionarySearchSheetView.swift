// DictionarySearchSheetView.swift
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

@MainActor
public struct DictionarySearchSheetView: View {
    let searchText: String
    let contextValues: LookupContextValues
    let accessibilityIdentifier: String
    let onDismiss: () -> Void

    @State private var searchViewModel = DictionarySearchViewModel(resultState: .searching)

    public init(
        searchText: String,
        contextValues: LookupContextValues,
        accessibilityIdentifier: String,
        onDismiss: @escaping () -> Void
    ) {
        self.searchText = searchText
        self.contextValues = contextValues
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            DictionarySearchView()
                .environment(searchViewModel)
                .navigationTitle("Dictionary")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: onDismiss)
                    }
                }
        }
        .onAppear(perform: performSearch)
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func performSearch() {
        searchViewModel.performSearch(
            searchText,
            contextValues: contextValues
        )
    }
}
