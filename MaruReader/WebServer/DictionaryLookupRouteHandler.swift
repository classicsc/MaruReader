//
//  DictionaryLookupRouteHandler.swift
//  MaruReader
//
//  Route handler for serving dictionary search results via HTTP.
//  Replaces DictionaryLookupURLSchemeHandler.
//

import Foundation
import os.log
import ReadiumGCDWebServer

/// Handles HTTP requests for dictionary lookup pages
/// Route patterns: /lookup/dictionarysearchview.html, /lookup/results.html, /lookup/popup.html
class DictionaryLookupRouteHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupRouteHandler")

    private let searchService: DictionarySearchService
    private let baseURL: String

    init(searchService: DictionarySearchService, baseURL: String) {
        self.searchService = searchService
        self.baseURL = baseURL
    }

    /// Registers the dictionary lookup route handler with the server manager
    @MainActor
    func register(with manager: WebServerManager) {
        manager.addAsyncHandler(
            matchBlock: { method, url, _, urlPath, query in
                // Match GET requests to /lookup/*
                guard method == "GET",
                      urlPath.hasPrefix("/lookup/")
                else {
                    return nil
                }
                Self.logger.info("Matched lookup request: \(urlPath)")
                return ReadiumGCDWebServerRequest(method: method, url: url, headers: [:], path: urlPath, query: query)
            },
            asyncProcessBlock: { [weak self] request, completion in
                Self.logger.info("Processing lookup request async")
                Task {
                    let response = await self?.handleRequest(request) ?? self?.createNotFoundResponse() ?? ReadiumGCDWebServerDataResponse(data: Data(), contentType: "text/plain")
                    Self.logger.info("Calling completion with response")
                    completion(response)
                }
            }
        )
    }

    private func handleRequest(_ request: ReadiumGCDWebServerRequest) async -> ReadiumGCDWebServerResponse {
        let urlPath = request.path
        Self.logger.info("Handling lookup request: \(urlPath)")

        // Parse path: /lookup/{page}
        let components = urlPath.split(separator: "/").map(String.init)
        guard components.count == 2,
              components[0] == "lookup",
              ["dictionarysearchview.html", "results.html", "popup.html"].contains(components[1])
        else {
            Self.logger.error("Invalid lookup URL format: \(urlPath)")
            return createNotFoundResponse()
        }

        let page = components[1]

        // Handle main dictionary search view (without results)
        if page == "dictionarysearchview.html" {
            let html = generateMainPageHTML()
            Self.logger.info("Generated main page HTML: \(html.count) characters")
            return createHTMLResponse(html: html)
        }

        // Extract query parameter
        let query = (request.query?["query"] as? String) ?? ""
        let trimmedQuery = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            // No query or empty query - return empty results page
            let html = page == "popup.html" ? Self.generatePopupEmptyHTML(baseURL: baseURL) : Self.generateEmptyHTML(baseURL: baseURL)
            return createHTMLResponse(html: html)
        }

        // Perform dictionary search asynchronously
        let html: String
        do {
            let searchResults = try await searchService.performSearch(query: trimmedQuery)
            let groupedResults = await searchService.groupResults(searchResults, serverBaseURL: baseURL)

            if page == "popup.html" {
                html = Self.generatePopupHTML(for: groupedResults, query: trimmedQuery, baseURL: baseURL)
                Self.logger.debug("Generated popup dictionary HTML for query '\(trimmedQuery)' (\(html.count) characters)")
            } else {
                html = Self.generateHTML(for: groupedResults, query: trimmedQuery, baseURL: baseURL)
                Self.logger.debug("Generated dictionary lookup HTML for query '\(trimmedQuery)' (\(html.count) characters)")
            }
        } catch {
            Self.logger.error("Dictionary search failed for query '\(trimmedQuery)': \(error.localizedDescription)")
            html = page == "popup.html" ? Self.generatePopupErrorHTML(query: trimmedQuery, error: error, baseURL: baseURL) : Self.generateErrorHTML(query: trimmedQuery, error: error, baseURL: baseURL)
        }

        return createHTMLResponse(html: html)
    }

    private func generateMainPageHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <link rel="stylesheet" href="\(baseURL)/resources/dictionary-search.css">
            <script src="\(baseURL)/resources/domUtilities.js"></script>
            <script src="\(baseURL)/resources/popup.js"></script>
            <script src="\(baseURL)/resources/textScanning.js"></script>
        </head>
        <body>
            <div class="header">
                <div class="title-bar">
                    <h1 class="page-title">Dictionary</h1>
                </div>
                <div class="search-container">
                    <input type="text" class="search-field" placeholder="Search dictionary" value="" id="dictionary-search">
                </div>
            </div>
            <div class="results-container">
                <iframe class="results-frame" id="results-frame" src="\(baseURL)/lookup/results.html"></iframe>
            </div>
        </body>
        </html>
        """
    }

    private static func generateHTML(for groupedResults: [GroupedSearchResults], query: String, baseURL: String) -> String {
        guard !groupedResults.isEmpty else {
            return generateNoResultsHTML(query: query, baseURL: baseURL)
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
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <script src="\(baseURL)/resources/domUtilities.js"></script>
            <script src="\(baseURL)/resources/popup.js"></script>
            <script src="\(baseURL)/resources/textScanning.js"></script>
            <style>
                body { padding: 12px; margin: 0; }
            </style>
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    private static func generateEmptyHTML(baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <script src="\(baseURL)/resources/domUtilities.js"></script>
            <script src="\(baseURL)/resources/popup.js"></script>
            <script src="\(baseURL)/resources/textScanning.js"></script>
            <style>
                body { padding: 12px; margin: 0; }
                .empty-state { text-align: center; color: #666; margin-top: 40px; }
            </style>
        </head>
        <body>
            <div class="empty-state">
                <p>Start typing to search the dictionary</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateNoResultsHTML(query: String, baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <script src="\(baseURL)/resources/domUtilities.js"></script>
            <script src="\(baseURL)/resources/popup.js"></script>
            <script src="\(baseURL)/resources/textScanning.js"></script>
            <style>
                body { padding: 12px; margin: 0; }
                .no-results { text-align: center; color: #666; margin-top: 40px; }
            </style>
        </head>
        <body>
            <div class="no-results">
                <p>No dictionary entries found for '\(escapeHTML(query))'</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateErrorHTML(query: String, error: Error, baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <script src="\(baseURL)/resources/domUtilities.js"></script>
            <script src="\(baseURL)/resources/popup.js"></script>
            <script src="\(baseURL)/resources/textScanning.js"></script>
            <style>
                body { padding: 12px; margin: 0; }
                .error-state { text-align: center; color: #d32f2f; margin-top: 40px; }
                .error-detail { color: #666; font-size: 14px; }
            </style>
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

    private static func generatePopupHTML(for groupedResults: [GroupedSearchResults], query: String, baseURL: String) -> String {
        guard !groupedResults.isEmpty else {
            return generatePopupNoResultsHTML(query: query, baseURL: baseURL)
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
            <link rel="stylesheet" href="\(baseURL)/resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
            <script>
                function navigateToTerm(term) {
                    try {
                        // Navigate up two levels: popup -> results iframe -> main window
                        var mainWindow = window.parent.parent;
                        if (mainWindow && mainWindow.document) {
                            var searchField = mainWindow.document.getElementById('dictionary-search');
                            var resultsFrame = mainWindow.document.getElementById('results-frame');

                            if (searchField) {
                                searchField.value = term;
                            }

                            if (resultsFrame) {
                                var encodedQuery = encodeURIComponent(term);
                                var url = '\(baseURL)/lookup/results.html?query=' + encodedQuery;
                                resultsFrame.src = url;
                            }
                        }
                    } catch (e) {
                        console.error('Failed to navigate to term:', e);
                    }
                }
            </script>
        </head>
        <body class="popup-results-body">
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    private static func generatePopupEmptyHTML(baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
        </head>
        <body class="popup-results-body">
            <div class="popup-empty-state">
                <p>Loading...</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generatePopupNoResultsHTML(query: String, baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
        </head>
        <body class="popup-results-body">
            <div class="popup-no-results">
                <p>No results found for '\(escapeHTML(query))'</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generatePopupErrorHTML(query: String, error: Error, baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/resources/popup.css">
        </head>
        <body class="popup-results-body">
            <div class="popup-error-state">
                <p>Search error for '\(escapeHTML(query))'</p>
                <p class="popup-error-detail">\(escapeHTML(error.localizedDescription))</p>
            </div>
        </body>
        </html>
        """
    }

    private func createHTMLResponse(html: String) -> ReadiumGCDWebServerResponse {
        let data = html.data(using: .utf8)!
        let response = ReadiumGCDWebServerDataResponse(data: data, contentType: "text/html; charset=utf-8")
        response.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
        response.setValue("no-cache", forAdditionalHeader: "Pragma")
        response.setValue("0", forAdditionalHeader: "Expires")
        return response
    }

    private func createNotFoundResponse() -> ReadiumGCDWebServerResponse {
        ReadiumGCDWebServerDataResponse(
            data: "Page not found".data(using: .utf8)!,
            contentType: "text/plain"
        )
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
