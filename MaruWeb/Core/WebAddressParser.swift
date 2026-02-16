// WebAddressParser.swift
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

enum WebAddressParser {
    /// Resolves user input into a URL. If the input looks like a URL, normalizes it.
    /// Otherwise, constructs a search query URL using the given engine.
    static func resolvedURL(from rawValue: String, engine: SearchEngine = WebSearchEngineSettings.searchEngine) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if looksLikeDomain(trimmed) {
            return URL(string: "https://\(trimmed)")
        }

        return engine.searchURL(for: trimmed)
    }

    /// Returns true when the input looks like a domain or URL without a scheme,
    /// rather than a search query.
    private static func looksLikeDomain(_ input: String) -> Bool {
        !input.contains(" ") && input.contains(".")
    }
}
