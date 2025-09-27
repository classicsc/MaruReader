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
    var htmlDocument = ""

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
            updateWebContent()

        } catch {
            searchError = error
            searchResults = []
            groupedResults = []
        }

        isSearching = false
    }

    private func clearResults() {
        searchResults = []
        groupedResults = []
        searchError = nil
        htmlDocument = ""
    }

    private func updateWebContent() {
        htmlDocument = groupedResults.generateUnifiedHTML()
        logger.debug("Generated HTML document of size \(self.htmlDocument.count) characters")
    }
}
