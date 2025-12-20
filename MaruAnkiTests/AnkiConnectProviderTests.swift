//
//  AnkiConnectProviderTests.swift
//  MaruAnkiTests
//
//  Created by Sam Smoker on 12/18/25.
//

import Foundation
@testable import MaruAnki
import Testing

struct AnkiConnectProviderTests {
    // MARK: - requestPermission Tests

    @Test func requestPermission_generatesCorrectRequest() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()

        _ = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "requestPermission-request.json")

        // Verify request structure
        #expect(body["action"] as? String == "requestPermission")
        #expect(body["version"] as? Int == 6)
        #expect(body["params"] == nil)
    }

    @Test func requestPermission_includesApiKeyWhenProvided() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()

        _ = try await AnkiConnectProvider(host: "localhost", port: 8765, apiKey: "test-api-key", network: mock)

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "requestPermission-with-apikey-request.json")

        #expect(body["key"] as? String == "test-api-key")
    }

    // MARK: - addNote Tests

    @Test func addNote_generatesWellFormedPayload() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("日本語")],
            "Back": [.text("Japanese")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-basic-request.json")

        // Verify top-level structure
        #expect(body["action"] as? String == "addNote")
        #expect(body["version"] as? Int == 6)

        // Verify note params
        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])

        #expect(note["deckName"] as? String == "Test Deck")
        #expect(note["modelName"] as? String == "Basic")

        let noteFields = try #require(note["fields"] as? [String: String])
        #expect(noteFields["Front"] == "日本語")
        #expect(noteFields["Back"] == "Japanese")

        let tags = try #require(note["tags"] as? [String])
        #expect(tags.isEmpty)

        // Verify options for allowDuplicate
        let options = try #require(note["options"] as? [String: Any])
        #expect(options["allowDuplicate"] as? Bool == true)
    }

    @Test func addNote_duplicateScopeDeck_generatesCorrectOptions() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: "Specific Deck",
            includeChildDecks: true,
            checkAllModels: true
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-duplicate-deck-scope-request.json")

        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])
        let options = try #require(note["options"] as? [String: Any])

        #expect(options["allowDuplicate"] as? Bool == false)
        #expect(options["duplicateScope"] as? String == "deck")

        let scopeOptions = try #require(options["duplicateScopeOptions"] as? [String: Any])
        #expect(scopeOptions["deckName"] as? String == "Specific Deck")
        #expect(scopeOptions["checkChildren"] as? Bool == true)
        #expect(scopeOptions["checkAllModels"] as? Bool == true)
    }

    @Test func addNote_duplicateScopeCollection_generatesCorrectOptions() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .collection,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: true
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-duplicate-collection-scope-request.json")

        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])
        let options = try #require(note["options"] as? [String: Any])

        #expect(options["allowDuplicate"] as? Bool == false)
        #expect(options["duplicateScope"] as? String == "collection")

        let scopeOptions = try #require(options["duplicateScopeOptions"] as? [String: Any])
        #expect(scopeOptions["checkAllModels"] as? Bool == true)
    }

    @Test func addNote_withRemoteMediaURL_includesURLInPayload() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let mediaURL = URL(string: "https://example.com/audio.mp3")!
        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [TemplateResolvedValue(text: "test", mediaFiles: ["audio.mp3": mediaURL])],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-remote-media-request.json")

        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])

        // Audio should be in the "audio" array since it's an mp3
        let audioArray = try #require(note["audio"] as? [[String: Any]])
        #expect(audioArray.count == 1)

        let audioItem = audioArray[0]
        #expect(audioItem["filename"] as? String == "audio.mp3")
        #expect(audioItem["url"] as? String == "https://example.com/audio.mp3")

        let audioFields = try #require(audioItem["fields"] as? [String])
        #expect(audioFields.contains("Front"))
    }

    @Test func addNote_withLocalMediaFile_includesBase64Data() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        // Create a temporary file with known content
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-image.png")
        let testData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        try testData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [TemplateResolvedValue(text: "test", mediaFiles: ["test-image.png": tempFile])],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-local-media-request.json")

        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])

        // Image should be in the "picture" array
        let pictureArray = try #require(note["picture"] as? [[String: Any]])
        #expect(pictureArray.count == 1)

        let pictureItem = pictureArray[0]
        #expect(pictureItem["filename"] as? String == "test-image.png")

        // Should have base64 data, not URL
        #expect(pictureItem["url"] == nil)
        let base64Data = try #require(pictureItem["data"] as? String)
        #expect(base64Data == testData.base64EncodedString())

        let pictureFields = try #require(pictureItem["fields"] as? [String])
        #expect(pictureFields.contains("Front"))
    }

    @Test func addNote_combinesMultipleValuesPerField() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueAddNoteSuccessResponse()

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [
                .text("Part 1 "),
                .text("Part 2"),
            ],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Test Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let body = try #require(try mock.lastRequestBodyAsJSON())

        // Record the request payload as an attachment
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        Attachment.record(bodyData, named: "addNote-combined-values-request.json")

        let params = try #require(body["params"] as? [String: Any])
        let note = try #require(params["note"] as? [String: Any])
        let noteFields = try #require(note["fields"] as? [String: String])

        #expect(noteFields["Front"] == "Part 1 Part 2")
    }

    // MARK: - Error Handling Tests

    @Test func addNote_duplicateError_throwsDuplicateNoteError() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueErrorResponse("cannot create note because it is a duplicate")

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        await #expect(throws: AnkiConnectError.duplicateNote) {
            try await provider.addNote(
                fields: fields,
                profileName: "User 1",
                deckName: "Test Deck",
                modelName: "Basic",
                duplicateOptions: duplicateOptions
            )
        }
    }

    @Test func addNote_genericError_throwsApiError() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueErrorResponse("model was not found")

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        await #expect(throws: AnkiConnectError.self) {
            try await provider.addNote(
                fields: fields,
                profileName: "User 1",
                deckName: "Test Deck",
                modelName: "NonexistentModel",
                duplicateOptions: duplicateOptions
            )
        }
    }

    // MARK: - Profile/Deck/Model Tests

    @Test func getAnkiProfiles_returnsCorrectProfiles() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse(["User 1", "User 2"]) // getProfiles
        mock.queueResultResponse("User 1") // getActiveProfile

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)
        let response = await provider.getAnkiProfiles()

        guard case let .success(profiles) = response else {
            Issue.record("Expected success response")
            return
        }

        #expect(profiles.count == 2)
        #expect(profiles.first { $0.id == "User 1" }?.isActiveProfile == true)
        #expect(profiles.first { $0.id == "User 2" }?.isActiveProfile == false)
    }

    @Test func getAnkiDecks_returnsCorrectDecks() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 1") // getActiveProfile
        mock.queueResultResponse(["Default": 1, "Japanese": 2]) // deckNamesAndIds

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)
        let response = await provider.getAnkiDecks(forProfile: "User 1")

        guard case let .success(decks) = response else {
            Issue.record("Expected success response")
            return
        }

        #expect(decks.count == 2)
        #expect(decks.contains { $0.name == "Default" && $0.id == "1" })
        #expect(decks.contains { $0.name == "Japanese" && $0.id == "2" })
    }

    @Test func getAnkiDecks_wrongProfile_returnsFailure() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 2") // getActiveProfile (different from requested)

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)
        let response = await provider.getAnkiDecks(forProfile: "User 1")

        guard case let .failure(error) = response else {
            Issue.record("Expected failure response")
            return
        }

        #expect(error as? AnkiConnectError == .profileMismatch(expected: "User 1", actual: "User 2"))
    }

    @Test func getAnkiModels_returnsCorrectModels() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 1") // getActiveProfile
        mock.queueResultResponse(["Basic": 100, "Cloze": 200]) // modelNamesAndIds

        // multi response for modelFieldNames
        // Order depends on sorted keys: Basic, Cloze
        let multiResult: [Any] = [
            ["result": ["Front", "Back"], "error": NSNull()], // Basic
            ["result": ["Text", "Extra"], "error": NSNull()], // Cloze
        ]
        mock.queueResultResponse(multiResult)

        let provider = try await AnkiConnectProvider(host: "localhost", port: 8765, network: mock)
        let response = await provider.getAnkiModels(forProfile: "User 1")

        guard case let .success(models) = response else {
            Issue.record("Expected success response")
            return
        }

        #expect(models.count == 2)

        let basic = try #require(models.first { $0.name == "Basic" })
        #expect(basic.id == "100")
        #expect(basic.fields == ["Front", "Back"])

        let cloze = try #require(models.first { $0.name == "Cloze" })
        #expect(cloze.id == "200")
        #expect(cloze.fields == ["Text", "Extra"])
    }
}
