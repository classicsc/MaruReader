//
//  AudioSourceListResponseTests.swift
//  MaruReaderCoreTests
//
//  Tests for parsing JSON audio source list responses.
//

import Foundation
@testable import MaruReaderCore
import Testing

struct AudioSourceListResponseTests {
    @Test func parsesValidResponse() throws {
        let json = """
        {
            "type": "audioSourceList",
            "audioSources": [
                {"url": "https://example.com/audio1.mp3", "name": "Source 1"},
                {"url": "https://example.com/audio2.mp3", "name": "Source 2"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)

        #expect(response.type == "audioSourceList")
        #expect(response.audioSources.count == 2)
        #expect(response.audioSources[0].url == "https://example.com/audio1.mp3")
        #expect(response.audioSources[0].name == "Source 1")
        #expect(response.audioSources[1].url == "https://example.com/audio2.mp3")
        #expect(response.audioSources[1].name == "Source 2")
    }

    @Test func parsesResponseWithOptionalName() throws {
        let json = """
        {
            "type": "audioSourceList",
            "audioSources": [
                {"url": "https://example.com/audio.mp3"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)

        #expect(response.type == "audioSourceList")
        #expect(response.audioSources.count == 1)
        #expect(response.audioSources[0].url == "https://example.com/audio.mp3")
        #expect(response.audioSources[0].name == nil)
    }

    @Test func parsesEmptyAudioSources() throws {
        let json = """
        {
            "type": "audioSourceList",
            "audioSources": []
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)

        #expect(response.type == "audioSourceList")
        #expect(response.audioSources.isEmpty)
    }

    @Test func failsWithMissingType() {
        let json = """
        {
            "audioSources": [
                {"url": "https://example.com/audio.mp3"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)
        }
    }

    @Test func failsWithMissingAudioSources() {
        let json = """
        {
            "type": "audioSourceList"
        }
        """
        let data = json.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)
        }
    }

    @Test func failsWithMissingURL() {
        let json = """
        {
            "type": "audioSourceList",
            "audioSources": [
                {"name": "Source without URL"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(AudioSourceListResponse.self, from: data)
        }
    }
}
