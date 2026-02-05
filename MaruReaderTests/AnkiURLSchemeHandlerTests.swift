// AnkiURLSchemeHandlerTests.swift
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
@testable import MaruAnki
@testable import MaruDictionaryUICommon
@testable import MaruReaderCore
import Testing
import WebKit

struct AnkiURLSchemeHandlerTests {
    @Test func stateReturnsDisabledWhenManagerNotReady() async throws {
        let response = makeResponse(termKey: "neko|ねこ")
        let manager = MockAnkiConnectionManager(isReady: false, profileName: "Default", addResult: .success(makeNoteResult()))
        let noteService = MockAnkiNoteService(existingTermKeys: [])
        let handler = AnkiURLSchemeHandler(noteService: noteService, managerFactory: { manager })
        await handler.setResponse(response)

        let request = makeStateRequest(requestId: response.requestID.uuidString, terms: [
            AnkiStateRequestTerm(termKey: "neko|ねこ", expression: "neko", reading: "ねこ"),
        ])
        let data = try await collectResponseBody(from: handler, request: request)
        let decoded = try JSONDecoder().decode(AnkiStateResponse.self, from: data)

        #expect(decoded.enabled == false)
        #expect(decoded.states.isEmpty)
    }

    @Test func stateReturnsTermStatesWhenReady() async throws {
        let response = makeResponse(termKey: "neko|ねこ")
        let manager = MockAnkiConnectionManager(isReady: true, profileName: "Default", addResult: .success(makeNoteResult()))
        let noteService = MockAnkiNoteService(existingTermKeys: ["neko|ねこ"])
        let handler = AnkiURLSchemeHandler(noteService: noteService, managerFactory: { manager })
        await handler.setResponse(response)

        let request = makeStateRequest(requestId: response.requestID.uuidString, terms: [
            AnkiStateRequestTerm(termKey: "neko|ねこ", expression: "neko", reading: "ねこ"),
            AnkiStateRequestTerm(termKey: "inu|いぬ", expression: "inu", reading: "いぬ"),
        ])
        let data = try await collectResponseBody(from: handler, request: request)
        let decoded = try JSONDecoder().decode(AnkiStateResponse.self, from: data)

        #expect(decoded.enabled == true)
        #expect(decoded.states["neko|ねこ"] == "exists")
        #expect(decoded.states["inu|いぬ"] == "ready")
    }

    @Test func addNoteReturnsSuccessAndRecordsNote() async throws {
        let response = makeResponse(termKey: "neko|ねこ")
        let manager = MockAnkiConnectionManager(isReady: true, profileName: "Default", addResult: .success(makeNoteResult()))
        let noteService = MockAnkiNoteService(existingTermKeys: [])
        let handler = AnkiURLSchemeHandler(noteService: noteService, managerFactory: { manager })
        await handler.setResponse(response)

        let request = makeAddRequest(
            requestId: response.requestID.uuidString,
            termKey: "neko|ねこ",
            expression: "neko",
            reading: "ねこ",
            audioURL: ""
        )
        let data = try await collectResponseBody(from: handler, request: request)
        let decoded = try JSONDecoder().decode(AnkiAddResponse.self, from: data)

        #expect(decoded.state == "success")
        let recorded = await noteService.recordedNotes
        #expect(recorded.count == 1)
        #expect(recorded.first?.expression == "neko")
    }

    @Test func addNoteReturnsExistsOnDuplicateError() async throws {
        let response = makeResponse(termKey: "neko|ねこ")
        let manager = MockAnkiConnectionManager(isReady: true, profileName: "Default", addResult: .failure(DuplicateNoteError()))
        let noteService = MockAnkiNoteService(existingTermKeys: [])
        let handler = AnkiURLSchemeHandler(noteService: noteService, managerFactory: { manager })
        await handler.setResponse(response)

        let request = makeAddRequest(
            requestId: response.requestID.uuidString,
            termKey: "neko|ねこ",
            expression: "neko",
            reading: "ねこ",
            audioURL: ""
        )
        let data = try await collectResponseBody(from: handler, request: request)
        let decoded = try JSONDecoder().decode(AnkiAddResponse.self, from: data)

        #expect(decoded.state == "exists")
        let recorded = await noteService.recordedNotes
        #expect(recorded.isEmpty)
    }

    @Test func addNoteReturnsErrorWhenTermMissing() async throws {
        let response = makeResponse(termKey: "neko|ねこ")
        let manager = MockAnkiConnectionManager(isReady: true, profileName: "Default", addResult: .success(makeNoteResult()))
        let noteService = MockAnkiNoteService(existingTermKeys: [])
        let handler = AnkiURLSchemeHandler(noteService: noteService, managerFactory: { manager })
        await handler.setResponse(response)

        let request = makeAddRequest(
            requestId: response.requestID.uuidString,
            termKey: "inu|いぬ",
            expression: "inu",
            reading: "いぬ",
            audioURL: ""
        )
        let data = try await collectResponseBody(from: handler, request: request)
        let decoded = try JSONDecoder().decode(AnkiAddResponse.self, from: data)

        #expect(decoded.state == "error")
    }
}

private struct AnkiStateRequestTerm: Encodable {
    let termKey: String
    let expression: String
    let reading: String
}

private struct AnkiStateRequest: Encodable {
    let requestId: String
    let terms: [AnkiStateRequestTerm]
}

private struct AnkiStateResponse: Decodable {
    let enabled: Bool
    let states: [String: String]
}

private struct AnkiAddRequest: Encodable {
    let requestId: String
    let termKey: String
    let expression: String
    let reading: String
    let audioURL: String
}

private struct AnkiAddResponse: Decodable {
    let state: String
}

private struct DuplicateNoteError: LocalizedError {
    var errorDescription: String? {
        "Duplicate note"
    }
}

private actor MockAnkiConnectionManager: AnkiConnectionManaging {
    private let ready: Bool
    private let profile: String?
    private let addResult: Result<NoteCreationResult, Error>

    init(isReady: Bool, profileName: String?, addResult: Result<NoteCreationResult, Error>) {
        ready = isReady
        profile = profileName
        self.addResult = addResult
    }

    var isReady: Bool {
        ready
    }

    var profileName: String? {
        profile
    }

    func addNote(resolver _: any TemplateValueResolver) async throws -> NoteCreationResult {
        switch addResult {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}

private actor MockAnkiNoteService: AnkiNoteServicing {
    let existingTermKeys: Set<String>
    private(set) var recordedNotes: [RecordedNote] = []

    init(existingTermKeys: Set<String>) {
        self.existingTermKeys = existingTermKeys
    }

    func getExistingNoteTermKeys(
        for _: [(expression: String, reading: String?)],
        profileName _: String
    ) async -> Set<String> {
        existingTermKeys
    }

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
    ) async throws -> UUID {
        let note = RecordedNote(
            expression: expression,
            reading: reading,
            profileName: profileName,
            deckName: deckName,
            modelName: modelName,
            fields: fields,
            tags: tags,
            ankiID: ankiID,
            pendingSync: pendingSync
        )
        recordedNotes.append(note)
        return UUID()
    }
}

private struct RecordedNote {
    let expression: String
    let reading: String?
    let profileName: String
    let deckName: String
    let modelName: String
    let fields: [String: String]
    let tags: [String]
    let ankiID: Int64?
    let pendingSync: Bool
}

private func makeNoteResult() -> NoteCreationResult {
    NoteCreationResult(
        ankiNoteID: 123,
        pendingSync: false,
        profileName: "Default",
        deckName: "Deck",
        modelName: "Model",
        resolvedFields: ["Front": "neko"]
    )
}

private func makeResponse(termKey: String) -> TextLookupResponse {
    let context = "neko"
    let request = TextLookupRequest(context: context)
    let range = context.startIndex ..< context.endIndex

    let group = GroupedSearchResults(
        termKey: termKey,
        expression: "neko",
        reading: "ねこ",
        dictionariesResults: [],
        pitchAccentResults: [],
        termTags: [],
        deinflectionInfo: nil
    )

    let styles = DisplayStyles(
        fontFamily: "Test",
        contentFontSize: 14,
        popupFontSize: 14,
        showDeinflection: true,
        pitchDownstepNotationInHeaderEnabled: false,
        pitchResultsAreaCollapsedDisplay: false,
        pitchResultsAreaDownstepNotationEnabled: false,
        pitchResultsAreaDownstepPositionEnabled: false,
        pitchResultsAreaEnabled: false
    )

    return TextLookupResponse(
        request: request,
        results: [group],
        primaryResult: "neko",
        primaryResultSourceRange: range,
        styles: styles
    )
}

private func makeStateRequest(requestId: String, terms: [AnkiStateRequestTerm]) -> URLRequest {
    let body = AnkiStateRequest(requestId: requestId, terms: terms)
    let data = try? JSONEncoder().encode(body)
    var request = URLRequest(url: URL(string: "marureader-anki://state")!)
    request.httpMethod = "POST"
    request.httpBody = data
    return request
}

private func makeAddRequest(
    requestId: String,
    termKey: String,
    expression: String,
    reading: String,
    audioURL: String
) -> URLRequest {
    let body = AnkiAddRequest(
        requestId: requestId,
        termKey: termKey,
        expression: expression,
        reading: reading,
        audioURL: audioURL
    )
    let data = try? JSONEncoder().encode(body)
    var request = URLRequest(url: URL(string: "marureader-anki://add")!)
    request.httpMethod = "POST"
    request.httpBody = data
    return request
}

private func collectResponseBody(from handler: AnkiURLSchemeHandler, request: URLRequest) async throws -> Data {
    var data = Data()
    for try await result in handler.reply(for: request) {
        switch result {
        case let .data(chunk):
            data.append(chunk)
        case .response:
            break
        @unknown default:
            break
        }
    }
    return data
}
