//
//  DictionaryResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

import Foundation
import ReadiumShared

struct DictionaryResults: Identifiable {
    let dictionaryTitle: String
    let dictionaryUUID: UUID
    let results: [SearchResult]
    let combinedHTML: String

    var id: UUID { dictionaryUUID }

    /// Generates HTML for these results using an HTTP base URL for media files.
    ///
    /// This is used when serving dictionary content via HTTP server instead of custom URL schemes.
    /// - Parameter baseURL: The HTTP base URL (e.g., "http://localhost:8080")
    /// - Returns: HTML string with HTTP URLs for media files
    func generateHTML(withBaseURL baseURL: HTTPURL) -> String {
        let allDefinitions = results.flatMap(\.definitions)
        let mediaURL = URL(string: "\(baseURL)/dictionary-media/\(dictionaryUUID.uuidString)/")!
        return allDefinitions.toHTML(baseURL: mediaURL)
    }
}
