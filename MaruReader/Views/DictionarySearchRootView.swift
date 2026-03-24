// DictionarySearchRootView.swift
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

import MaruDictionaryUICommon
import SwiftUI

struct DictionarySearchRootView: View {
    private static let screenshotQuery = "読む"

    let availability: DictionaryFeatureAvailability

    @State private var searchViewModel: DictionarySearchViewModel?
    @State private var query: String = ""
    @State private var didConfigureScreenshotState = false
    @FocusState private var isSearchFieldFocused: Bool

    init(availability: DictionaryFeatureAvailability = .ready) {
        self.availability = availability
    }

    var body: some View {
        NavigationStack {
            switch availability {
            case .ready:
                if let searchViewModel {
                    DictionarySearchView()
                        .environment(searchViewModel)
                } else {
                    ProgressView("Preparing dictionary...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            activateSearchIfNeeded()
                        }
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
            @unknown default:
                if let searchViewModel {
                    DictionarySearchView()
                        .environment(searchViewModel)
                } else {
                    ProgressView("Preparing dictionary...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            activateSearchIfNeeded()
                        }
                }
            }
        }
        .searchable(text: $query, placement: .automatic, prompt: "Search Dictionary")
        .searchFocused($isSearchFieldFocused)
        .onChange(of: query) { _, newValue in
            searchViewModel?.performSearch(newValue)
        }
        .task {
            configureScreenshotStateIfNeeded()
        }
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            if isFocused {
                activateSearchIfNeeded()
                searchViewModel?.textFieldFocused()
            } else {
                searchViewModel?.textFieldUnfocused()
            }
        }
    }

    private func activateSearchIfNeeded() {
        guard searchViewModel == nil else { return }
        searchViewModel = DictionarySearchViewModel()
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchViewModel?.performSearch(query)
        }
    }

    private func configureScreenshotStateIfNeeded() {
        guard MaruReaderApp.isScreenshotMode, !didConfigureScreenshotState else { return }
        didConfigureScreenshotState = true
        query = Self.screenshotQuery
        activateSearchIfNeeded()

        // The search tab auto-focuses its searchable field; blur it again so
        // screenshot capture is deterministic even on freshly erased simulators.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isSearchFieldFocused = false
        }
    }
}
