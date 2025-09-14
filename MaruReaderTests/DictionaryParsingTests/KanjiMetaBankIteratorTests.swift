import Foundation
@testable import MaruReader
import Testing

struct KanjiMetaBankIteratorTests {
    @Test func kanjiMetaIterator_V3Format_ParsesMixedFrequencyForms() async throws {
        // Mix of number, string, object(with displayValue), object(without displayValue)
        let jsonString = """
        [
            ["漢", "freq", 123],
            ["日", "freq", "high"],
            ["人", "freq", {"value": 45, "displayValue": "Rank 45"}],
            ["書", "freq", {"value": 7}]
        ]
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_meta_bank_v3.json")
        try jsonString.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [url], dataFormat: 3)
        var entries: [KanjiMetaBankV3Entry] = []
        for try await e in iterator {
            entries.append(e)
        }
        #expect(entries.count == 4)

        // 1. Number frequency
        #expect(entries[0].kanji == "漢")
        switch entries[0].frequency {
        case let .number(v): #expect(v == 123)
        default: #expect(Bool(false), "Expected number frequency")
        }

        // 2. String frequency
        #expect(entries[1].kanji == "日")
        switch entries[1].frequency {
        case let .string(s): #expect(s == "high")
        default: #expect(Bool(false), "Expected string frequency")
        }

        // 3. Object with displayValue
        #expect(entries[2].kanji == "人")
        switch entries[2].frequency {
        case let .object(value, display):
            #expect(value == 45)
            #expect(display == "Rank 45")
        default: #expect(Bool(false), "Expected object frequency with displayValue")
        }

        // 4. Object without displayValue
        #expect(entries[3].kanji == "書")
        switch entries[3].frequency {
        case let .object(value, display):
            #expect(value == 7)
            #expect(display == nil)
        default: #expect(Bool(false), "Expected object frequency without displayValue")
        }
    }

    @Test func kanjiMetaIterator_MultipleFiles_StreamsAllEntries() async throws {
        let jsonString1 = """
        [
            ["漢", "freq", 123]
        ]
        """
        let jsonString2 = """
        [
            ["日", "freq", "high"],
            ["人", "freq", {"value": 45, "displayValue": "Rank 45"}]
        ]
        """
        let url1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_meta_bank_1.json")
        let url2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_meta_bank_2.json")
        try jsonString1.write(to: url1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: url2, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url1); try? FileManager.default.removeItem(at: url2) }

        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [url1, url2], dataFormat: 3)
        var kanji: [String] = []
        for try await e in iterator {
            kanji.append(e.kanji)
        }
        #expect(kanji == ["漢", "日", "人"])
    }

    @Test func kanjiMetaIterator_InvalidData_ThrowsAfterValid() async throws {
        let jsonString = """
        [
            ["漢", "freq", 123],
            ["日", "frequency", 456] // invalid second element
        ]
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_meta_bank_invalid.json")
        try jsonString.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [url], dataFormat: 3)
        var collected: [KanjiMetaBankV3Entry] = []
        var errorOccurred = false
        do {
            for try await e in iterator {
                collected.append(e)
            }
        } catch {
            errorOccurred = true
        }
        #expect(errorOccurred)
        #expect(collected.count == 1)
        #expect(collected.first?.kanji == "漢")
    }

    @Test func kanjiMetaIterator_EmptyFiles_ReturnsNoEntries() async throws {
        let jsonString = "[]"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_kanji_meta_bank_empty.json")
        try jsonString.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [url], dataFormat: 3)
        var any = false
        for try await _ in iterator {
            any = true
        }
        #expect(any == false)
    }

    @Test func kanjiMetaIterator_NoFiles_ReturnsNoEntries() async throws {
        let iterator = StreamingBankIterator<KanjiMetaBankV3Entry>(bankURLs: [], dataFormat: 3)
        var count = 0
        for try await _ in iterator {
            count += 1
        }
        #expect(count == 0)
    }
}
