//
//  StreamingAudioSourceIteratorTests.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

import Foundation
@testable import MaruReaderCore
import Testing

struct StreamingAudioSourceIteratorTests {
    // MARK: - Headword Iterator Tests

    @Test func headwordIterator_StreamsAllHeadwords() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test"
            },
            "headwords": {
                "私": ["file1.ogg", "file2.ogg"],
                "僕": ["file3.ogg"],
                "彼": ["file4.ogg", "file5.ogg", "file6.ogg"]
            },
            "files": {}
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_headwords.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingAudioSourceHeadwordIterator(fileURL: tempURL)
        var headwords: [(String, [String])] = []

        for try await (expression, filenames) in iterator {
            headwords.append((expression, filenames))
        }

        #expect(headwords.count == 3)

        // Find each headword (order may vary due to dictionary iteration)
        let watashiEntry = headwords.first { $0.0 == "私" }
        #expect(watashiEntry != nil)
        #expect(watashiEntry?.1 == ["file1.ogg", "file2.ogg"])

        let bokuEntry = headwords.first { $0.0 == "僕" }
        #expect(bokuEntry != nil)
        #expect(bokuEntry?.1 == ["file3.ogg"])

        let kareEntry = headwords.first { $0.0 == "彼" }
        #expect(kareEntry != nil)
        #expect(kareEntry?.1.count == 3)
    }

    @Test func headwordIterator_EmptyHeadwords_ReturnsNoEntries() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test"
            },
            "headwords": {},
            "files": {}
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty_headwords.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingAudioSourceHeadwordIterator(fileURL: tempURL)
        var count = 0

        for try await _ in iterator {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: - File Iterator Tests

    @Test func fileIterator_StreamsAllFiles() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test"
            },
            "headwords": {},
            "files": {
                "file1.ogg": {
                    "kana_reading": "わたし",
                    "pitch_number": "0"
                },
                "file2.ogg": {
                    "kana_reading": "わたくし",
                    "pitch_pattern": "わたくし━"
                },
                "file3.ogg": {
                    "kana_reading": "ぼく"
                }
            }
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_files.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingAudioSourceFileIterator(fileURL: tempURL)
        var files: [(String, AudioFileInfo)] = []

        for try await (filename, info) in iterator {
            files.append((filename, info))
        }

        #expect(files.count == 3)

        // Find each file entry
        let file1 = files.first { $0.0 == "file1.ogg" }
        #expect(file1 != nil)
        #expect(file1?.1.kanaReading == "わたし")
        #expect(file1?.1.pitchNumber == "0")

        let file2 = files.first { $0.0 == "file2.ogg" }
        #expect(file2 != nil)
        #expect(file2?.1.kanaReading == "わたくし")
        #expect(file2?.1.pitchPattern == "わたくし━")

        let file3 = files.first { $0.0 == "file3.ogg" }
        #expect(file3 != nil)
        #expect(file3?.1.kanaReading == "ぼく")
        #expect(file3?.1.pitchNumber == nil)
    }

    @Test func fileIterator_EmptyFiles_ReturnsNoEntries() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test"
            },
            "headwords": {},
            "files": {}
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty_files.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingAudioSourceFileIterator(fileURL: tempURL)
        var count = 0

        for try await _ in iterator {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: - Meta Parser Tests

    @Test func metaParser_ParsesMetaSection() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Test Source",
                "year": 2024,
                "version": 3,
                "media_dir": "audio",
                "media_dir_abs": "https://example.com/audio/"
            },
            "headwords": {
                "test": ["test.ogg"]
            },
            "files": {
                "test.ogg": {
                    "kana_reading": "てすと"
                }
            }
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_meta.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let meta = try AudioSourceMetaParser.parse(from: tempURL)

        #expect(meta.name == "Test Source")
        #expect(meta.year == 2024)
        #expect(meta.version == 3)
        #expect(meta.mediaDir == "audio")
        #expect(meta.mediaDirAbs == "https://example.com/audio/")
    }

    @Test func metaParser_ParsesMinimalMeta() async throws {
        let jsonString = """
        {
            "meta": {
                "name": "Minimal"
            },
            "headwords": {},
            "files": {}
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_minimal_meta.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let meta = try AudioSourceMetaParser.parse(from: tempURL)

        #expect(meta.name == "Minimal")
        #expect(meta.year == nil)
        #expect(meta.version == nil)
        #expect(meta.mediaDir == nil)
        #expect(meta.mediaDirAbs == nil)
    }

    // MARK: - Large File Tests

    @Test func headwordIterator_HandlesLargeFile() async throws {
        // Generate a large JSON with many headwords
        var headwords: [String] = []
        for i in 0 ..< 1000 {
            headwords.append("\"\(i)号\": [\"file\(i).ogg\"]")
        }

        let jsonString = """
        {
            "meta": {
                "name": "Large Test"
            },
            "headwords": {
                \(headwords.joined(separator: ",\n"))
            },
            "files": {}
        }
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_large_headwords.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingAudioSourceHeadwordIterator(fileURL: tempURL)
        var count = 0

        for try await _ in iterator {
            count += 1
        }

        #expect(count == 1000)
    }
}
