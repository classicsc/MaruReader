// AudioSourceListResponseTests.swift
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
