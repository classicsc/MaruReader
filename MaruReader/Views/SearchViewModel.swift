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

    private func updateWebContent() {
        htmlDocument = generateUnifiedHTML()
        logger.debug("Generated HTML document of size \(self.htmlDocument.count) characters")
    }

    private func generateUnifiedHTML() -> String {
        let termGroupsHTML = groupedResults.map { termGroup in
            """
            <div class="term-group">
                <h1 class="term-header">\(escapeHTML(termGroup.displayTerm))</h1>
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    """
                    <div class="dictionary-section">
                        <h2 class="dictionary-header">\(escapeHTML(dictionaryResult.dictionaryTitle))</h2>
                        <div class="dictionary-content">
                            \(dictionaryResult.combinedHTML)
                        </div>
                    </div>
                    """
                }.joined())
            </div>
            """
        }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 12px;
                    padding: 0;
                    line-height: 1.4;
                    font-size: 16px;
                    color: CanvasText;
                    background-color: Canvas;
                }
                .term-group {
                    margin-bottom: 20px;
                }
                .term-header {
                    font-size: 22px;
                    font-weight: 600;
                    margin: 0 0 12px 0;
                    color: CanvasText;
                }
                .dictionary-section {
                    margin-bottom: 12px;
                }
                .dictionary-header {
                    font-size: 17px;
                    font-weight: 600;
                    margin: 0 0 8px 0;
                    color: color-mix(in srgb, CanvasText 60%, transparent);
                }
                .dictionary-content {
                    margin-bottom: 8px;
                }
                .glossary-list {
                    margin: 0;
                    padding-left: 20px;
                }
                .glossary-list li {
                    margin-bottom: 8px;
                }
                .definition-text {
                    margin: 4px 0;
                }
                .deinflection {
                    font-style: italic;
                    opacity: 0.7;
                    margin: 4px 0;
                }
            </style>
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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
