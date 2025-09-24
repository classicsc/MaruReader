//
//  SearchViewModel.swift
//  MaruReader
//
//  Search view model for dictionary search functionality.
//

import CoreData
import Foundation

@MainActor
@Observable
class SearchViewModel {
    var searchResults: [SearchResult] = []
    var groupedResults: [GroupedSearchResults] = []
    var isSearching = false
    var searchError: Error?

    private let persistenceController: PersistenceController
    private var termFetcher: TermFetcher?
    private let candidateGenerator = DictionaryCandidateGenerator()

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        setupTermFetcher()
    }

    private func setupTermFetcher() {
        let backgroundContext = persistenceController.container.newBackgroundContext()
        termFetcher = TermFetcher(backgroundContext: backgroundContext)
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isSearching = true
        searchError = nil

        do {
            // Create lookup candidates from query
            let candidates = candidateGenerator.generateCandidates(from: query)

            let results = try await termFetcher?.fetchTerms(for: candidates) ?? []

            searchResults = results
            groupedResults = groupResults(results)

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
    }

    private func groupResults(_ results: [SearchResult]) -> [GroupedSearchResults] {
        let grouped = Swift.Dictionary(grouping: results, by: { result in
            "\(result.term)|\(result.reading ?? "")"
        })

        return grouped.map { termKey, termResults in
            let firstResult = termResults.first!
            let dictionaryGroups = Swift.Dictionary(grouping: termResults, by: { $0.dictionaryTitle })

            let dictionaryResults = dictionaryGroups.map { dictionaryTitle, dictResults in
                let combinedHTML = generateCombinedHTML(for: dictResults)
                return DictionaryResults(
                    dictionaryTitle: dictionaryTitle,
                    results: dictResults,
                    combinedHTML: combinedHTML
                )
            }.sorted { lhs, rhs in
                let lhsPriority = lhs.results.first?.displayPriority ?? 0
                let rhsPriority = rhs.results.first?.displayPriority ?? 0
                return lhsPriority < rhsPriority
            }

            return GroupedSearchResults(
                termKey: termKey,
                expression: firstResult.term,
                reading: firstResult.reading,
                dictionariesResults: dictionaryResults
            )
        }.sorted { lhs, rhs in
            guard let lhsFirst = lhs.dictionariesResults.first?.results.first,
                  let rhsFirst = rhs.dictionariesResults.first?.results.first
            else {
                return false
            }
            return lhsFirst.rankingCriteria > rhsFirst.rankingCriteria
        }
    }

    private func generateCombinedHTML(for results: [SearchResult]) -> String {
        let allDefinitions = results.flatMap(\.definitions)
        return allDefinitions.toHTML()
    }
}

struct GroupedSearchResults: Identifiable {
    let termKey: String
    let expression: String
    let reading: String?
    let dictionariesResults: [DictionaryResults]

    var id: String { termKey }

    var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }
}

struct DictionaryResults: Identifiable {
    let dictionaryTitle: String
    let results: [SearchResult]
    let combinedHTML: String

    var id: String { dictionaryTitle }
}
