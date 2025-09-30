//
//  TextScanURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-textscan:// scheme to receive text scanning data from JavaScript.
//

import Foundation
import os.log
import WebKit

@MainActor
class TextScanURLSchemeHandler: NSObject, URLSchemeHandler, WKURLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TextScanURLSchemeHandler")

    // Track active WKURLSchemeTask operations for cancellation
    private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
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
                logger.info("Received text scan data:")
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

    // MARK: - WKURLSchemeHandler conformance

    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        let request = urlSchemeTask.request

        let task = Task { [weak self] in
            do {
                let results = try await Self.handleRequest(request)

                for result in results {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        return
                    }

                    await MainActor.run {
                        switch result {
                        case let .response(response):
                            urlSchemeTask.didReceive(response)
                        case let .data(data):
                            urlSchemeTask.didReceive(data)
                        @unknown default:
                            break
                        }
                    }
                }

                await MainActor.run {
                    urlSchemeTask.didFinish()
                }
            } catch {
                await MainActor.run {
                    urlSchemeTask.didFailWithError(error)
                }
            }

            // Clean up task tracking
            _ = await MainActor.run {
                self?.activeTasks.removeValue(forKey: taskId)
            }
        }

        // Store task for potential cancellation
        activeTasks[taskId] = task
    }

    func webView(_: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        let task = activeTasks.removeValue(forKey: taskId)
        task?.cancel()
    }
}
