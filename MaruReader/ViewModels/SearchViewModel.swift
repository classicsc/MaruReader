//
//  SearchViewModel.swift
//  MaruReader
//
//  Search view model for dictionary search functionality.
//

import CoreData
import Foundation
import os.log
import WebKit

@MainActor
@Observable
class SearchViewModel {
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "SearchViewModel")

    var searchResults: [SearchResult] = []
    var groupedResults: [GroupedSearchResults] = []
    var isSearching = false
    var searchError: Error?

    private let searchService: DictionarySearchService

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.searchService = DictionarySearchService(persistenceController: persistenceController)
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isSearching = true
        searchError = nil

        do {
            let results = try await searchService.performSearch(query: query)
            searchResults = results
            groupedResults = await searchService.groupResults(results)

        } catch {
            searchError = error
            searchResults = []
            groupedResults = []
        }

        isSearching = false
    }

    func lookupURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(string: "marureader-lookup://dictionarysearchview.html")
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        return URL(string: "marureader-lookup://dictionarysearchview.html?query=\(encodedQuery)")
    }

    private func clearResults() {
        searchResults = []
        groupedResults = []
        searchError = nil
    }
}
