// MARK: - HTML generation extensions for SearchResult arrays and singles.

import Foundation

extension [SearchResult] {
    func generateCombinedHTML(dictionaryUUID: UUID? = nil) -> String {
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
    public func generateCombinedAnkiHTML(dictionaryUUID: UUID? = nil) -> String {
        let allDefinitions = flatMap(\.definitions)
        let mediaBaseURL: URL? = if let dictUUID = dictionaryUUID {
            URL(string: "marureader-media://\(dictUUID.uuidString)/")
        } else {
            nil
        }
        return allDefinitions.toAnkiHTML(mediaBaseURL: mediaBaseURL)
    }
}
