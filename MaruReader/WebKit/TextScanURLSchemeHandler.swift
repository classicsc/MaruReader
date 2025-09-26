//
//  TextScanURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-textscan:// scheme to receive text scanning data from JavaScript.
//

import Foundation
import os.log
import WebKit

class TextScanURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TextScanURLSchemeHandler")

    func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let task = Task { @Sendable in
                do {
                    let results = try await Self.handleRequest(request)
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

    private static func handleRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            logger.error("Invalid URL in request")
            return createErrorResponse("Invalid URL")
        }

        logger.debug("Handling text scan request for URL: \(url.absoluteString)")

        // Parse the URL: marureader-textscan://scan?data=encodedJSON
        guard url.scheme == "marureader-textscan" else {
            logger.error("Invalid scheme for text scan URL: \(url.absoluteString)")
            return createErrorResponse("Invalid scheme")
        }

        guard let host = url.host(), host == "scan" else {
            logger.error("Invalid host for text scan URL, expected 'scan': \(url.absoluteString)")
            return createErrorResponse("Invalid host")
        }

        // Extract the data parameter from the query string
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let encodedData = dataItem.value
        else {
            logger.error("Missing or invalid data parameter in text scan URL")
            return createErrorResponse("Missing data parameter")
        }

        // Decode the JSON data
        guard let decodedData = encodedData.removingPercentEncoding else {
            logger.error("Failed to decode URL-encoded data")
            return createErrorResponse("Invalid URL encoding")
        }

        // Parse and log the text scan result
        do {
            if let jsonData = decodedData.data(using: .utf8),
               let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            {
                // Check if this is a link/image-only result (no text content)
                let hasLinkInfo = jsonObject["linkInfo"] != nil
                let hasImageInfo = jsonObject["imageInfo"] != nil
                let hasTextContent = jsonObject["tappedChar"] as? String != nil

                if hasLinkInfo || hasImageInfo {
                    if hasTextContent {
                        logger.info("Received text scan data with link/image:")
                    } else {
                        logger.info("Received link/image scan data (no text):")
                    }
                } else {
                    logger.info("Received text scan data:")
                }

                if let tappedChar = jsonObject["tappedChar"] as? String {
                    logger.info("  - Tapped character: '\(tappedChar)'")
                }
                if let forwardText = jsonObject["forwardText"] as? String {
                    logger.info("  - Forward text: '\(forwardText)'")
                }
                if let hasRubyText = jsonObject["hasRubyText"] as? Bool {
                    logger.info("  - Has ruby text: \(hasRubyText)")
                }
                if let cssPath = jsonObject["cssPath"] as? String {
                    logger.info("  - CSS path: \(cssPath)")
                }

                // Log link information
                if let linkInfo = jsonObject["linkInfo"] as? [String: Any] {
                    if let linkType = linkInfo["type"] as? String {
                        logger.info("  - Link type: \(linkType)")

                        if let href = linkInfo["href"] as? String {
                            logger.info("  - Link href: \(href)")
                        }

                        if linkType == "gloss-image-link" {
                            if let dataCollapsible = linkInfo["dataCollapsible"] as? String {
                                logger.info("  - Link data-collapsible: \(dataCollapsible)")
                            }
                            if let dataCollapsed = linkInfo["dataCollapsed"] as? String {
                                logger.info("  - Link data-collapsed: \(dataCollapsed)")
                            }
                            if let dataImageLoadState = linkInfo["dataImageLoadState"] as? String {
                                logger.info("  - Link data-image-load-state: \(dataImageLoadState)")
                            }
                        } else if linkType == "link" {
                            if let dataExternal = linkInfo["dataExternal"] as? String {
                                logger.info("  - Link data-external: \(dataExternal)")
                            }
                        }
                    }
                }

                // Log image information
                if let imageInfo = jsonObject["imageInfo"] as? [String: Any] {
                    if let imageType = imageInfo["type"] as? String {
                        logger.info("  - Image type: \(imageType)")

                        if let src = imageInfo["src"] as? String {
                            logger.info("  - Image src: \(src)")
                        }
                    }
                }

                // TODO: In the future, integrate with SearchViewModel to perform dictionary lookup
                // For now, just log the received data as requested

            } else if decodedData == "null" {
                logger.info("Received null text scan result (no text found at tap location)")
            } else {
                logger.warning("Received malformed JSON data: \(decodedData)")
            }
        } catch {
            logger.error("Failed to parse JSON data: \(error.localizedDescription)")
            return createErrorResponse("Invalid JSON data")
        }

        // Return a simple success response
        return createSuccessResponse()
    }

    private static func createSuccessResponse() -> [URLSchemeTaskResult] {
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

    private static func createErrorResponse(_ message: String) -> [URLSchemeTaskResult] {
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
