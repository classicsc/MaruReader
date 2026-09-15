// YouTubeTranscriptTests.swift
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
@testable import MaruWeb
import Testing

struct YouTubeTranscriptTests {
    @Test(arguments: ["https://www.youtube.com/watch?v=abc_123-XYZ", "https://m.youtube.com/watch?v=abc_123-XYZ&t=4", "https://youtu.be/abc_123-XYZ"])
    func recognizesVideoURLs(_ value: String) {
        #expect(YouTubeVideo.id(from: URL(string: value)) == "abc_123-XYZ")
    }

    @Test(arguments: ["https://youtube.com.evil.test/watch?v=abc", "https://example.com/watch?v=abc", "https://www.youtube.com/", "https://www.youtube.com/watch?v=", "file:///watch?v=abc"])
    func rejectsNonVideoURLs(_ value: String) {
        #expect(YouTubeVideo.id(from: URL(string: value)) == nil)
    }

    @Test func desktopURLPreservesVideoAndTime() throws {
        let url = try #require(URL(string: "https://m.youtube.com/watch?v=abc&t=42&list=playlist"))
        #expect(YouTubeVideo.desktopURL(for: url)?.absoluteString == "https://www.youtube.com/watch?v=abc&t=42&list=playlist")
        #expect(try YouTubeVideo.desktopURL(for: #require(URL(string: "https://example.com"))) == nil)
    }

    @Test func activeCueHandlesBoundariesAndSeekingBackwards() {
        let cues = [YouTubeTranscriptCue(id: 0, start: 1, text: "一"), YouTubeTranscriptCue(id: 1, start: 7, text: "二")]
        #expect(YouTubeTranscriptCue.activeID(in: cues, at: 0) == nil)
        #expect(YouTubeTranscriptCue.activeID(in: cues, at: 1) == 0)
        #expect(YouTubeTranscriptCue.activeID(in: cues, at: 7) == 1)
        #expect(YouTubeTranscriptCue.activeID(in: cues, at: 3) == 0)
        #expect(YouTubeTranscriptCue.activeID(in: [], at: 3) == nil)
    }

    @Test func convertsDOMOffsetsToSwiftCharacters() {
        let cue = YouTubeTranscriptCue(id: 0, start: 0, text: "🐈が猫")
        #expect(cue.characterOffset(forUTF16Offset: 2) == 1)
        #expect(cue.characterOffset(forUTF16Offset: 4) == 2)
        #expect(cue.characterOffset(forUTF16Offset: 5) == nil)
        #expect(cue.characterOffset(forUTF16Offset: -1) == nil)
    }
}
