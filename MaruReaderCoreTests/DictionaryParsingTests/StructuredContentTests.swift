// StructuredContentTests.swift
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
@testable import MaruReaderCore
import Testing

struct StructuredContentTests {
    // These tests cover decoding of glossary Data into Definition and StructuredContent.
    // Focus: Variant decoding (text, structured, image, deinflection); nested elements.
    // As glossary formats evolve (e.g., new types), these ensure flexible decoding.

    @Test func definitionContentDecode_TextVariant_Succeeds() throws {
        // Purpose: Decode simple text definition.
        // Input: JSON string.
        // Expected: .text variant.
        let jsonString = "\"Simple text definition\""
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(Definition.self, from: data)

        if case let .text(text) = content {
            #expect(text == "Simple text definition")
        } else {
            Issue.record("Expected .text variant")
        }
    }

    @Test func definitionContentDecode_StructuredContentVariant_Succeeds() throws {
        // Purpose: Decode structured-content object.
        // Input: JSON with type and content.
        // Expected: .detailed(.structured) with inner .text content.
        let jsonString = """
        {"type": "structured-content", "content": "Text inside"}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(Definition.self, from: data)

        if case let .detailed(.structured(structuredDef)) = content {
            #expect(structuredDef.type == "structured-content")
            if case let .text(inner) = structuredDef.content {
                #expect(inner == "Text inside")
            } else {
                Issue.record("Expected inner .text")
            }
        } else {
            Issue.record("Expected .detailed(.structured) variant")
        }
    }

    @Test func definitionContentDecode_ImageVariant_Succeeds() throws {
        // Purpose: Decode image definition.
        // Input: JSON with type, path, dimensions.
        // Expected: .detailed(.image) with matching properties.
        let jsonString = """
        {"type": "image", "path": "img.jpg", "width": 100, "height": 200}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(Definition.self, from: data)

        if case let .detailed(.image(img)) = content {
            #expect(img.type == "image")
            #expect(img.path == "img.jpg")
            #expect(img.width == 100)
            #expect(img.height == 200)
        } else {
            Issue.record("Expected .detailed(.image) variant")
        }
    }

    @Test func definitionContentDecode_DeinflectionVariant_Succeeds() throws {
        // Purpose: Decode deinflection array.
        // Input: [term, [rules]] array.
        // Expected: .deinflection with term and rules array.
        let jsonString = """
        ["食べる", ["v1", "transitive"]]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(Definition.self, from: data)

        if case let .deinflection(term, rules) = content {
            #expect(term == "食べる")
            #expect(rules == ["v1", "transitive"])
        } else {
            Issue.record("Expected .deinflection variant")
        }
    }

    @Test func definitionContentDecode_InvalidArray_ThrowsError() throws {
        // Purpose: Handle invalid array structure.
        // Input: Array with wrong count.
        // Expected: Throws DecodingError.dataCorrupted.
        let jsonString = """
        ["only one"]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Definition.self, from: data)
        }
    }

    @Test func structuredContentDecode_NestedArray_Succeeds() throws {
        // Purpose: Decode nested array with mixed content.
        // Input: Array containing text and element.
        // Expected: .array with inner .text and .element.
        let jsonString = """
        ["Text", {"tag": "div", "content": "Nested"}]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(StructuredContent.self, from: data)

        if case let .array(array) = content {
            #expect(array.count == 2)
            if case let .text(text) = array[0] {
                #expect(text == "Text")
            } else {
                Issue.record("Expected first .text")
            }
            if case let .element(elem) = array[1] {
                #expect(elem.tag == "div")
                if case let .text(nestedText) = elem.content {
                    #expect(nestedText == "Nested")
                } else {
                    Issue.record("Expected nested .text content")
                }
            } else {
                Issue.record("Expected second .element")
            }
        } else {
            Issue.record("Expected .array variant")
        }
    }

    @Test func structuredContentDecode_ElementWithAttributes_Succeeds() throws {
        // Purpose: Decode element with attributes like href and style.
        // Input: JSON object for <a> tag.
        // Expected: .element with href, content, and style.
        let jsonString = """
        {"tag": "a", "href": "https://example.com", "content": "Link text", "style": {"fontWeight": "bold"}}
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let content = try decoder.decode(StructuredContent.self, from: data)

        if case let .element(elem) = content {
            #expect(elem.tag == "a")
            #expect(elem.href == "https://example.com")
            #expect(elem.style?.fontWeight == "bold")
            if case let .text(text) = elem.content {
                #expect(text == "Link text")
            } else {
                Issue.record("Expected inner .text")
            }
        } else {
            Issue.record("Expected .element variant")
        }
    }

    @Test func structuredContentDecode_UnknownType_ThrowsError() throws {
        // Purpose: Handle invalid JSON types.
        // Input: Non-string/array/object (e.g., number).
        // Expected: Throws DecodingError.dataCorrupted.
        let jsonString = "42"
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(StructuredContent.self, from: data)
        }
    }

    @Test func definitionArrayDecode_ParseDefinitionsFromData_ReturnsArray() throws {
        // Purpose: Parse array of mixed definitions from Data.
        // Input: JSON array with text and image.
        // Expected: [Definition] with two variants.
        let jsonString = """
        ["Text def", {"type": "image", "path": "img.jpg"}]
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()

        let definitions = try decoder.decode([Definition].self, from: data)

        #expect(definitions.count == 2)
        if case let .text(text) = definitions[0] {
            #expect(text == "Text def")
        } else {
            Issue.record("Expected first .text")
        }
        if case let .detailed(.image(img)) = definitions[1] {
            #expect(img.path == "img.jpg")
        } else {
            Issue.record("Expected second .detailed(.image)")
        }
    }
}
