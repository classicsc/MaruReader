// TermBankIteratorTests.swift
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

internal import AsyncAlgorithms
import Foundation
@testable import MaruDictionaryManagement
import Testing

struct TermBankIteratorTests {
    @Test func termBankIterator_V3Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V3 format data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            ["飲む", "のむ", "v5m", "B", 95, ["to drink"], 2, "common"],
            ["走る", "はしる", "v5r", "C", 90, ["to run"], 3, "common"],
            ["説明", "せつめい", "n", "", 80, [
                {"type":"structured-content","content":[
                    "An explanation:",
                    {"tag":"ul","content":[
                        {"tag":"li","content":"Detail 1"},
                        {"tag":"li","content":{"tag":"strong","content":"Important"}}
                    ]},
                    {"tag":"a","href":"https://example.com","content":"More info"}
                ]}
            ], 0, "info"],
            ["画像", "がぞう", "n", "", 70, [
                {"type":"structured-content","content":{
                    "tag":"figure","content":[
                        {"tag":"img","path":"pic.png","width":128,"height":64,"alt":"Picture"},
                        {"tag":"figcaption","content":"A picture"}
                    ]
                }}
            ], -1, "media"]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL]
        )

        let terms = try await Array(iterator)

        #expect(terms.count == 5)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        #expect(terms[0].definitionTags == ["v1"])
        #expect(terms[0].rules == ["A"])
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == 1)
        #expect(terms[0].termTags == ["common"])

        // Check second term
        #expect(terms[1].expression == "飲む")
        #expect(terms[1].reading == "のむ")
        #expect(terms[1].definitionTags == ["v5m"])
        #expect(terms[1].rules == ["B"])
        #expect(terms[1].score == 95)
        #expect(terms[1].sequence == 2)

        // Check third term
        #expect(terms[2].expression == "走る")
        #expect(terms[2].reading == "はしる")
        #expect(terms[2].definitionTags == ["v5r"])
        #expect(terms[2].rules == ["C"])
        #expect(terms[2].score == 90)
        #expect(terms[2].sequence == 3)

        // Check fourth term with complex structured-content array
        #expect(terms[3].expression == "説明")
        #expect(terms[3].reading == "せつめい")
        #expect(terms[3].rules == [])
        #expect(terms[3].score == 80)
        #expect(terms[3].sequence == 0)
        let glossary3 = terms[3].glossary
        #expect(glossary3.count == 1)
        let glossary3JSONObject = try glossaryJSONObject(glossary3[0])
        let glossary3Object = try #require(glossary3JSONObject)
        #expect(glossary3Object["type"] as? String == "structured-content")
        let glossary3Content = try #require(glossary3Object["content"] as? [Any])
        #expect(glossary3Content.count == 3)
        #expect(glossary3Content[0] as? String == "An explanation:")
        let ulElement = try #require(glossary3Content[1] as? [String: Any])
        #expect(ulElement["tag"] as? String == "ul")
        let ulChildren = try #require(ulElement["content"] as? [Any])
        #expect(ulChildren.count == 2)
        let li1 = try #require(ulChildren[0] as? [String: Any])
        #expect(li1["tag"] as? String == "li")
        #expect(li1["content"] as? String == "Detail 1")
        let li2 = try #require(ulChildren[1] as? [String: Any])
        #expect(li2["tag"] as? String == "li")
        let strongElement = try #require(li2["content"] as? [String: Any])
        #expect(strongElement["tag"] as? String == "strong")
        let anchorElement = try #require(glossary3Content[2] as? [String: Any])
        #expect(anchorElement["tag"] as? String == "a")
        #expect(anchorElement["href"] as? String == "https://example.com")
        #expect(anchorElement["content"] as? String == "More info")

        // Check fifth term with figure/image structured-content
        #expect(terms[4].expression == "画像")
        #expect(terms[4].reading == "がぞう")
        #expect(terms[4].rules == [])
        #expect(terms[4].score == 70)
        #expect(terms[4].sequence == -1)
        let glossary4 = terms[4].glossary
        #expect(glossary4.count == 1)
        let glossary4JSONObject = try glossaryJSONObject(glossary4[0])
        let glossary4Object = try #require(glossary4JSONObject)
        #expect(glossary4Object["type"] as? String == "structured-content")
        let figureElement = try #require(glossary4Object["content"] as? [String: Any])
        #expect(figureElement["tag"] as? String == "figure")
        let figureChildren = try #require(figureElement["content"] as? [Any])
        #expect(figureChildren.count == 2)
        let imgElement = try #require(figureChildren[0] as? [String: Any])
        #expect(imgElement["tag"] as? String == "img")
        #expect(imgElement["path"] as? String == "pic.png")
        #expect(imgElement["width"] as? Double == 128)
        #expect(imgElement["height"] as? Double == 64)
        #expect(imgElement["alt"] as? String == "Picture")
        let captionElement = try #require(figureChildren[1] as? [String: Any])
        #expect(captionElement["tag"] as? String == "figcaption")
        #expect(captionElement["content"] as? String == "A picture")
    }

    @Test func termBankIterator_V1Format_ParsesCorrectly() async throws {
        // Create a temporary test file with V1 format data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, "to eat", "to consume food"],
            ["飲む", "のむ", "v5m", "B", 95, "to drink"],
            ["走る", "はしる", "v5r", "C", 90, "to run", "to move quickly on foot"]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v1.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV1Entry>(
            bankURLs: [tempURL]
        )

        let terms = try await Array(iterator)

        #expect(terms.count == 3)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        #expect(terms[0].definitionTags == ["v1"])
        #expect(terms[0].rules == ["A"])
        #expect(terms[0].score == 100)
        #expect(terms[0].glossary.count == 2)

        // Check second term (single definition)
        #expect(terms[1].expression == "飲む")
        #expect(terms[1].glossary.count == 1)

        // Check third term (multiple definitions)
        #expect(terms[2].expression == "走る")
        #expect(terms[2].glossary.count == 2)
    }

    @Test func termBankIterator_V3Format_ParsesNullDefinitionTagsAndDeinflectionGlossary() async throws {
        let jsonString = """
        [
            ["見た", "みた", null, "", 42, [["見る", ["v1", "past"]]], 9, ""]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v3_null_tags.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL]
        )

        let terms = try await Array(iterator)
        let term = try #require(terms.first)

        #expect(term.definitionTags == nil)
        #expect(term.rules.isEmpty)
        #expect(term.termTags.isEmpty)
        #expect(term.sequence == 9)
        #expect(term.score == 42)
        let glossaryData = try JSONEncoder().encode(term.glossary[0])
        let glossaryJSONObject = try #require(try JSONSerialization.jsonObject(with: glossaryData) as? [Any])
        #expect(glossaryJSONObject.count == 2)
        #expect(glossaryJSONObject[0] as? String == "見る")
        #expect(glossaryJSONObject[1] as? [String] == ["v1", "past"])
    }

    @Test func termBankIterator_MultipleFiles_StreamsAllTerms() async throws {
        // Create multiple temporary test files
        let jsonString1 = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            ["飲む", "のむ", "v5m", "B", 95, ["to drink"], 2, "common"]
        ]
        """

        let jsonString2 = """
        [
            ["走る", "はしる", "v5r", "C", 90, ["to run"], 3, "common"],
            ["歩く", "あるく", "v5k", "D", 85, ["to walk"], 4, "common"]
        ]
        """

        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_2.json")
        try jsonString1.write(to: tempURL1, atomically: true, encoding: .utf8)
        try jsonString2.write(to: tempURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL1, tempURL2]
        )

        let terms = try await Array(iterator)

        #expect(terms.count == 4)
        #expect(terms[0].expression == "食べる")
        #expect(terms[1].expression == "飲む")
        #expect(terms[2].expression == "走る")
        #expect(terms[3].expression == "歩く")
    }

    @Test func termBankIterator_InvalidData_ThrowsError() async throws {
        // Create a temporary test file with invalid data
        let jsonString = """
        [
            ["食べる", "たべる", "v1", "A", 100, ["to eat"], 1, "common"],
            {"invalid": "object"}
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_throwing.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL]
        ).makeAsyncIterator()

        let term1 = try await iterator.next()
        var errorOccurred = false
        do {
            _ = try await iterator.next()
        } catch {
            errorOccurred = true
        }

        #expect(errorOccurred)
        #expect(term1?.expression == "食べる") // Only the first valid entry should be parsed
    }

    @Test func termBankIterator_EmptyFiles_ReturnsNoTerms() async throws {
        // Create an empty JSON array file
        let jsonString = "[]"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_empty.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL]
        )

        let terms = try await Array(iterator)

        #expect(terms.count == 0)
    }

    @Test func termBankIterator_NoFiles_ReturnsNoTerms() async throws {
        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: []
        )

        let terms = try await Array(iterator)

        #expect(terms.count == 0)
    }
}

private func glossaryJSONObject(_ value: some Encodable) throws -> [String: Any]? {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any]
}
