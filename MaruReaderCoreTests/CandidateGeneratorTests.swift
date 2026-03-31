// CandidateGeneratorTests.swift
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

@testable import MaruReaderCore
import Testing

struct CandidateGeneratorTests {
    @Test func generateCandidates_preservesDistinctDeinflectionProvenance() {
        let generator = DictionaryCandidateGenerator()

        let candidates = generator.generateCandidates(from: "行きましょう")
        let ikuCandidates = candidates.filter { $0.text == "行く" }

        #expect(
            ikuCandidates.contains {
                $0.originalSubstring == "行き" &&
                    $0.deinflectionInputRules == [["continuative"]]
            }
        )
        #expect(
            ikuCandidates.contains {
                $0.originalSubstring == "行きましょう" &&
                    $0.deinflectionInputRules == [["volitional", "-ます"]]
            }
        )
        #expect(Set(ikuCandidates.map(\.originalSubstring)).count >= 2)
    }
}
