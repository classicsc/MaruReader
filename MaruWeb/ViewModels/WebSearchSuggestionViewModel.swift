// WebSearchSuggestionViewModel.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import Observation

@MainActor
@Observable
final class WebSearchSuggestionViewModel {
    var suggestions: [String] = []
    var isLoading = false

    private let provider: WebSearchSuggestionProvider
    private var fetchTask: Task<Void, Never>?

    init(provider: WebSearchSuggestionProvider = WebSearchSuggestionProvider()) {
        self.provider = provider
    }

    func updateQuery(_ query: String) {
        fetchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, WebSearchEngineSettings.searchSuggestionsEnabled else {
            suggestions = []
            isLoading = false
            return
        }

        isLoading = true
        let engine = WebSearchEngineSettings.searchEngine
        let provider = self.provider

        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let results = await provider.fetchSuggestions(for: trimmed, engine: engine)
            guard !Task.isCancelled else { return }

            suggestions = results
            isLoading = false
        }
    }

    func cancel() {
        fetchTask?.cancel()
        fetchTask = nil
        suggestions = []
        isLoading = false
    }
}
