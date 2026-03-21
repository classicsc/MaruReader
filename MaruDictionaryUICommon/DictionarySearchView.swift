// DictionarySearchView.swift
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
public struct DictionarySearchView: View {
    @Environment(DictionarySearchViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dictionaryPresentationTheme) private var presentationTheme
    @State private var presentationState = DictionarySearchPresentationState()

    public init() {}

    public var body: some View {
        DictionarySearchContentView(
            viewModel: viewModel,
            presentationState: presentationState,
            openURL: openURL,
            presentationTheme: presentationTheme
        )
        .task {
            configureView()
        }
        .onChange(of: presentationTheme?.dictionaryWebTheme, updateDictionaryWebTheme)
        .onChange(of: viewModel.currentRequest?.id, clearEditingWhenRequestIsRemoved)
        .onChange(of: isSearching, clearEditingWhenSearching)
    }

    private var isSearching: Bool {
        if case .searching = viewModel.resultState {
            return true
        }
        return false
    }

    private func configureView() {
        presentationState.loadContextDisplaySettings()
        applyDictionaryWebTheme()
    }

    private func updateDictionaryWebTheme() {
        applyDictionaryWebTheme()
    }

    private func applyDictionaryWebTheme() {
        viewModel.setDictionaryWebTheme(presentationTheme?.dictionaryWebTheme)
    }

    private func clearEditingWhenRequestIsRemoved() {
        guard viewModel.currentRequest == nil else { return }
        presentationState.clearEditing()
    }

    private func clearEditingWhenSearching() {
        guard isSearching else { return }
        presentationState.clearEditing()
    }
}

#Preview {
    DictionarySearchView()
}
