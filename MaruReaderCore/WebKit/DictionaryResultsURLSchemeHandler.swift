// DictionaryResultsURLSchemeHandler.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import os.log
import WebKit

public final actor DictionaryResultsURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryResultsURLSchemeHandler")

    private var currentSession: TextLookupSession?
    private var currentRequestID: String?

    public init() {}

    public func setSession(_ session: TextLookupSession?) async {
        currentSession = session
        if let session {
            let requestId = await session.requestId
            currentRequestID = requestId.uuidString
        } else {
            currentRequestID = nil
        }
    }

    public nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let task = Task { @Sendable in
                do {
                    let results = try await handleRequest(request)
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

    private func handleRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            Self.logger.error("Invalid URL in request")
            return Self.createNotFoundResponse()
        }

        Self.logger.debug("Handling request for URL: \(url.absoluteString)")

        guard url.scheme == "marureader-lookup", let host = url.host(), !host.isEmpty else {
            Self.logger.error("Invalid marureader-lookup URL format: \(url.absoluteString)")
            return Self.createNotFoundResponse()
        }

        switch host {
        case "state":
            return try await handleStateRequest(url: url)
        case "results":
            return try await handleResultsRequest(url: url)
        default:
            Self.logger.error("Unknown marureader-lookup endpoint: \(host)")
            return Self.createNotFoundResponse()
        }
    }

    private func handleStateRequest(url: URL) async throws -> [URLSchemeTaskResult] {
        guard let session = currentSession else {
            return Self.createNotFoundResponse()
        }

        let params = Self.queryParameters(from: url)
        guard requestMatchesCurrent(params["requestId"]) else {
            return Self.createNotFoundResponse()
        }

        let requestId = await session.requestId
        let styles = session.styles
        let dictionaryStyles = await session.dictionaryStylesCSS()
        let response = DictionaryResultsStateResponse(
            requestId: requestId.uuidString,
            styles: styles,
            dictionaryStyles: dictionaryStyles
        )

        return try Self.createJSONResponse(response, url: url)
    }

    private func handleResultsRequest(url: URL) async throws -> [URLSchemeTaskResult] {
        guard let session = currentSession else {
            return Self.createNotFoundResponse()
        }

        let params = Self.queryParameters(from: url)
        guard requestMatchesCurrent(params["requestId"]) else {
            return Self.createNotFoundResponse()
        }

        let limit = Int(params["limit"] ?? "") ?? 10
        let modeParam = params["mode"] ?? "results"
        let mode: DictionaryResultsHTMLRenderer.Mode = modeParam == "popup" ? .popup : .results

        let requestId = await session.requestId
        let batch = try await session.renderNextBatch(maxGroups: max(1, limit), mode: mode)
        let response = DictionaryResultsBatchResponse(
            requestId: requestId.uuidString,
            html: batch.html,
            nextCursor: batch.nextCursor,
            hasMore: batch.hasMore
        )

        return try Self.createJSONResponse(response, url: url)
    }

    private func requestMatchesCurrent(_ requestId: String?) -> Bool {
        guard let requestId, !requestId.isEmpty, let currentRequestID else {
            return false
        }
        return requestId == currentRequestID
    }

    private static func queryParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        var params: [String: String] = [:]
        components.queryItems?.forEach { item in
            params[item.name] = item.value ?? ""
        }
        return params
    }

    private static func createJSONResponse(_ responseBody: some Encodable, url: URL) throws -> [URLSchemeTaskResult] {
        let data = try JSONEncoder().encode(responseBody)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)",
                "Cache-Control": "no-store",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type",
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

        let data = "Resource not found".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }
}

private struct DictionaryResultsStateResponse: Encodable {
    let requestId: String
    let styles: DisplayStyles
    let dictionaryStyles: String
}

private struct DictionaryResultsBatchResponse: Encodable {
    let requestId: String
    let html: String
    let nextCursor: Int
    let hasMore: Bool
}
