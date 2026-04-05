// GlossaryJSONWindowedSamplerTests.swift
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
@testable import MaruDictionaryManagement
import Testing

struct GlossaryJSONWindowedSamplerTests {
    @Test func collectGlossarySamples_v3_extractsGlossariesFromSampledWindows() throws {
        let bankURL = try writeTemporaryBank(
            """
            [
              ["a","a","","",0,["g0"],0,""],
              ["b","b","","",0,["g1"],1,""],
              ["c","c","","",0,["g2"],2,""],
              ["d","d","","",0,["g3"],3,""],
              ["e","e","","",0,["g4"],4,""]
            ]
            """
        )
        defer { try? FileManager.default.removeItem(at: bankURL.deletingLastPathComponent()) }

        let samples = try GlossaryJSONWindowedSampler.collectGlossarySamples(
            from: bankURL,
            format: .v3,
            windowStride: 4,
            windowLength: 1,
            maximumTotalBytes: 1024
        )

        let sampleStrings = samples.compactMap { String(data: $0, encoding: .utf8) }
        #expect(sampleStrings == ["[\"g0\"]", "[\"g4\"]"])
    }

    @Test func collectGlossarySamples_v1_rebuildsRemainingGlossaryElementsAsArray() throws {
        let bankURL = try writeTemporaryBank(
            """
            [
              ["a","a","","",0,"g0","g0b"],
              ["b","b","","",0,"g1"],
              ["c","c","","",0,"g2","g2b"]
            ]
            """
        )
        defer { try? FileManager.default.removeItem(at: bankURL.deletingLastPathComponent()) }

        let samples = try GlossaryJSONWindowedSampler.collectGlossarySamples(
            from: bankURL,
            format: .v1,
            windowStride: 2,
            windowLength: 1,
            maximumTotalBytes: 1024
        )

        let sampleStrings = samples.compactMap { String(data: $0, encoding: .utf8) }
        #expect(sampleStrings == ["[\"g0\",\"g0b\"]", "[\"g2\",\"g2b\"]"])
    }

    private func writeTemporaryBank(_ contents: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let bankURL = directoryURL.appendingPathComponent("term_bank_1.json")
        try Data(contents.utf8).write(to: bankURL, options: .atomic)
        return bankURL
    }
}
