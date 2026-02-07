// GlossaryCompressionCodecTests.swift
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

struct GlossaryCompressionCodecTests {
    @Test func encodeDecodeGlossaryJSON_roundTrip_returnsOriginalJSON() {
        let jsonData = Data(#"["to eat",{"type":"text","text":"Detailed definition"}]"#.utf8)

        let encoded = GlossaryCompressionCodec.encodeGlossaryJSON(jsonData)
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(encoded)

        #expect(decoded == jsonData)
    }

    @Test func decodeDefinitions_roundTrip_returnsDefinitions() throws {
        let definitions: [Definition] = [.text("to eat"), .text("to consume")]
        let jsonData = try JSONEncoder().encode(definitions)
        let encoded = GlossaryCompressionCodec.encodeGlossaryJSON(jsonData)

        let decoded = GlossaryCompressionCodec.decodeDefinitions(from: encoded)

        #expect(decoded?.count == 2)
        if case let .text(firstDefinition) = decoded?[0] {
            #expect(firstDefinition == "to eat")
        } else {
            Issue.record("Expected first definition to be .text")
        }
    }

    @Test func decodeGlossaryJSON_corruptedPayload_returnsNil() {
        let jsonData = Data(#"["to eat"]"#.utf8)
        var encoded = GlossaryCompressionCodec.encodeGlossaryJSON(jsonData)
        #expect(encoded.count > 8)

        encoded[8] ^= 0xFF
        let decoded = GlossaryCompressionCodec.decodeGlossaryJSON(encoded)

        #expect(decoded == nil)
    }
}
