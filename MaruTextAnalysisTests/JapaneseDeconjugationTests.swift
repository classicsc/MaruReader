// JapaneseDeconjugationTests.swift
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

@testable import MaruTextAnalysis
import Testing

struct JapaneseDeconjugationTests {
    @Test func exactFormIsPreserved() {
        let candidates = JapaneseDeconjugator.deconjugate("食べる")

        #expect(candidates.first?.text == "食べる")
        #expect(candidates.first?.process.isEmpty == true)
        #expect(candidates.contains { $0.text == "食べる" && $0.tags.isEmpty })
    }

    @Test func politePastVerbProducesDictionaryForm() {
        let candidates = JapaneseDeconjugator.deconjugate("食べました")

        #expect(candidates.contains { candidate in
            candidate.text == "食べる" &&
                candidate.tags.contains("v1") &&
                candidate.process.contains("past polite")
        })
    }

    @Test func adjectivePastProducesDictionaryForm() {
        let candidates = JapaneseDeconjugator.deconjugate("高かった")

        #expect(candidates.contains { candidate in
            candidate.text == "高い" &&
                candidate.tags.contains("adj-i") &&
                candidate.process.contains("past")
        })
    }

    @Test func contextRuleTeMiruHandlesTePrefix() {
        let positive = JapaneseDeconjugator.deconjugate("食べてみた")

        #expect(positive.contains { $0.text == "食べてみる" })
    }

    @Test func godanPastAndTeiruFormsProduceDictionaryForms() {
        let cases: [(input: String, dictionaryForm: String, tag: String)] = [
            ("建っていた", "建つ", "v5t"),
            ("作った", "作る", "v5r"),
        ]

        for testCase in cases {
            let candidates = JapaneseDeconjugator.deconjugate(testCase.input)

            #expect(candidates.contains { candidate in
                candidate.text == testCase.dictionaryForm &&
                    candidate.tags.last == testCase.tag
            })
        }
    }

    @Test func orderingIsDeterministic() {
        let first = JapaneseDeconjugator.deconjugate("食べさせられた").map {
            "\($0.text)|\($0.tags.joined(separator: ","))|\($0.process.joined(separator: ","))"
        }
        let second = JapaneseDeconjugator.deconjugate("食べさせられた").map {
            "\($0.text)|\($0.tags.joined(separator: ","))|\($0.process.joined(separator: ","))"
        }

        #expect(first == second)
    }
}
