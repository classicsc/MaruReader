//
//  DictionaryLookupURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-lookup:// scheme to serve dictionary search results.
//

import Foundation
import os.log
import WebKit

public class DictionaryLookupURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryLookupURLSchemeHandler")

    private let searchService: DictionarySearchService
    private let onNavigate: @Sendable (String) -> Void

    public init(
        persistenceController: DictionaryPersistenceController = DictionaryPersistenceController.shared,
        onNavigate: @escaping @Sendable (String) -> Void = { _ in },
    ) {
        self.searchService = DictionarySearchService(persistenceController: persistenceController)
        self.onNavigate = onNavigate
    }

    public nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let searchService = self.searchService
            let onNavigate = self.onNavigate
            let task = Task { @Sendable in
                do {
                    let results = try await Self.handleRequest(
                        request,
                        searchService: searchService,
                        onNavigate: onNavigate,
                    )
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

    private static func handleRequest(
        _ request: URLRequest,
        searchService _: DictionarySearchService,
        onNavigate: @escaping @Sendable (String) -> Void,
    ) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            logger.error("Invalid URL in request")
            return createNotFoundResponse()
        }

        logger.debug("Handling lookup request for URL: \(url.absoluteString)")

        guard url.scheme == "marureader-lookup",
              let host = url.host(),
              host == "lookup"
        else {
            logger.error("Invalid marureader-lookup URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        let path = url.path(percentEncoded: false)

        if path == "/navigate", request.httpMethod == "POST" {
            return try await handleNavigateRequest(request: request, onNavigate: onNavigate)
        } else {
            logger.error("Unknown path in marureader-lookup URL: \(path)")
            return createNotFoundResponse()
        }
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

    private static func handleNavigateRequest(
        request: URLRequest,
        onNavigate: @escaping @Sendable (String) -> Void
    ) async throws -> [URLSchemeTaskResult] {
        guard let postData = request.httpBody else {
            logger.error("Missing POST data in navigate request")
            return createScanErrorResponse("Missing data parameter")
        }

        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: postData) as? [String: Any],
               let term = jsonObject["term"] as? String
            {
                logger.info("Navigate request for term: '\(term)'")
                onNavigate(term)
            } else {
                logger.warning("Received malformed navigate JSON data")
            }
        } catch {
            logger.error("Failed to parse navigate JSON data: \(error.localizedDescription)")
            return createScanErrorResponse("Invalid JSON data")
        }

        return createScanSuccessResponse()
    }

    private static func createScanSuccessResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-textscan://scan")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain",
                "Access-Control-Allow-Origin": "*",
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
