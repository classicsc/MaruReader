// AudioURLSchemeHandlerTests.swift
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

import CoreData
import Foundation
@testable import MaruReaderCore
import Testing
import WebKit

private struct AudioLookupResponsePayload: Decodable {
    let sources: [AudioLookupSourcePayload]
}

private struct AudioLookupSourcePayload: Decodable {
    let url: String
    let providerName: String
    let itemName: String?
    let pitch: String?
}

private final class MockAudioLookupNetworkProvider: NetworkProviding, @unchecked Sendable {
    var responseQueue: [(Data, URLResponse)] = []

    func data(from url: URL) async throws -> (Data, URLResponse) {
        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    func queueAudioSourceListResponse(audioSources: [[String: String]], statusCode: Int = 200) {
        let sourcesJSON = audioSources.map { source -> [String: Any] in
            var dict: [String: Any] = ["url": source["url"]!]
            if let name = source["name"] {
                dict["name"] = name
            }
            return dict
        }
        let json: [String: Any] = [
            "type": "audioSourceList",
            "audioSources": sourcesJSON,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }
}

struct AudioURLSchemeHandlerTests {
    private func createJSONListAudioSource(in context: NSManagedObjectContext) -> NSManagedObject {
        let source = NSEntityDescription.insertNewObject(forEntityName: "AudioSource", into: context)
        source.setValue(UUID(), forKey: "id")
        source.setValue("Test Source", forKey: "name")
        source.setValue(true, forKey: "enabled")
        source.setValue(Int64(0), forKey: "priority")
        source.setValue(false, forKey: "isLocal")
        source.setValue(false, forKey: "indexedByHeadword")
        source.setValue("https://api.example.com/audio?term={term}", forKey: "urlPattern")
        source.setValue(true, forKey: "urlPatternReturnsJSON")
        source.setValue(Date(), forKey: "dateAdded")
        source.setValue("mp3", forKey: "audioFileExtensions")
        source.setValue(true, forKey: "isComplete")
        source.setValue(false, forKey: "pendingDeletion")
        return source
    }

    private func extractResponse(from results: [URLSchemeTaskResult]) -> HTTPURLResponse? {
        for result in results {
            if case let .response(response) = result {
                return response as? HTTPURLResponse
            }
        }
        return nil
    }

    private func extractData(from results: [URLSchemeTaskResult]) -> Data? {
        for result in results {
            if case let .data(data) = result {
                return data
            }
        }
        return nil
    }

    @Test func lookupEndpointReturnsSources() async throws {
        let mockNetwork = MockAudioLookupNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "日本語 [0]"],
        ])

        let persistenceController = makeDictionaryPersistenceController()
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        let handler = AudioURLSchemeHandler(lookupService: service)
        let request = try URLRequest(url: #require(URL(string: "marureader-audio://lookup?term=日本語&reading=にほんご&language=ja")))
        let results = try await handler.handleRequest(request)

        let response = extractResponse(from: results)
        let data = extractData(from: results)

        #expect(response?.statusCode == 200)
        #expect(response?.value(forHTTPHeaderField: "Access-Control-Allow-Origin") == "*")

        let payload = try JSONDecoder().decode(AudioLookupResponsePayload.self, from: #require(data))
        #expect(payload.sources.count == 1)
        #expect(payload.sources[0].url == "https://audio.example.com/test.mp3")
        #expect(payload.sources[0].providerName == "Test Source")
        #expect(payload.sources[0].itemName == "日本語 [0]")
        #expect(payload.sources[0].pitch == "0")
    }

    @Test func lookupEndpointMissingTermReturnsBadRequest() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: MockAudioLookupNetworkProvider())
        let handler = AudioURLSchemeHandler(lookupService: service)

        let request = try URLRequest(url: #require(URL(string: "marureader-audio://lookup")))
        let results = try await handler.handleRequest(request)
        let response = extractResponse(from: results)

        #expect(response?.statusCode == 400)
    }

    @Test func lookupEndpointReturnsEmptyWhenNoSources() async throws {
        let persistenceController = makeDictionaryPersistenceController()
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: MockAudioLookupNetworkProvider())
        let handler = AudioURLSchemeHandler(lookupService: service)

        let request = try URLRequest(url: #require(URL(string: "marureader-audio://lookup?term=日本語")))
        let results = try await handler.handleRequest(request)
        let data = extractData(from: results)

        let payload = try JSONDecoder().decode(AudioLookupResponsePayload.self, from: #require(data))
        #expect(payload.sources.isEmpty)
    }
}
