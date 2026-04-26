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
    @Test func generateCandidates_preservesDistinctDeconjugationProvenance() {
        let generator = DictionaryCandidateGenerator()

        let candidates = generator.generateCandidates(from: "行きましょう")
        let ikuCandidates = candidates.filter { $0.text == "行く" }

        #expect(
            ikuCandidates.contains {
                $0.originalSubstring == "行き" &&
                    $0.deconjugationPaths.contains { path in
                        path.process.contains("(infinitive)") &&
                            path.tags.contains("v5k")
                    }
            }
        )
        #expect(
            ikuCandidates.contains {
                $0.originalSubstring == "行きましょう" &&
                    $0.deconjugationPaths.contains { path in
                        path.process.contains("polite volitional") &&
                            path.process.contains("(infinitive)") &&
                            path.tags.contains("v5k")
                    }
            }
        )
        #expect(Set(ikuCandidates.map(\.originalSubstring)).count >= 2)
    }

    @Test func generateCandidates_attachesTextNormalizationProvenance() {
        let generator = DictionaryCandidateGenerator()

        let candidates = generator.generateCandidates(from: "chikara")

        #expect(candidates.contains {
            $0.text == "chikara" &&
                $0.preprocessorRules == [[]]
        })
        #expect(candidates.contains {
            $0.text == "ちから" &&
                $0.preprocessorRules.contains(["convertAlphabeticToKana"])
        })
    }

    @Test func generateCandidates_deduplicatesExactPreprocessingProvenance() {
        let generator = DictionaryCandidateGenerator()

        let candidates = generator.generateCandidates(from: "chikara")
        let keys = candidates.map { candidate in
            [
                candidate.text,
                candidate.originalSubstring,
                candidate.preprocessorRules.map { $0.joined(separator: "\u{1F}") }.joined(separator: "\u{1E}"),
                candidate.deconjugationPaths.map { path in
                    [
                        path.process.joined(separator: "\u{1F}"),
                        path.tags.joined(separator: "\u{1F}"),
                        String(path.priority),
                    ].joined(separator: "\u{1C}")
                }.joined(separator: "\u{1E}"),
            ].joined(separator: "\u{1D}")
        }

        #expect(keys.count == Set(keys).count)
    }

    @Test func preprocessingProvenance_stillAffectsRanking() {
        let direct = LookupCandidate(
            text: "ちから",
            originalSubstring: "chikara",
            preprocessorRules: [[]],
            deconjugationPaths: []
        )
        let preprocessed = LookupCandidate(
            text: "ちから",
            originalSubstring: "chikara",
            preprocessorRules: [["convertAlphabeticToKana"]],
            deconjugationPaths: []
        )

        #expect(CandidateRankingKey(candidate: direct) > CandidateRankingKey(candidate: preprocessed))
    }

    @Test func candidateRankingKey_prefersLongerGeneratedTermWhenSourceAndPathTie() {
        let path = LookupCandidateDeconjugation(
            process: ["teiru", "(te form)", "(unstressed infinitive)"],
            tags: ["v5m"],
            priority: 3
        )
        let longer = LookupCandidate(
            text: "住む",
            originalSubstring: "住んでいる",
            preprocessorRules: [],
            deconjugationPaths: [path]
        )
        let shorter = LookupCandidate(
            text: "住",
            originalSubstring: "住んでいる",
            preprocessorRules: [],
            deconjugationPaths: [path]
        )

        #expect(CandidateRankingKey(candidate: longer) > CandidateRankingKey(candidate: shorter))
    }
}
