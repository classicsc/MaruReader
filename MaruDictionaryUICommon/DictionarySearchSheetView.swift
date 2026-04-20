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

    @Environment(\.dictionaryFeatureAvailability) private var availability
    @State private var searchViewModel: DictionarySearchViewModel?
    @State private var didPerformSearch = false

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
            Group {
                switch availability {
                case .ready:
                    if let searchViewModel {
                        DictionarySearchView()
                            .environment(searchViewModel)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case let .preparing(description):
                    ProgressView(description)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .failed(message):
                    ContentUnavailableView(
                        "Dictionary Unavailable",
                        systemImage: "character.book.closed.ja",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle("Dictionary")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .onAppear {
            performSearchIfReady()
        }
        .onChange(of: availability) { _, newValue in
            if case .ready = newValue {
                performSearchIfReady()
            }
        }
        .dictionarySheetDetents()
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func performSearchIfReady() {
        guard case .ready = availability, !didPerformSearch else { return }
        didPerformSearch = true
        let viewModel = DictionarySearchViewModel(resultState: .searching)
        viewModel.performSearch(searchText, contextValues: contextValues)
        searchViewModel = viewModel
    }
}
