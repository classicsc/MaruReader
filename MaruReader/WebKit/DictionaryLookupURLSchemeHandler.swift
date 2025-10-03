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

    nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
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

        // Parse the URL: marureader-lookup://lookup/dictionarysearchview.html?query=まる
        guard url.scheme == "marureader-lookup",
              let host = url.host(),
              host == "lookup"
        else {
            logger.error("Invalid marureader-lookup URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        let path = url.path(percentEncoded: false)

        if path == "/dictionarysearchview.html" || path == "/popup.html" {
            return try await handleSearchViewRequest(url: url, searchService: searchService)
        } else if path == "/scan", request.httpMethod == "POST" {
            return try await handleScanRequest(request: request)
        } else {
            logger.error("Unknown path in marureader-lookup URL: \(path)")
            return createNotFoundResponse()
        }
    }

    private static func handleSearchViewRequest(url: URL, searchService: DictionarySearchService) async throws -> [URLSchemeTaskResult] {
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
            let groupedResults = DictionarySearchService.groupResults(searchResults)

            let page = url.path(percentEncoded: false)

            if page == "popup.html" {
                // Generate popup HTML
                let html = generatePopupHTML(for: groupedResults, query: query)
                return createHTMLResponse(html: html, url: url)
            } else {
                // Generate HTML
                let html = generateHTML(for: groupedResults, query: query)
                return createHTMLResponse(html: html, url: url)
            }
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

    private static func generatePopupHTML(for groupedResults: [GroupedSearchResults], query: String) -> String {
        guard !groupedResults.isEmpty else {
            return generateNoResultsHTML(query: query)
        }

        let termGroupsHTML = groupedResults.map { termGroup in
            """
            <div class="popup-term-group" onclick="navigateToTerm('\(escapeHTML(termGroup.expression))')">
                <h2 class="popup-term-header">\(escapeHTML(termGroup.displayTerm))</h2>
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    """
                    <div class="popup-dictionary-section">
                        <h3 class="popup-dictionary-header">\(escapeHTML(dictionaryResult.dictionaryTitle))</h3>
                        <div class="popup-dictionary-content">
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
            <link rel="stylesheet" href="marureader-resource://popup.css">
            <script>
                function navigateToTerm(term) {
                    var message = new XMLHttpRequest();
                    message.open("POST", "marureader-lookup://lookup/navigate", true);
                    message.setRequestHeader("Content-Type", "application/json;charset=UTF-8");
                    message.send(JSON.stringify({ term: term }));
                }
            </script>
        </head>
        <body class="popup-results-body">
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
            url: URL(string: "marureader-lookup://lookup/error.html")!,
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

    private static func handleScanRequest(request: URLRequest) async throws -> [URLSchemeTaskResult] {
        // Extract the data parameter from the query string
        guard let postData = request.httpBody else {
            logger.error("Missing or invalid data parameter in text scan URL")
            return createScanErrorResponse("Missing data parameter")
        }

        // Parse and log the text scan result
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: postData) as? [String: Any] {
                logger.info("Received text scan data:")
                if let offset = jsonObject["offset"] as? Int {
                    logger.info("  - Offset: '\(offset)'")
                }
                if let context = jsonObject["context"] as? String {
                    logger.info("  - Context text: '\(context)'")
                }
                if let rubyContext = jsonObject["rubyContext"] as? Bool {
                    logger.info("  - Has ruby text: \(rubyContext)")
                }
                if let cssPath = jsonObject["cssSelector"] as? String {
                    logger.info("  - CSS path: \(cssPath)")
                }

                // TODO: In the future, integrate with views to perform dictionary lookup
            } else {
                logger.warning("Received malformed JSON data: \(postData)")
            }
        } catch {
            logger.error("Failed to parse JSON data: \(error.localizedDescription)")
            return createScanErrorResponse("Invalid JSON data")
        }

        // Return a simple success response
        return createScanSuccessResponse()
    }

    private static func createScanSuccessResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-textscan://scan")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain",
                "Content-Length": "2",
            ]
        )!

        let data = "OK".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createScanErrorResponse(_ message: String) -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-textscan://error")!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain",
                "Content-Length": "\(message.utf8.count)",
            ]
        )!

        let data = message.data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }
}
