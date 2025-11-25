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
}
