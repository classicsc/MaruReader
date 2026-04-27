// WebContentRuleListCompilerTests.swift
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

struct WebContentRuleListCompilerTests {
    @Test func partition_withEmptyArray_returnsNoChunks() throws {
        let chunks = try WebContentRuleListCompiler.partition(
            ruleListJSON: "[]",
            maxRulesPerChunk: 100
        )
        #expect(chunks.isEmpty)
    }

    @Test func partition_belowLimit_returnsSingleChunk() throws {
        let json = "[{\"a\":1},{\"a\":2},{\"a\":3}]"
        let chunks = try WebContentRuleListCompiler.partition(
            ruleListJSON: json,
            maxRulesPerChunk: 100
        )
        #expect(chunks.count == 1)
        #expect(chunks[0].ruleCount == 3)
    }

    @Test func partition_aboveLimit_splitsIntoChunks() throws {
        let count = 1003
        let array = (0 ..< count).map { ["a": $0] }
        let data = try JSONSerialization.data(withJSONObject: array)
        let json = try #require(String(data: data, encoding: .utf8))
        let chunks = try WebContentRuleListCompiler.partition(
            ruleListJSON: json,
            maxRulesPerChunk: 200
        )
        #expect(chunks.count == 6)
        let total = chunks.reduce(0) { $0 + $1.ruleCount }
        #expect(total == count)
        #expect(chunks.last?.ruleCount == count - 5 * 200)
        for (offset, chunk) in chunks.dropLast().enumerated() {
            _ = offset
            #expect(chunk.ruleCount == 200)
        }
    }

    @Test func partition_nonArrayInput_throws() {
        #expect(throws: WebContentRuleListCompileError.self) {
            _ = try WebContentRuleListCompiler.partition(
                ruleListJSON: "{\"not\": \"array\"}",
                maxRulesPerChunk: 100
            )
        }
    }

    @Test func partition_chunksAreRoundTrippableJSON() throws {
        let array: [[String: Any]] = (0 ..< 25).map { ["url-filter": ".*\($0)"] }
        let json = try #require(String(data: JSONSerialization.data(withJSONObject: array), encoding: .utf8))
        let chunks = try WebContentRuleListCompiler.partition(
            ruleListJSON: json,
            maxRulesPerChunk: 10
        )
        for chunk in chunks {
            let parsed = try JSONSerialization.jsonObject(with: Data(chunk.json.utf8))
            #expect(parsed is [Any])
            #expect((parsed as? [Any])?.count == chunk.ruleCount)
        }
    }
}
