// DictionarySearchResultsView.swift
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

@MainActor
struct DictionarySearchResultsView: View {
    let viewModel: DictionarySearchViewModel
    let openURL: OpenURLAction
    let presentationTheme: DictionaryPresentationTheme?

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch viewModel.resultState {
            case .ready:
                DictionarySearchReadyView(
                    viewModel: viewModel,
                    openURL: openURL,
                    presentationTheme: presentationTheme
                )
            case let .noResults(query):
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No results found for \"\(query)\"")
                )
            case .startPage:
                ContentUnavailableView(
                    "Start a Search",
                    systemImage: "book",
                    description: Text("Enter text to search the dictionary.")
                )
            case let .error(error):
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            case .searching:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themedBackgroundColor)
            }
        }
    }

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }
}
