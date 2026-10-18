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
import os
import WebKit

protocol AnkiConnectionManaging: Sendable {
    var isReady: Bool { get async }
    var profileName: String? { get async }
    func makeNoteDraft(resolver: any TemplateValueResolver) async throws -> AnkiNoteDraft
    func isDuplicate(expression: String, reading: String?, fields: [String: [TemplateResolvedValue]]) async -> Bool
    func addNote(fields: [String: [TemplateResolvedValue]], allowDuplicate: Bool) async throws -> NoteCreationResult
}

extension AnkiConnectionManager: AnkiConnectionManaging {}

/// Everything the note editor needs for one term: the resolved draft, the term it came from,
/// a resolver for alternate values, and the way to submit the finished note.
public struct AnkiNoteEditorContext: Sendable {
    public let termGroup: GroupedSearchResults
    public let resolver: any TemplateValueResolver
    public let draft: AnkiNoteDraft
    /// The configured duplicate scope would reject this note; submitting adds it as a duplicate.
    public let isDuplicate: Bool
    /// Adds the note and returns the add button state: "success", "exists" or "error".
    let submit: @Sendable (AnkiNoteDraft) async -> String
}

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
    func snapshot() async throws -> TextLookupResponse?
    func termGroup(for termKey: String) async throws -> GroupedSearchResults?
}

extension TextLookupSession: TextLookupSnapshotProviding {
    func requestId() async -> String? {
        requestId.uuidString
    }
}

public final actor AnkiURLSchemeHandler: URLSchemeHandler {
    private static let logger = Logger.maru(category: "AnkiURLSchemeHandler")

    private let noteService: any AnkiNoteServicing
    private let managerFactory: @Sendable () async -> any AnkiConnectionManaging

    private var managerTask: Task<any AnkiConnectionManaging, Never>?
    private var currentProvider: (any TextLookupSnapshotProviding)?
    private var currentRequestID: String?
    private var editHandler: (@Sendable (AnkiNoteEditorContext) -> Void)?

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
        let requestID = await provider?.requestId()
        currentProvider = provider
        currentRequestID = requestID
    }

    public func setSession(_ session: TextLookupSession?) async {
        await setLookupProvider(session)
    }

    /// Receives "edit and add" requests from the page so the host can present the note editor.
    public func setEditHandler(_ handler: @escaping @Sendable (AnkiNoteEditorContext) -> Void) {
        editHandler = handler
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
        case "edit":
            return try await handleEditRequest(request)
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

        let tapAction = AnkiAddButtonPreferences.tapAction == .openEditor ? "edit" : "add"
        return try Self.createJSONResponse(AnkiStateResponse(enabled: true, states: states, tapAction: tapAction))
    }

    private func handleAddRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let decoded = try decodeAddRequest(request) else {
            return Self.createBadRequestResponse(message: "Expected POST with body")
        }

        guard let lookup = await lookupContext(for: decoded) else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        let manager = await connectionManager()
        guard await manager.isReady, let draft = try? await manager.makeNoteDraft(resolver: lookup.resolver) else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        // Anki would reject a known duplicate outright. Let the user decide in the editor instead,
        // where the add becomes an explicit "Add Duplicate".
        if let editHandler, await manager.isDuplicate(expression: decoded.expression, reading: decoded.reading, fields: draft.resolvedFields) {
            editHandler(editorContext(for: decoded, lookup: lookup, draft: draft, manager: manager, isDuplicate: true))
            return try Self.createJSONResponse(AnkiAddResponse(state: "exists"))
        }

        let state = await addNote(expression: decoded.expression, reading: decoded.reading) {
            try await manager.addNote(fields: draft.resolvedFields, allowDuplicate: false)
        }
        return try Self.createJSONResponse(AnkiAddResponse(state: state))
    }

    /// Resolves the note into a draft and hands it to the host, which presents the editor.
    private func handleEditRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let decoded = try decodeAddRequest(request) else {
            return Self.createBadRequestResponse(message: "Expected POST with body")
        }

        guard let editHandler, let lookup = await lookupContext(for: decoded) else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        let manager = await connectionManager()
        guard await manager.isReady, let draft = try? await manager.makeNoteDraft(resolver: lookup.resolver) else {
            return try Self.createJSONResponse(AnkiAddResponse(state: "error"))
        }

        let isDuplicate = await manager.isDuplicate(expression: decoded.expression, reading: decoded.reading, fields: draft.resolvedFields)
        editHandler(editorContext(for: decoded, lookup: lookup, draft: draft, manager: manager, isDuplicate: isDuplicate))
        return try Self.createJSONResponse(AnkiAddResponse(state: "ready"))
    }

    private func editorContext(
        for decoded: AnkiAddRequest,
        lookup: (termGroup: GroupedSearchResults, resolver: TextLookupResponseTemplateResolver),
        draft: AnkiNoteDraft,
        manager: any AnkiConnectionManaging,
        isDuplicate: Bool
    ) -> AnkiNoteEditorContext {
        let expression = decoded.expression
        let reading = decoded.reading
        return AnkiNoteEditorContext(termGroup: lookup.termGroup, resolver: lookup.resolver, draft: draft, isDuplicate: isDuplicate) { draft in
            await self.addNote(expression: expression, reading: reading) {
                try await manager.addNote(fields: draft.resolvedFields, allowDuplicate: isDuplicate)
            }
        }
    }

    private func decodeAddRequest(_ request: URLRequest) throws -> AnkiAddRequest? {
        guard request.httpMethod?.uppercased() == "POST", let data = requestBodyData(from: request) else {
            return nil
        }
        return try JSONDecoder().decode(AnkiAddRequest.self, from: data)
    }

    /// The term group and a resolver for the request, or nil when the request is stale or the term is unknown.
    private func lookupContext(
        for decoded: AnkiAddRequest
    ) async -> (termGroup: GroupedSearchResults, resolver: TextLookupResponseTemplateResolver)? {
        guard requestMatchesCurrent(decoded.requestId),
              let provider = currentProvider,
              let termGroup = try? await provider.termGroup(for: decoded.termKey),
              let response = try? await provider.snapshot()
        else {
            return nil
        }

        let audioURL = decoded.audioURL.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        let selectionText = decoded.selectionText?.isEmpty == true ? nil : decoded.selectionText
        let resolver = TextLookupResponseTemplateResolver(
            response: response,
            selectedGroup: termGroup,
            primaryAudioURL: audioURL,
            selectionText: selectionText
        )
        return (termGroup, resolver)
    }

    /// Runs an add, records the note locally, and maps the outcome to a button state.
    private func addNote(
        expression: String,
        reading: String?,
        _ perform: @Sendable () async throws -> NoteCreationResult
    ) async -> String {
        do {
            let result = try await perform()
            let reading = reading?.isEmpty == true ? nil : reading
            _ = try await noteService.recordNote(
                expression: expression,
                reading: reading,
                profileName: result.profileName,
                deckName: result.deckName,
                modelName: result.modelName,
                fields: result.resolvedFields,
                tags: [],
                ankiID: result.ankiNoteID,
                pendingSync: result.pendingSync
            )
            return "success"
        } catch AnkiConnectionManagerError.duplicateNote {
            return "exists"
        } catch {
            return "error"
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
    var tapAction = "add"
}

private struct AnkiAddRequest: Decodable {
    let requestId: String?
    let termKey: String
    let expression: String
    let reading: String?
    let audioURL: String?
    let selectionText: String?
}

private struct AnkiAddResponse: Encodable {
    let state: String
}
