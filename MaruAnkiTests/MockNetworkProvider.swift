// MockNetworkProvider.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
@testable import MaruAnki

/// A mock network provider that captures requests and returns canned responses.
///
/// Use this in tests to verify request payloads without hitting the network.
final class MockNetworkProvider: NetworkProviding, @unchecked Sendable {
    /// All requests that have been made through this provider.
    private(set) var capturedRequests: [URLRequest] = []

    /// Queue of responses to return. Each call to `data(for:)` pops the first response.
    /// If empty, returns a default success response.
    var responseQueue: [(Data, URLResponse)] = []

    /// If set, this error will be thrown instead of returning a response.
    var errorToThrow: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)

        if let error = errorToThrow {
            throw error
        }

        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }

        // Default empty success response
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    /// Convenience method to queue a permission granted response.
    func queuePermissionGrantedResponse(requireApiKey: Bool = false, version: Int = 6) {
        let json: [String: Any] = [
            "result": [
                "permission": "granted",
                "requireApiKey": requireApiKey,
                "version": version,
            ],
            "error": NSNull(),
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8765")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }

    /// Convenience method to queue an addNote success response.
    func queueAddNoteSuccessResponse(noteId: Int64 = 1_234_567_890) {
        let json: [String: Any] = [
            "result": noteId,
            "error": NSNull(),
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8765")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }

    /// Convenience method to queue a generic success response with a result object.
    func queueResultResponse(_ result: Any) {
        let json: [String: Any] = [
            "result": result,
            "error": NSNull(),
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8765")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }

    /// Convenience method to queue an error response.
    func queueErrorResponse(_ errorMessage: String) {
        let json: [String: Any] = [
            "result": NSNull(),
            "error": errorMessage,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8765")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }

    /// Returns the last captured request, or nil if no requests have been made.
    var lastRequest: URLRequest? {
        capturedRequests.last
    }

    /// Returns the HTTP body of the last request as a JSON dictionary.
    func lastRequestBodyAsJSON() throws -> [String: Any]? {
        guard let body = lastRequest?.httpBody else { return nil }
        return try JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
}
