import Foundation
@testable import MaruReader
import Testing

struct KanjiBankIteratorTests {
    // MARK: - V3

    @Test func kanjiBankIterator_V3Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V3 format data
        // Layout per KanjiBankV3Entry: char, onyomi string, kunyomi string, tags string, meanings array, stats object
        let jsonString = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", ["Chinese", "Han"], {"frequency":"120", "grade":"6"}],
            ["日", "ニチ ジツ", "ひ か", "jlpt-n5", ["sun", "day", "Japan"], {"frequency":"5", "grade":"1"}],
            ["木", "モク ボク", "き こ", "", ["tree", "wood"], {"frequency":"30"}],
            ["仮", "", "かり", "jlpt-n2", [], {}]
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
            bankURLs: [tempURL]
        )

        var entries: [KanjiBankV3Entry] = []
        for try await entry in iterator {
            entries.append(entry)
        }

        #expect(entries.count == 4)
        // First
        #expect(entries[0].character == "漢")
        #expect(entries[0].onyomi == ["カン", "ケン"])
        #expect(entries[0].kunyomi == ["かん"])
        #expect(entries[0].tags == ["jlpt-n1", "joyo"])
        #expect(entries[0].meanings == ["Chinese", "Han"])
        #expect(entries[0].stats["frequency"] == "120")
        #expect(entries[0].stats["grade"] == "6")
        // Third has empty tags, verify splitting => []
        #expect(entries[2].tags.isEmpty)
        // Fourth has empty onyomi & meanings
        #expect(entries[3].onyomi.isEmpty)
        #expect(entries[3].meanings.isEmpty)
    }

    // MARK: - V1

    @Test func kanjiBankIterator_V1Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V1 format data
        // Layout V1: char, onyomi string, kunyomi string, tags string, optional meanings...
        let jsonString = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", "Chinese", "Han"],
            ["日", "ニチ ジツ", "ひ か", "jlpt-n5", "sun", "day", "Japan"],
            ["木", "モク ボク", "き こ", "", "tree"],
            ["人", "ジン ニン", "ひと", "", "person", "human"],
            ["仮", "", "かり", "jlpt-n2"]
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_v1.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<KanjiBankV1Entry>(
            bankURLs: [tempURL]
        )

        var entries: [KanjiBankV1Entry] = []
        for try await entry in iterator {
            entries.append(entry)
        }

        #expect(entries.count == 5)
        #expect(entries[0].character == "漢")
        #expect(entries[0].onyomi == ["カン", "ケン"])
        #expect(entries[0].kunyomi == ["かん"]) // single kunyomi
        #expect(entries[0].tags == ["jlpt-n1", "joyo"])
        #expect(entries[0].meanings == ["Chinese", "Han"])
        // Entry with empty tags string => []
        #expect(entries[2].tags.isEmpty)
        // Entry with two meanings
        #expect(entries[3].meanings == ["person", "human"])
        // Entry with no meanings (only the 4 base fields)
        #expect(entries[4].meanings.isEmpty)
        #expect(entries[4].onyomi.isEmpty)
    }

    // MARK: - Multiple Files (V3)

    @Test func kanjiBankIterator_MultipleFiles_StreamsAllKanji() async throws {
        let jsonString1 = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", ["Chinese"], {"frequency":"120"}]
        ]
        """
        let jsonString2 = """
        [
            ["日", "ニチ ジツ", "ひ か", "jlpt-n5", ["sun", "day"], {"frequency":"5"}],
            ["木", "モク", "き", "", ["tree"], {}]
        ]
        """
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_part1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_part2.json")
        try jsonString1.write(to: tempURL1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: tempURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }

        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
            bankURLs: [tempURL1, tempURL2]
        )

        var chars: [String] = []
        for try await entry in iterator {
            chars.append(entry.character)
        }
        #expect(chars == ["漢", "日", "木"]) // preserve file order then array order
    }

    // MARK: - Invalid Data (V3)

    @Test func kanjiBankIterator_InvalidData_ThrowsError() async throws {
        // Second element is invalid (object) -> should throw after first valid entry emitted.
        let jsonString = """
        [
            ["漢", "カン ケン", "かん", "jlpt-n1 joyo", ["Chinese"], {"frequency":"120"}],
            {"invalid": true}
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_invalid.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
            bankURLs: [tempURL]
        )

        var parsed: [KanjiBankV3Entry] = []
        var errorOccurred = false
        do {
            for try await entry in iterator {
                parsed.append(entry)
            }
        } catch {
            errorOccurred = true
        }
        #expect(errorOccurred)
        #expect(parsed.count == 1)
        #expect(parsed.first?.character == "漢")
    }

    // MARK: - Empty & No Files (V3)

    @Test func kanjiBankIterator_EmptyFiles_ReturnsNoKanji() async throws {
        let jsonString = "[]"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_bank_empty.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
            bankURLs: [tempURL]
        )

        var count = 0
        for try await _ in iterator {
            count += 1
        }
        #expect(count == 0)
    }

    @Test func kanjiBankIterator_NoFiles_ReturnsNoKanji() async throws {
        let iterator = StreamingBankIterator<KanjiBankV3Entry>(
            bankURLs: []
        )
        var count = 0
        for try await _ in iterator {
            count += 1
        }
        #expect(count == 0)
    }
}
