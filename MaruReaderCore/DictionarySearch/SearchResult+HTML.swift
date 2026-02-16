// SearchResult+HTML.swift
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

// MARK: - HTML generation extensions for SearchResult arrays and singles.

import Foundation

public extension [SearchResult] {
    internal func generateCombinedHTML(dictionaryUUID: UUID? = nil) -> String {
        let allDefinitions = self.flatMap(\.definitions)
        let allDefinitionsHTML: String
        if let dictUUID = dictionaryUUID {
            let baseURL = URL(string: "marureader-media://\(dictUUID.uuidString)/")!
            allDefinitionsHTML = allDefinitions.toHTML(baseURL: baseURL)
        } else {
            allDefinitionsHTML = allDefinitions.toHTML()
        }
        return allDefinitionsHTML
    }

    /// Generate Anki-compatible HTML with inline styles (no CSS class dependencies).
    func generateCombinedAnkiHTML(dictionaryUUID: UUID? = nil) -> String {
        let allDefinitions = flatMap(\.definitions)
        let mediaBaseURL: URL? = if let dictUUID = dictionaryUUID {
            URL(string: "marureader-media://\(dictUUID.uuidString)/")
        } else {
            nil
        }
        return allDefinitions.toAnkiHTML(mediaBaseURL: mediaBaseURL)
    }

    /// Extracts all image paths from the search results' definitions.
    func extractImagePaths() -> [String] {
        flatMap(\.definitions).extractImagePaths()
    }
}
