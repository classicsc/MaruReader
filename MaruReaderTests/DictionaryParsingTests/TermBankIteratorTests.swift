//
//  TermBankIteratorTests.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/13/25.
//

import Foundation
@testable import MaruReader
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
            ], 4, "info"],
            ["画像", "がぞう", "n", "", 70, [
                {"type":"structured-content","content":{
                    "tag":"figure","content":[
                        {"tag":"img","path":"pic.png","width":128,"height":64,"alt":"Picture"},
                        {"tag":"figcaption","content":"A picture"}
                    ]
                }}
            ], 5, "media"]
        ]
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_v3.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL],
            dataFormat: 3
        )

        var terms: [ParsedTerm] = []
        for try await entry in iterator {
            let term = ParsedTerm(from: entry)
            terms.append(term)
        }

        #expect(terms.count == 5)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        let definitionTags0 = StringArrayTransformer().reverseTransformedValue(terms[0].definitionTags) as? [String]
        #expect(definitionTags0 == ["v1"])
        #expect(terms[0].rules == "A")
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == 1)
        let termTags0 = StringArrayTransformer().reverseTransformedValue(terms[0].termTags) as? [String]
        #expect(termTags0 == ["common"])

        // Check second term
        #expect(terms[1].expression == "飲む")
        #expect(terms[1].reading == "のむ")
        let definitionTags1 = StringArrayTransformer().reverseTransformedValue(terms[1].definitionTags) as? [String]
        #expect(definitionTags1 == ["v5m"])
        #expect(terms[1].rules == "B")
        #expect(terms[1].score == 95)
        #expect(terms[1].sequence == 2)

        // Check third term
        #expect(terms[2].expression == "走る")
        #expect(terms[2].reading == "はしる")
        let definitionTags2 = StringArrayTransformer().reverseTransformedValue(terms[2].definitionTags) as? [String]
        #expect(definitionTags2 == ["v5r"])
        #expect(terms[2].rules == "C")
        #expect(terms[2].score == 90)
        #expect(terms[2].sequence == 3)

        // Check fourth term with complex structured-content array
        #expect(terms[3].expression == "説明")
        #expect(terms[3].reading == "せつめい")
        let glossary3 = DefinitionArrayTransformer().reverseTransformedValue(terms[3].glossary) as? [Definition]
        #expect(glossary3?.count == 1)
        if let def = glossary3?.first, case let .detailed(.structured(structDef)) = def {
            // Root structured content should be an array
            if case let .array(rootArray) = structDef.content {
                #expect(rootArray.count == 3)
                // 0: text
                if case let .text(t0) = rootArray[0] { #expect(t0 == "An explanation:") } else { Issue.record("Expected first element text") }
                // 1: ul element with two li children
                if case let .element(ulElem) = rootArray[1] {
                    #expect(ulElem.tag == "ul")
                    if case let .array(liArray) = ulElem.content {
                        #expect(liArray.count == 2)
                        if case let .element(li1) = liArray[0] {
                            #expect(li1.tag == "li")
                            if case let .text(liText1) = li1.content { #expect(liText1 == "Detail 1") } else { Issue.record("Expected li1 text") }
                        } else { Issue.record("Expected first li element") }
                        if case let .element(li2) = liArray[1] {
                            #expect(li2.tag == "li")
                            if case let .element(strongElem) = li2.content { #expect(strongElem.tag == "strong") } else { Issue.record("Expected strong element inside second li") }
                        } else { Issue.record("Expected second li element") }
                    } else { Issue.record("Expected ul content array") }
                } else { Issue.record("Expected ul element as second root item") }
                // 2: anchor element
                if case let .element(aElem) = rootArray[2] {
                    #expect(aElem.tag == "a")
                    #expect(aElem.href == "https://example.com")
                    if case let .text(linkText) = aElem.content { #expect(linkText == "More info") } else { Issue.record("Expected link text") }
                } else { Issue.record("Expected anchor element as third root item") }
            } else {
                Issue.record("Expected root structured content array")
            }
        } else {
            Issue.record("Expected structured-content definition for 説明")
        }

        // Check fifth term with figure/image structured-content
        #expect(terms[4].expression == "画像")
        #expect(terms[4].reading == "がぞう")
        let glossary4 = DefinitionArrayTransformer().reverseTransformedValue(terms[4].glossary) as? [Definition]
        #expect(glossary4?.count == 1)
        if let def = glossary4?.first, case let .detailed(.structured(structDef)) = def {
            if case let .element(figureElem) = structDef.content {
                #expect(figureElem.tag == "figure")
                if case let .array(figureChildren) = figureElem.content {
                    #expect(figureChildren.count == 2)
                    // img element
                    if case let .element(imgElem) = figureChildren[0] {
                        #expect(imgElem.tag == "img")
                        #expect(imgElem.path == "pic.png")
                        #expect(imgElem.width == 128)
                        #expect(imgElem.height == 64)
                        #expect(imgElem.alt == "Picture")
                    } else { Issue.record("Expected img element") }
                    // figcaption element
                    if case let .element(captionElem) = figureChildren[1] {
                        #expect(captionElem.tag == "figcaption")
                        if case let .text(captionText) = captionElem.content { #expect(captionText == "A picture") } else { Issue.record("Expected figcaption text") }
                    } else { Issue.record("Expected figcaption element") }
                } else { Issue.record("Expected figure content array") }
            } else { Issue.record("Expected figure element as root structured content") }
        } else {
            Issue.record("Expected structured-content definition for 画像")
        }
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
            bankURLs: [tempURL],
            dataFormat: 1
        )

        var terms: [ParsedTerm] = []
        for try await entry in iterator {
            let term = ParsedTerm(from: entry)
            terms.append(term)
        }

        #expect(terms.count == 3)

        // Check first term
        #expect(terms[0].expression == "食べる")
        #expect(terms[0].reading == "たべる")
        let definitionTags = StringArrayTransformer().reverseTransformedValue(terms[0].definitionTags) as? [String]
        #expect(definitionTags == ["v1"])
        #expect(terms[0].rules == "A")
        #expect(terms[0].score == 100)
        #expect(terms[0].sequence == nil)
        #expect(terms[0].termTags == nil)
        let glossary0 = DefinitionArrayTransformer().reverseTransformedValue(terms[0].glossary) as? [Definition]
        #expect(glossary0?.count == 2)

        // Check second term (single definition)
        #expect(terms[1].expression == "飲む")
        let glossary1 = DefinitionArrayTransformer().reverseTransformedValue(terms[1].glossary) as? [Definition]
        #expect(glossary1?.count == 1)

        // Check third term (multiple definitions)
        #expect(terms[2].expression == "走る")
        let glossary2 = DefinitionArrayTransformer().reverseTransformedValue(terms[2].glossary) as? [Definition]
        #expect(glossary2?.count == 2)
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
            bankURLs: [tempURL1, tempURL2],
            dataFormat: 3
        )

        var terms: [ParsedTerm] = []
        for try await entry in iterator {
            let term = ParsedTerm(from: entry)
            terms.append(term)
        }

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

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL],
            dataFormat: 3
        )

        var terms: [ParsedTerm] = []
        var errorOccurred = false

        do {
            for try await entry in iterator {
                let term = ParsedTerm(from: entry)
                terms.append(term)
            }
        } catch {
            errorOccurred = true
        }

        #expect(errorOccurred)
        #expect(terms.count == 1) // Only the first valid entry should be parsed
    }

    @Test func termBankIterator_EmptyFiles_ReturnsNoTerms() async throws {
        // Create an empty JSON array file
        let jsonString = "[]"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_term_bank_empty.json")
        try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [tempURL],
            dataFormat: 3
        )

        var terms: [ParsedTerm] = []
        for try await entry in iterator {
            let term = ParsedTerm(from: entry)
            terms.append(term)
        }

        #expect(terms.count == 0)
    }

    @Test func termBankIterator_NoFiles_ReturnsNoTerms() async throws {
        let iterator = StreamingBankIterator<TermBankV3Entry>(
            bankURLs: [],
            dataFormat: 3
        )

        var terms: [ParsedTerm] = []
        for try await entry in iterator {
            let term = ParsedTerm(from: entry)
            terms.append(term)
        }

        #expect(terms.count == 0)
    }
}
