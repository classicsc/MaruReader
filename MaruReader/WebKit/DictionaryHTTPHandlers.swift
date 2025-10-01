//
//  DictionaryHTTPHandlers.swift
//  MaruReader
//
//  HTTP request handlers for dictionary system using GCDHTTPServer.
//

import Foundation
import os.log
import ReadiumShared
import UniformTypeIdentifiers

/// Factory for creating HTTP request handlers for the dictionary system.
enum DictionaryHTTPHandlers {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryHTTPHandlers")

    // MARK: - Media Handler

    /// Creates a handler for serving dictionary media files.
    ///
    /// Endpoint pattern: `/dictionary-media/{uuid}/{filepath}`
    /// Example: `/dictionary-media/550E8400-E29B-41D4-A716-446655440000/image.png`
    static func createMediaHandler() -> HTTPRequestHandler {
        HTTPRequestHandler(
            onRequest: { request in
                guard let href = request.href else {
                    logger.error("No HREF in media request")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                logger.debug("Handling media request for: \(href)")

                // Parse path: dictionary-media/{uuid}/{filepath}
                let pathComponents = href.string.split(separator: "/", omittingEmptySubsequences: true)
                guard pathComponents.count >= 2,
                      let uuidString = pathComponents.first,
                      let uuid = UUID(uuidString: String(uuidString))
                else {
                    logger.error("Invalid media URL format: \(href)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                // Reconstruct file path from remaining components
                let filePath = pathComponents.dropFirst().joined(separator: "/")

                // Handle URL decoding of the file path
                guard let decodedFilePath = filePath.removingPercentEncoding else {
                    logger.error("Failed to decode file path: \(filePath)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                do {
                    let fileURL = try mediaFileURL(dictionaryUUID: uuid, filePath: decodedFilePath)

                    // Check if file exists
                    guard (try? fileURL.checkResourceIsReachable()) == true else {
                        logger.warning("Media file not found: \(fileURL.path)")
                        return HTTPServerResponse(error: createNotFoundError(url: request.url))
                    }

                    logger.debug("Serving media file: \(fileURL.path())")

                    return HTTPServerResponse(
                        resource: FileResource(file: FileURL(url: fileURL)!),
                        mediaType: MediaType(getMimeType(for: fileURL))
                    )
                } catch {
                    logger.error("Failed to locate media file: \(error.localizedDescription)")
                    return HTTPServerResponse(error: createServerError(url: request.url))
                }
            },
            onFailure: { request, error in
                logger.error("Media handler failed for \(request.url): \(error)")
            }
        )
    }

    private static func mediaFileURL(dictionaryUUID: UUID, filePath: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let base = appSupport
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(dictionaryUUID.uuidString, isDirectory: true)

        return filePath.split(separator: "/").reduce(base) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }

    // MARK: - Resource Handler

    /// Creates a handler for serving app bundle resources (CSS, JS, fonts).
    ///
    /// Endpoint pattern: `/dictionary-resources/{filename}`
    /// Example: `/dictionary-resources/structured-content.css`
    static func createResourceHandler() -> HTTPRequestHandler {
        // Allowlist of resources that can be served
        let allowedResources: Set<String> = [
            "structured-content.css",
            "MaterialSymbolsOutlined.woff2",
            "domUtilities.js",
            "textScanning.js",
            "popup.js",
            "popup.css",
            "dictionary-search.css",
        ]

        return HTTPRequestHandler(
            onRequest: { request in
                guard let href = request.href else {
                    logger.error("No HREF in resource request")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                logger.debug("Handling resource request for: \(href)")

                // Parse path: dictionary-resources/{filename}
                let pathComponents = href.string.split(separator: "/", omittingEmptySubsequences: true)
                guard let filename = pathComponents.last else {
                    logger.error("Invalid resource URL format: \(href)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                let filenameString = String(filename)

                // Check allowlist
                guard allowedResources.contains(filenameString) else {
                    logger.warning("Requested resource not in allowlist: \(filenameString)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                do {
                    let resourceURL = try bundleResourceURL(filename: filenameString)

                    // Check if file exists
                    guard (try? resourceURL.checkResourceIsReachable()) == true else {
                        logger.warning("Resource file not found: \(resourceURL.path)")
                        return HTTPServerResponse(error: createNotFoundError(url: request.url))
                    }

                    logger.debug("Serving resource file: \(resourceURL.path())")

                    return HTTPServerResponse(
                        resource: FileResource(file: FileURL(url: resourceURL)!),
                        mediaType: MediaType(getMimeType(for: resourceURL))
                    )
                } catch {
                    logger.error("Failed to locate resource file: \(error.localizedDescription)")
                    return HTTPServerResponse(error: createServerError(url: request.url))
                }
            },
            onFailure: { request, error in
                logger.error("Resource handler failed for \(request.url): \(error)")
            }
        )
    }

    private static func bundleResourceURL(filename: String) throws -> URL {
        let components = filename.components(separatedBy: ".")
        let name = components.first ?? filename
        let ext = components.count > 1 ? components.last : nil

        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "DictionaryHTTPHandlers", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Resource file not found in bundle: \(filename)",
            ])
        }

        return resourceURL
    }

    // MARK: - Lookup Handler

    /// Creates a handler for serving dictionary lookup HTML pages.
    ///
    /// Endpoint pattern: `/dictionary-lookup/{page}?query={query}`
    /// Example: `/dictionary-lookup/results.html?query=まる`
    static func createLookupHandler(
        searchService: DictionarySearchService,
        baseURL: HTTPURL
    ) -> HTTPRequestHandler {
        HTTPRequestHandler(
            onRequest: { request in
                guard let href = request.href else {
                    logger.error("No HREF in lookup request")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                logger.debug("Handling lookup request for: \(request.url)")

                // Parse path: dictionary-lookup/{page}
                let pathComponents = href.string.split(separator: "/", omittingEmptySubsequences: true)
                guard let pageName = pathComponents.last?.split(separator: "?").first else {
                    logger.error("Invalid lookup URL format: \(href)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                let page = String(pageName)

                // Validate page
                guard ["dictionarysearchview.html", "results.html", "popup.html"].contains(page) else {
                    logger.error("Invalid lookup page: \(page)")
                    return HTTPServerResponse(error: createNotFoundError(url: request.url))
                }

                // Handle main dictionary search view (without results)
                if page == "dictionarysearchview.html" {
                    let html = generateMainPageHTML(baseURL: baseURL)
                    return createHTMLResponse(html: html, url: request.url)
                }

                // Extract query parameter
                let urlComponents = URLComponents(string: request.url.string)
                let query = urlComponents?.queryItems?.first(where: { $0.name == "query" })?.value

                // No query or empty query - return empty results page
                guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
                    let html = page == "popup.html"
                        ? generatePopupEmptyHTML(baseURL: baseURL)
                        : generateEmptyHTML(baseURL: baseURL)
                    return createHTMLResponse(html: html, url: request.url)
                }

                // Perform dictionary search asynchronously
                // Note: HTTPRequestHandler needs to return synchronously, so we bridge async/sync safely
                final class ResultHolder: @unchecked Sendable {
                    private let lock = NSLock()
                    private var _html: String = ""

                    var html: String {
                        get {
                            lock.lock()
                            defer { lock.unlock() }
                            return _html
                        }
                        set {
                            lock.lock()
                            defer { lock.unlock() }
                            _html = newValue
                        }
                    }
                }

                let holder = ResultHolder()
                let semaphore = DispatchSemaphore(value: 0)

                Task.detached { @Sendable in
                    let generatedHTML: String
                    do {
                        let searchResults = try await searchService.performSearch(query: query)
                        let groupedResults = await searchService.groupResults(searchResults)

                        if page == "popup.html" {
                            generatedHTML = generatePopupHTML(for: groupedResults, query: query, baseURL: baseURL)
                            logger.debug("Generated popup dictionary HTML for query '\(query)' (\(generatedHTML.count) characters)")
                        } else {
                            generatedHTML = generateHTML(for: groupedResults, query: query, baseURL: baseURL)
                            logger.debug("Generated dictionary lookup HTML for query '\(query)' (\(generatedHTML.count) characters)")
                        }
                    } catch {
                        logger.error("Dictionary search failed for query '\(query)': \(error.localizedDescription)")
                        generatedHTML = page == "popup.html"
                            ? generatePopupErrorHTML(query: query, error: error, baseURL: baseURL)
                            : generateErrorHTML(query: query, error: error, baseURL: baseURL)
                    }

                    holder.html = generatedHTML
                    semaphore.signal()
                }

                semaphore.wait()
                return createHTMLResponse(html: holder.html, url: request.url)
            },
            onFailure: { request, error in
                logger.error("Lookup handler failed for \(request.url): \(error)")
            }
        )
    }

    // MARK: - Helper Functions

    private static func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }

        // Fallback for common types
        switch pathExtension {
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "html", "htm": return "text/html"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "woff2": return "font/woff2"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "wav": return "audio/wav"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }

    private static func createNotFoundError(url: HTTPURL) -> HTTPError {
        HTTPError.errorResponse(HTTPResponse(
            request: HTTPRequest(url: url),
            url: url,
            status: .notFound,
            headers: [:],
            mediaType: nil,
            body: nil
        ))
    }

    private static func createServerError(url: HTTPURL) -> HTTPError {
        HTTPError.errorResponse(HTTPResponse(
            request: HTTPRequest(url: url),
            url: url,
            status: .internalServerError,
            headers: [:],
            mediaType: nil,
            body: nil
        ))
    }

    private static func createHTMLResponse(html: String, url _: HTTPURL) -> HTTPServerResponse {
        HTTPServerResponse(
            resource: DataResource(data: html.data(using: .utf8)!),
            mediaType: MediaType("text/html; charset=utf-8")
        )
    }

    // MARK: - HTML Generation

    private static func generateMainPageHTML(baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
                // Inject base URL for JavaScript to use
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/dictionary-search.css">
            <script src="\(baseURL)/dictionary-resources/domUtilities.js"></script>
            <script src="\(baseURL)/dictionary-resources/popup.js"></script>
            <script src="\(baseURL)/dictionary-resources/textScanning.js"></script>
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
                <iframe class="results-frame" id="results-frame" src="\(baseURL)/dictionary-lookup/results.html"></iframe>
            </div>
        </body>
        </html>
        """
    }

    private static func generateHTML(for groupedResults: [GroupedSearchResults], query: String, baseURL: HTTPURL) -> String {
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
                            \(dictionaryResult.generateHTML(withBaseURL: baseURL))
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
            <script>
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <script src="\(baseURL)/dictionary-resources/domUtilities.js"></script>
            <script src="\(baseURL)/dictionary-resources/popup.js"></script>
            <script src="\(baseURL)/dictionary-resources/textScanning.js"></script>
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

    private static func generateEmptyHTML(baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <script src="\(baseURL)/dictionary-resources/domUtilities.js"></script>
            <script src="\(baseURL)/dictionary-resources/popup.js"></script>
            <script src="\(baseURL)/dictionary-resources/textScanning.js"></script>
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

    private static func generateNoResultsHTML(query: String, baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <script src="\(baseURL)/dictionary-resources/domUtilities.js"></script>
            <script src="\(baseURL)/dictionary-resources/popup.js"></script>
            <script src="\(baseURL)/dictionary-resources/textScanning.js"></script>
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

    private static func generateErrorHTML(query: String, error: Error, baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <script src="\(baseURL)/dictionary-resources/domUtilities.js"></script>
            <script src="\(baseURL)/dictionary-resources/popup.js"></script>
            <script src="\(baseURL)/dictionary-resources/textScanning.js"></script>
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

    private static func generatePopupHTML(for groupedResults: [GroupedSearchResults], query: String, baseURL: HTTPURL) -> String {
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
                            \(dictionaryResult.generateHTML(withBaseURL: baseURL))
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
            <script>
                window.MARUREADER_BASE_URL = '\(baseURL)';
            </script>
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/structured-content.css">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
            <script>
                function navigateToTerm(term) {
                    try {
                        // Try dictionary view navigation first (popup -> results iframe -> main window)
                        var mainWindow = window.parent.parent;
                        if (mainWindow && mainWindow.document) {
                            var searchField = mainWindow.document.getElementById('dictionary-search');
                            var resultsFrame = mainWindow.document.getElementById('results-frame');

                            if (searchField && resultsFrame) {
                                // We're in the dictionary view context
                                searchField.value = term;
                                var encodedQuery = encodeURIComponent(term);
                                var baseURL = window.MARUREADER_BASE_URL;
                                var url = baseURL + '/dictionary-lookup/results.html?query=' + encodedQuery;
                                resultsFrame.src = url;
                                return;
                            }
                        }
                    } catch (e) {
                        // Accessing parent/parent failed, likely cross-origin or reader context
                        console.log('Dictionary view navigation not available:', e);
                    }

                    // Fall back to WebKit message handler (for EPUB reader context or dictionary sheet)
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dictionaryTermSelected) {
                            window.webkit.messageHandlers.dictionaryTermSelected.postMessage(term);
                        } else {
                            console.error('WebKit message handler not available');
                        }
                    } catch (e) {
                        console.error('Failed to send term selection message:', e);
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

    private static func generatePopupEmptyHTML(baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
        </head>
        <body class="popup-results-body">
            <div class="popup-empty-state">
                <p>Loading...</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generatePopupNoResultsHTML(query: String, baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
        </head>
        <body class="popup-results-body">
            <div class="popup-no-results">
                <p>No results found for '\(escapeHTML(query))'</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generatePopupErrorHTML(query: String, error: Error, baseURL: HTTPURL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(baseURL)/dictionary-resources/popup.css">
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
}

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
