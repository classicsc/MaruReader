//
//  DictionaryLookupURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-lookup:// scheme to serve dictionary search results.
//

import Foundation
import os.log
import WebKit

class DictionaryLookupURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupURLSchemeHandler")

    private let searchService: DictionarySearchService

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.searchService = DictionarySearchService(persistenceController: persistenceController)
    }

    func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let searchService = self.searchService
            let task = Task { @Sendable in
                do {
                    let results = try await Self.handleRequest(request, searchService: searchService)
                    for result in results {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func handleRequest(_ request: URLRequest, searchService: DictionarySearchService) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            logger.error("Invalid URL in request")
            return createNotFoundResponse()
        }

        logger.debug("Handling lookup request for URL: \(url.absoluteString)")

        // Parse the URL: marureader-lookup://dictionarysearchview.html?query=まる
        guard url.scheme == "marureader-lookup",
              let host = url.host(),
              host == "dictionarysearchview.html"
        else {
            logger.error("Invalid marureader-lookup URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        // Extract query parameter
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let queryItem = queryItems.first(where: { $0.name == "query" }),
              let query = queryItem.value,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            // No query or empty query - return empty results page
            let html = generateEmptyHTML()
            return createHTMLResponse(html: html, url: url)
        }

        do {
            // Perform dictionary search
            let searchResults = try await searchService.performSearch(query: query)
            let groupedResults = await searchService.groupResults(searchResults)

            // Generate HTML
            let html = generateHTML(for: groupedResults, query: query)

            logger.debug("Generated dictionary lookup HTML for query '\(query)' (\(html.count) characters)")

            return createHTMLResponse(html: html, url: url)

        } catch {
            logger.error("Dictionary search failed for query '\(query)': \(error.localizedDescription)")
            let html = generateErrorHTML(query: query, error: error)
            return createHTMLResponse(html: html, url: url)
        }
    }

    private static func generateHTML(for groupedResults: [GroupedSearchResults], query: String) -> String {
        guard !groupedResults.isEmpty else {
            return generateNoResultsHTML(query: query)
        }

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
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
            <script src="marureader-resource://domUtilities.js"></script>
            <script src="marureader-resource://textScanning.js"></script>
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    private static func generateEmptyHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
        </head>
        <body>
            <div class="empty-state">
                <p>Start typing to search the dictionary</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateNoResultsHTML(query: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
        </head>
        <body>
            <div class="no-results">
                <p>No dictionary entries found for '\(escapeHTML(query))'</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateErrorHTML(query: String, error: Error) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
        </head>
        <body>
            <div class="error-state">
                <h2>Search Error</h2>
                <p>Failed to search for '\(escapeHTML(query))'</p>
                <p class="error-detail">\(escapeHTML(error.localizedDescription))</p>
            </div>
        </body>
        </html>
        """
    }

    private static func createHTMLResponse(html: String, url: URL) -> [URLSchemeTaskResult] {
        let data = html.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/html; charset=utf-8",
                "Content-Length": "\(data.count)",
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0",
            ]
        )!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-lookup://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Page not found".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }
}

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
