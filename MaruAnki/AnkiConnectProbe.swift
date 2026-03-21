// AnkiConnectProbe.swift
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

public struct AnkiConnectConnectionInfo: Sendable, Equatable {
    public let host: String
    public let port: Int
    public let apiKey: String?

    public init(host: String, port: Int, apiKey: String?) {
        self.host = host
        self.port = port
        self.apiKey = apiKey
    }
}

public struct AnkiConnectProbe: Sendable {
    private let network: any NetworkProviding

    public init() {
        network = URLSession.shared
    }

    init(network: any NetworkProviding) {
        self.network = network
    }

    public func fetchProfiles(connection: AnkiConnectConnectionInfo) async throws -> [AnkiProfileMeta] {
        let provider = try await provider(for: connection)
        let response = await provider.getAnkiProfiles()
        return try profiles(from: response)
    }

    public func fetchDecks(connection: AnkiConnectConnectionInfo, profileName: String) async throws -> [AnkiDeckMeta] {
        let provider = try await provider(for: connection)
        let response = await provider.getAnkiDecks(forProfile: profileName)
        return try decks(from: response)
    }

    public func fetchModels(connection: AnkiConnectConnectionInfo, profileName: String) async throws -> [AnkiModelMeta] {
        let provider = try await provider(for: connection)
        let response = await provider.getAnkiModels(forProfile: profileName)
        return try models(from: response)
    }

    private func provider(for connection: AnkiConnectConnectionInfo) async throws -> AnkiConnectProvider {
        try await AnkiConnectProvider(
            host: connection.host,
            port: connection.port,
            apiKey: connection.apiKey,
            network: network
        )
    }

    private func profiles(from response: AnkiProfileListingResponse) throws -> [AnkiProfileMeta] {
        switch response {
        case let .success(profiles):
            return profiles
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
    }

    private func decks(from response: AnkiDeckListingResponse) throws -> [AnkiDeckMeta] {
        switch response {
        case let .success(decks):
            return decks
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
    }

    private func models(from response: AnkiModelListingResponse) throws -> [AnkiModelMeta] {
        switch response {
        case let .success(models):
            return models
        case let .failure(error):
            throw error
        case .apiCapabilityMissing:
            throw AnkiConnectionManagerError.providerUnavailable
        }
    }
}
