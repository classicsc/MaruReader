import Foundation
@testable import MaruReaderCore
import Testing

struct TermMetaBankIteratorTests {
    @Test func termMetaIterator_V3Format_ParsesComplexEntries() async throws {
        // Mix of frequency (number), frequency with reading, complex pitch, and IPA with multiple transcriptions.
        let jsonString = """
        [
            ["食べる", "freq", 1500],
            ["読む", "freq", {"reading": "よむ", "frequency": {"value": 3200, "displayValue": "3.2k"}}],
            ["歩く", "pitch", {"reading": "あるく", "pitches": [
                {"position": "HLL", "nasal": [1], "devoice": [2,3], "tags": ["v5k", "intransitive"]},
                {"position": 0, "tags": ["heiban"]},
                {"position": 3, "nasal": 2, "devoice": [4], "tags": ["alt"]}
            ]}],
            ["美しい", "ipa", {"reading": "うつくしい", "transcriptions": [
                {"ipa": "/utsukʊʃiː/", "tags": ["adjective", "formal"]},
                {"ipa": "/utsukushiː/"}
            ]}]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_meta_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [tempURL])

        var entries: [TermMetaBankV3Entry] = []
        for try await entry in iterator {
            entries.append(entry)
        }

        #expect(entries.count == 4)

        // 1. Simple frequency number
        #expect(entries[0].term == "食べる")
        #expect(entries[0].kind == .freq)
        switch entries[0].data {
        case let .frequency(freq):
            #expect(freq.value == 1500)
            #expect(freq.displayValue == nil)
        default: #expect(Bool(false), "Expected frequency data")
        }

        // 2. Frequency with reading object
        #expect(entries[1].term == "読む")
        switch entries[1].data {
        case let .frequencyWithReading(rf):
            #expect(rf.reading == "よむ")
            #expect(rf.frequency.value == 3200)
            #expect(rf.frequency.displayValue == "3.2k")
        default: #expect(Bool(false), "Expected frequency-with-reading data")
        }

        // 3. Complex pitch entry
        #expect(entries[2].term == "歩く")
        #expect(entries[2].kind == .pitch)
        switch entries[2].data {
        case let .pitch(pitch):
            #expect(pitch.reading == "あるく")
            #expect(pitch.pitches.count == 3)
            // First accent pattern HLL with nasal [1], devoice [2,3]
            if case let .pattern(p) = pitch.pitches[0].position { #expect(p == "HLL") } else { #expect(Bool(false)) }
            #expect(pitch.pitches[0].nasal == [1])
            #expect(pitch.pitches[0].devoice == [2, 3])
            #expect(pitch.pitches[0].tags == ["v5k", "intransitive"])
            // Second accent mora 0
            if case let .mora(m0) = pitch.pitches[1].position { #expect(m0 == 0) } else { #expect(Bool(false)) }
            #expect(pitch.pitches[1].nasal == nil)
            // Third accent mora 3 with nasal single (converted to array), devoice [4]
            if case let .mora(m3) = pitch.pitches[2].position { #expect(m3 == 3) } else { #expect(Bool(false)) }
            #expect(pitch.pitches[2].nasal == [2])
            #expect(pitch.pitches[2].devoice == [4])
            #expect(pitch.pitches[2].tags == ["alt"])
        default: #expect(Bool(false), "Expected pitch data")
        }

        // 4. IPA with multiple transcriptions
        #expect(entries[3].term == "美しい")
        switch entries[3].data {
        case let .ipa(ipa):
            #expect(ipa.reading == "うつくしい")
            #expect(ipa.transcriptions.count == 2)
            #expect(ipa.transcriptions[0].ipa == "/utsukʊʃiː/")
            #expect(ipa.transcriptions[0].tags == ["adjective", "formal"])
            #expect(ipa.transcriptions[1].ipa == "/utsukushiː/")
            #expect(ipa.transcriptions[1].tags == nil)
        default: #expect(Bool(false), "Expected IPA data")
        }
    }

    @Test func termMetaIterator_MultipleFiles_StreamsAllEntries() async throws {
        let jsonString1 = """
        [
            ["食べる", "freq", 1500]
        ]
        """
        let jsonString2 = """
        [
            ["歩く", "pitch", {"reading": "あるく", "pitches": [{"position": 0}]}],
            ["美しい", "ipa", {"reading": "うつくしい", "transcriptions": [{"ipa": "/utsukʊʃiː/"}]}]
        ]
        """
        let url1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_meta_bank_1.json")
        let url2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_meta_bank_2.json")
        try jsonString1.write(to: url1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: url2, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url1); try? FileManager.default.removeItem(at: url2) }

        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [url1, url2])
        var terms: [String] = []
        for try await e in iterator {
            terms.append(e.term)
        }
        #expect(terms == ["食べる", "歩く", "美しい"])
    }

    @Test func termMetaIterator_InvalidData_ThrowsAfterValid() async throws {
        let jsonString = """
        [
            ["食べる", "freq", 1500],
            {"invalid": "object"}
        ]
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_meta_bank_invalid.json")
        try jsonString.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [url])
        var collected: [TermMetaBankV3Entry] = []
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
        #expect(collected.first?.term == "食べる")
    }

    @Test func termMetaIterator_EmptyFiles_ReturnsNoEntries() async throws {
        let jsonString = "[]"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_meta_bank_empty.json")
        try jsonString.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [url])
        var any = false
        for try await _ in iterator {
            any = true
        }
        #expect(any == false)
    }

    @Test func termMetaIterator_NoFiles_ReturnsNoEntries() async throws {
        let iterator = StreamingBankIterator<TermMetaBankV3Entry>(bankURLs: [])
        var count = 0
        for try await _ in iterator {
            count += 1
        }
        #expect(count == 0)
    }
}
