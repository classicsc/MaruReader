//
//  AudioSourceIndexParsingTests.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import Foundation
@testable import MaruReaderCore
import Testing

struct AudioSourceIndexParsingTests {
    @Test func audioSourceIndex_FullFormat_ParsesCorrectly() throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test Audio Source",
                "year": 2025,
                "version": 2,
                "media_dir": "media",
                "media_dir_abs": "https://example.com/audio"
            },
            "headwords": {
                "私": ["file1.ogg", "file2.ogg"],
                "僕": ["file3.ogg"]
            },
            "files": {
                "file1.ogg": {
                    "kana_reading": "わたし",
                    "pitch_pattern": "わたし━",
                    "pitch_number": "0"
                },
                "file2.ogg": {
                    "kana_reading": "わたくし",
                    "pitch_pattern": "わたくし━",
                    "pitch_number": "0"
                },
                "file3.ogg": {
                    "kana_reading": "ぼく",
                    "pitch_pattern": "ぼく┐",
                    "pitch_number": "1"
                }
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let index = try decoder.decode(AudioSourceIndex.self, from: data)

        // Verify meta
        #expect(index.meta.name == "Test Audio Source")
        #expect(index.meta.year == 2025)
        #expect(index.meta.version == 2)
        #expect(index.meta.mediaDir == "media")
        #expect(index.meta.mediaDirAbs == "https://example.com/audio")

        // Verify headwords
        #expect(index.headwords.count == 2)
        #expect(index.headwords["私"] == ["file1.ogg", "file2.ogg"])
        #expect(index.headwords["僕"] == ["file3.ogg"])

        // Verify files
        #expect(index.files.count == 3)

        let file1 = index.files["file1.ogg"]
        #expect(file1?.kanaReading == "わたし")
        #expect(file1?.pitchPattern == "わたし━")
        #expect(file1?.pitchNumber == "0")

        let file2 = index.files["file2.ogg"]
        #expect(file2?.kanaReading == "わたくし")

        let file3 = index.files["file3.ogg"]
        #expect(file3?.kanaReading == "ぼく")
        #expect(file3?.pitchNumber == "1")
    }

    @Test func audioSourceIndex_LocalSource_ParsesWithoutMediaDirAbs() throws {
        let jsonString = """
        {
            "meta": {
                "name": "Local Audio",
                "media_dir": "audio_files"
            },
            "headwords": {},
            "files": {}
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let index = try decoder.decode(AudioSourceIndex.self, from: data)

        #expect(index.meta.name == "Local Audio")
        #expect(index.meta.mediaDir == "audio_files")
        #expect(index.meta.mediaDirAbs == nil)
        #expect(index.meta.year == nil)
        #expect(index.meta.version == nil)
    }

    @Test func audioSourceIndex_OnlineSource_ParsesWithMediaDirAbs() throws {
        let jsonString = """
        {
            "meta": {
                "name": "Online Audio",
                "media_dir_abs": "https://cdn.example.com/audio/"
            },
            "headwords": {},
            "files": {}
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let index = try decoder.decode(AudioSourceIndex.self, from: data)

        #expect(index.meta.name == "Online Audio")
        #expect(index.meta.mediaDir == nil)
        #expect(index.meta.mediaDirAbs == "https://cdn.example.com/audio/")
    }

    @Test func audioFileInfo_OptionalFields_ParsesCorrectly() throws {
        let jsonString = """
        {
            "kana_reading": "たべる"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let info = try decoder.decode(AudioFileInfo.self, from: data)

        #expect(info.kanaReading == "たべる")
        #expect(info.pitchPattern == nil)
        #expect(info.pitchNumber == nil)
    }

    @Test func audioFileInfo_AllFields_ParsesCorrectly() throws {
        let jsonString = """
        {
            "kana_reading": "たべる",
            "pitch_pattern": "たべる┐",
            "pitch_number": "2"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let info = try decoder.decode(AudioFileInfo.self, from: data)

        #expect(info.kanaReading == "たべる")
        #expect(info.pitchPattern == "たべる┐")
        #expect(info.pitchNumber == "2")
    }
}
