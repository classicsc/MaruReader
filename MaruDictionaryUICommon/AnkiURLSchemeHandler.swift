// AnkiURLSchemeHandler.swift
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
import MaruAnki
import MaruReaderCore
import os.log
import WebKit

protocol AnkiConnectionManaging: Sendable {
    var isReady: Bool { get async }
    var profileName: String? { get async }
    func addNote(resolver: any TemplateValueResolver) async throws -> NoteCreationResult
}

extension AnkiConnectionManager: AnkiConnectionManaging {}

protocol AnkiNoteServicing: Sendable {
    func getExistingNoteTermKeys(
        for terms: [(expression: String, reading: String?)],
        profileName: String
    ) async -> Set<String>

    func recordNote(
        expression: String,
        reading: String?,
        profileName: String,
        deckName: String,
        modelName: String,
        fields: [String: String],
        tags: [String],
        ankiID: Int64?,
        pendingSync: Bool
    ) async throws -> UUID
}

extension AnkiNoteService: AnkiNoteServicing {}

protocol TextLookupSnapshotProviding: Sendable {
    func requestId() async -> String?
    func snapshot() async -> TextLookupResponse?
    func termGroup(for termKey: String) async -> GroupedSearchResults?
}

extension TextLookupSession: TextLookupSnapshotProviding {
    func requestId() async -> String? {
        requestId.uuidString
    }
}

public final actor AnkiURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AnkiURLSchemeHandler")

    private let noteService: any AnkiNoteServicing
    private let managerFactory: @Sendable () async -> any AnkiConnectionManaging

    private var managerTask: Task<any AnkiConnectionManaging, Never>?
    private var currentProvider: (any TextLookupSnapshotProviding)?
    private var currentRequestID: String?

    public init() {
        noteService = AnkiNoteService()
        managerFactory = { await AnkiConnectionManager() }
    }

    init(
        noteService: any AnkiNoteServicing,
        managerFactory: @escaping @Sendable () async -> any AnkiConnectionManaging
    ) {
        self.noteService = noteService
        self.managerFactory = managerFactory
    }

    func setLookupProvider(_ provider: (any TextLookupSnapshotProviding)?) async {
        currentProvider = provider
        currentRequestID = await provider?.requestId()
    }

    public func setSession(_ session: TextLookupSession?) async {
        await setLookupProvider(session)
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

        guard url.scheme == "marureader-anki", let host = url.host(), !host.isEmpty else {
            Self.logger.error("Invalid marureader-anki URL format: \(url.absoluteString)")
            return Self.createNotFoundResponse()
        }

        switch host {
        case "state":
            return try await handleStateRequest(request)
        case "add":
            return try await handleAddRequest(request)
        default:
            Self.logger.error("Unknown marureader-anki endpoint: \(host)")
            return Self.createNotFoundResponse()
        }
    }

    private func handleStateRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard request.httpMethod?.uppercased() == "POST" else {
            return Self.createBadRequestResponse(message: "Expected POST")
        }

        guard let data = requestBodyData(from: request) else {
            return Self.createBadRequestResponse(message: "Missing body")
        }

        let decoded = try JSONDecoder().decode(AnkiStateRequest.self, from: data)

        guard requestMatchesCurrent(decoded.requestId) else {
            return try Self.createJSONResponse(AnkiStateResponse(enabled: false, states: [:]))
        }

        let manager = await connectionManager()
        guard await manager.isReady, let profileName = await manager.profileName else {
            return try Self.createJSONResponse(AnkiStateResponse(enabled: false, states: [:]))
        }

        let terms = deduplicatedTerms(decoded.terms)
        let lookupTerms = terms.map { (expression: $0.expression, reading: $0.reading) }
        let existingTermKeys = await noteService.getExistingNoteTermKeys(
            for: lookupTerms,
            profileName: profileName
        )

        var states: [String: String] = [:]
        for term in terms {
            let state = existingTermKeys.contains(term.termKey) ? "exists" : "ready"
            states[term.termKey] = state
        }

        return try Self.createJSONResponse(AnkiStateResponse(enabled: true, states: states))
    }

    private func handleAddRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard request.httpMethod?.uppercased() == "POST" else {
            return Self.createBadRequestResponse(message: "Expected POST")
        }

        guard let data = requestBodyData(from: request) else {
            return Self.createBadRequestResponse(message: "Missing body")
        }

        let decoded = try JSONDecoder().decode(AnkiAddRequest.self, from: data)

        guard requestMatchesCurrent(decoded.requestId) else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        guard let provider = currentProvider,
              let termGroup = await provider.termGroup(for: decoded.termKey),
              let response = await provider.snapshot()
        else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        let manager = await connectionManager()
        guard await manager.isReady else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        let audioURL = decoded.audioURL.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: termGroup,
            primaryAudioURL: audioURL
        )

        do {
            let result = try await manager.addNote(resolver: resolver)
            let reading = decoded.reading?.isEmpty == true ? nil : decoded.reading
            _ = try await noteService.recordNote(
                expression: decoded.expression,
                reading: reading,
                profileName: result.profileName,
                deckName: result.deckName,
                modelName: result.modelName,
                fields: result.resolvedFields,
                tags: [],
                ankiID: result.ankiNoteID,
                pendingSync: result.pendingSync
            )
            return try Self.createJSONResponse(AnkiAddResponse(state: "success"))
        } catch {
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("duplicate") || errorDescription.contains("exists") {
                return try Self.createJSONResponse(AnkiAddResponse(state: "exists"))
            }
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }
    }

    private func requestMatchesCurrent(_ requestId: String?) -> Bool {
        guard let requestId, !requestId.isEmpty, let currentRequestID else {
            return false
        }
        return requestId == currentRequestID
    }

    private func deduplicatedTerms(_ terms: [AnkiStateTerm]) -> [AnkiStateTerm] {
        var seen = Set<String>()
        var result: [AnkiStateTerm] = []
        for term in terms {
            guard !seen.contains(term.termKey) else { continue }
            seen.insert(term.termKey)
            result.append(term)
        }
        return result
    }

    private func connectionManager() async -> any AnkiConnectionManaging {
        if let managerTask {
            return await managerTask.value
        }

        let task = Task { await managerFactory() }
        managerTask = task
        return await task.value
    }

    private func requestBodyData(from request: URLRequest) -> Data? {
        guard let body = request.httpBody else {
            return nil
        }
        return body
    }

    private static func createJSONResponse(_ responseBody: some Encodable) throws -> [URLSchemeTaskResult] {
        let data = try JSONEncoder().encode(responseBody)
        let response = HTTPURLResponse(
            url: URL(string: "marureader-anki://response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)",
                "Cache-Control": "no-store",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createBadRequestResponse(message: String) -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-anki://error")!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        let data = message.data(using: .utf8) ?? Data()

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-anki://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Not found".data(using: .utf8) ?? Data()

        return [
            .response(response),
            .data(data),
        ]
    }
}

private struct AnkiStateRequest: Decodable {
    let requestId: String?
    let terms: [AnkiStateTerm]
}

private struct AnkiStateTerm: Decodable {
    let termKey: String
    let expression: String
    let reading: String?
}

private struct AnkiStateResponse: Encodable {
    let enabled: Bool
    let states: [String: String]
}

private struct AnkiAddRequest: Decodable {
    let requestId: String?
    let termKey: String
    let expression: String
    let reading: String?
    let audioURL: String?
}

private struct AnkiAddResponse: Encodable {
    let state: String
}
