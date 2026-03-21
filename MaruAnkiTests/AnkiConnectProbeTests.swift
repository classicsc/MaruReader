// AnkiConnectProbeTests.swift
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
import Testing

struct AnkiConnectProbeTests {
    @Test func fetchProfiles_returnsProfilesAndActiveSelection() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse(["User 1", "User 2"])
        mock.queueResultResponse("User 2")

        let probe = AnkiConnectProbe(network: mock)
        let profiles = try await probe.fetchProfiles(connection: .init(host: "localhost", port: 8765, apiKey: nil))

        #expect(profiles.count == 2)
        #expect(profiles.first { $0.id == "User 2" }?.isActiveProfile == true)
    }

    @Test func fetchDecks_returnsDecksForActiveProfile() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 1")
        mock.queueResultResponse(["Default": 1, "Japanese": 2])

        let probe = AnkiConnectProbe(network: mock)
        let decks = try await probe.fetchDecks(
            connection: .init(host: "localhost", port: 8765, apiKey: nil),
            profileName: "User 1"
        )

        #expect(decks.count == 2)
        #expect(decks.contains { $0.name == "Default" && $0.id == "1" })
        #expect(decks.contains { $0.name == "Japanese" && $0.id == "2" })
    }

    @Test func fetchModels_returnsModelsForActiveProfile() async throws {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 1")
        mock.queueResultResponse(["Basic": 100, "Cloze": 200])
        mock.queueResultResponse([
            ["result": ["Front", "Back"], "error": NSNull()],
            ["result": ["Text", "Extra"], "error": NSNull()],
        ])

        let probe = AnkiConnectProbe(network: mock)
        let models = try await probe.fetchModels(
            connection: .init(host: "localhost", port: 8765, apiKey: nil),
            profileName: "User 1"
        )

        #expect(models.count == 2)
        #expect(models.first { $0.name == "Basic" }?.fields == ["Front", "Back"])
        #expect(models.first { $0.name == "Cloze" }?.fields == ["Text", "Extra"])
    }

    @Test func fetchProfiles_propagatesPermissionDenied() async {
        let mock = MockNetworkProvider()
        mock.queueResultResponse([
            "permission": "denied",
            "requireApiKey": false,
            "version": 6,
        ])

        let probe = AnkiConnectProbe(network: mock)

        await #expect(throws: AnkiConnectError.permissionDenied) {
            try await probe.fetchProfiles(connection: .init(host: "localhost", port: 8765, apiKey: nil))
        }
    }

    @Test func fetchProfiles_propagatesApiKeyRequired() async {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse(requireApiKey: true)

        let probe = AnkiConnectProbe(network: mock)

        await #expect(throws: AnkiConnectError.apiKeyRequired) {
            try await probe.fetchProfiles(connection: .init(host: "localhost", port: 8765, apiKey: nil))
        }
    }

    @Test func fetchDecks_propagatesProfileMismatch() async {
        let mock = MockNetworkProvider()
        mock.queuePermissionGrantedResponse()
        mock.queueResultResponse("User 2")

        let probe = AnkiConnectProbe(network: mock)

        await #expect(throws: AnkiConnectError.profileMismatch(expected: "User 1", actual: "User 2")) {
            try await probe.fetchDecks(
                connection: .init(host: "localhost", port: 8765, apiKey: nil),
                profileName: "User 1"
            )
        }
    }
}
