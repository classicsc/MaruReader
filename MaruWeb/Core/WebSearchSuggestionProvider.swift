// WebSearchSuggestionProvider.swift
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

import Foundation

struct WebSearchSuggestionProvider {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches search suggestions for the given query using the engine's suggestion URL.
    /// Returns an empty array on error or if the engine has no suggestions URL.
    func fetchSuggestions(for query: String, engine: SearchEngine) async -> [String] {
        guard !query.isEmpty,
              let url = engine.suggestionsURL(for: query)
        else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: url)
            return parseSuggestions(from: data)
        } catch {
            return []
        }
    }

    /// Parses the OpenSearch JSON suggestion format: `[query, [suggestion1, suggestion2, ...]]`
    func parseSuggestions(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 2,
              let suggestions = json[1] as? [String]
        else {
            return []
        }
        return suggestions
    }
}
