// AudioLookupServiceTests.swift
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

/// A mock network provider that captures requests and returns canned responses.
final class MockNetworkProvider: NetworkProviding, @unchecked Sendable {
    /// All URLs that have been requested through this provider.
    private(set) var requestedURLs: [URL] = []

    /// Queue of responses to return. Each call to `data(from:)` pops the first response.
    /// If empty, returns a default empty success response.
    var responseQueue: [(Data, URLResponse)] = []

    /// If set, this error will be thrown instead of returning a response.
    var errorToThrow: Error?

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)

        if let error = errorToThrow {
            throw error
        }

        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }

        // Default empty success response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    /// Queue an audio source list response with given sources.
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

struct AudioLookupServicePitchExtractionTests {
    /// Helper to create an AudioSource entity with all required fields for JSON list pattern testing.
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

    @Test func extractsPitchFromNameWithBracketedNumber() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "日本語 [0]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        // Set up an audio source with JSON list pattern
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "日本語", reading: "にほんご", downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources.count == 1)
        #expect(result.sources[0].pitchNumber == "0")
    }

    @Test func extractsPitchFromNameWithMultiDigitNumber() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "テスト [12]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "テスト", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == "12")
    }

    @Test func extractsPitchFromNameWithCompoundPitchPattern() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "言葉 [3-1]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "言葉", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == "3-1")
    }

    @Test func returnsNilPitchWhenNameHasNoBrackets() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "日本語"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "日本語", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == nil)
    }

    @Test func returnsNilPitchWhenNameIsNil() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "テスト", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == nil)
    }

    @Test func ignoresBracketsWithNonNumericContent() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "日本語 [adjective]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "日本語", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == nil)
    }

    @Test func extractsFirstPitchWhenMultipleBracketsPresent() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test.mp3", "name": "日本語 [0] [1]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "日本語", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        #expect(result.sources[0].pitchNumber == "0")
    }

    @Test func returnsMultipleSourcesForDifferentPitches() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test1.mp3", "name": "example: しょくちょう [0]"],
            ["url": "https://audio.example.com/test2.mp3", "name": "example: しょくちょう [2]"],
            ["url": "https://audio.example.com/test3.mp3", "name": "example: ショクチョウ [0]"], // duplicate pitch
            ["url": "https://audio.example.com/test4.mp3", "name": "example"], // no pitch
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "職長", reading: "しょくちょう", downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        // Should have 3 sources: [0], [2], and one with nil pitch (deduplicated)
        #expect(result.sources.count == 3)

        let pitches = result.sources.map(\.pitchNumber)
        #expect(pitches.contains("0"))
        #expect(pitches.contains("2"))
        #expect(pitches.contains(nil))
    }

    @Test func deduplicatesSamePitchFromMultipleSources() async throws {
        let mockNetwork = MockNetworkProvider()
        mockNetwork.queueAudioSourceListResponse(audioSources: [
            ["url": "https://audio.example.com/test1.mp3", "name": "source1 [0]"],
            ["url": "https://audio.example.com/test2.mp3", "name": "source2 [0]"],
            ["url": "https://audio.example.com/test3.mp3", "name": "source3 [0]"],
        ])

        let persistenceController = DictionaryPersistenceController(inMemory: true)
        let service = AudioLookupService(persistenceController: persistenceController, networkProvider: mockNetwork)

        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = self.createJSONListAudioSource(in: context)
            try context.save()
        }

        try await service.loadProviders()

        let request = AudioLookupRequest(term: "テスト", reading: nil, downstepPosition: nil, language: "ja")
        let result = await service.lookupAudio(for: request)

        #expect(result.hasAudio)
        // Should only have 1 source since all have same pitch [0]
        #expect(result.sources.count == 1)
        #expect(result.sources[0].pitchNumber == "0")
        #expect(result.sources[0].url.absoluteString == "https://audio.example.com/test1.mp3")
    }
}
