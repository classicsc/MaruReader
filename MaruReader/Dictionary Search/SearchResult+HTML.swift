//
//  SearchResult+HTML.swift
//  MaruReader
//
//  HTML generation extensions for SearchResult arrays.
//

import Foundation

extension [SearchResult] {
    func generateCombinedHTML(dictionaryUUID: UUID? = nil, serverBaseURL: String) -> String {
        let allDefinitions = self.flatMap(\.definitions)
        if let dictUUID = dictionaryUUID {
            let baseURL = URL(string: "\(serverBaseURL)/media/\(dictUUID.uuidString)/")!
            return allDefinitions.toHTML(baseURL: baseURL)
        }
        return allDefinitions.toHTML()
    }
}
