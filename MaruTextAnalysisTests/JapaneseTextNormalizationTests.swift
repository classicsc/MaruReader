// JapaneseTextNormalizationTests.swift
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

struct JapaneseTextNormalizationTests {
    @Test func normalizeForLookup_usesSudachiNormalizedForm() {
        #expect(JapaneseTextNormalization.normalizeForLookup("附属") == "付属")
        #expect(JapaneseTextNormalization.normalizeForLookup("SUMMER") == "サマー")
    }

    @Test func generateLookupVariants_originalVariantIsFirst() {
        let variants = JapaneseTextNormalization.generateLookupVariants(for: "ﾖﾐﾁｬﾝ")

        #expect(variants.first == JapaneseTextVariant(text: "ﾖﾐﾁｬﾝ", transformationChain: []))
    }

    @Test func generateLookupVariants_outputOrderIsDeterministic() {
        let first = JapaneseTextNormalization.generateLookupVariants(for: "chikara")
        let second = JapaneseTextNormalization.generateLookupVariants(for: "chikara")

        #expect(first == second)
    }

    @Test func generateLookupVariants_maxVariantsIsHonored() {
        let variants = JapaneseTextNormalization.generateLookupVariants(for: "chikara", maxVariants: 2)

        #expect(variants.count == 2)
        #expect(variants.first?.text == "chikara")
    }

    @Test func generateLookupVariants_zeroMaxVariantsReturnsEmpty() {
        let variants = JapaneseTextNormalization.generateLookupVariants(for: "chikara", maxVariants: 0)

        #expect(variants.isEmpty)
    }

    @Test func generateLookupVariants_preservesProvenanceChainNames() throws {
        let variants = JapaneseTextNormalization.generateLookupVariants(for: "ﾖﾐﾁｬﾝ")
        let converted = try #require(variants.first { $0.text == "ヨミチャン" })

        #expect(converted.transformationChain == ["sudachiNormalizedForm"])
    }

    @Test func generateLookupVariants_generatesKanaRepresentativeCases() {
        expectVariant("ひらがな", includes: "ヒラガナ")
        expectVariant("カタカナ", includes: "かたかな")
        expectVariant("ﾖﾐﾁｬﾝ", includes: "ヨミチャン")
    }

    @Test func generateLookupVariants_generatesRomajiRepresentativeCases() {
        expectVariant("chikara", includes: "ちから")
        expectVariant("CHIKARA", includes: "ちから")
        expectVariant("kka", includes: "っか")
    }

    @Test func generateLookupVariants_generatesAlphanumericWidthRepresentativeCases() {
        expectVariant("abc123", includes: "ａｂｃ１２３")
        expectVariant("ａｂｃ１２３", includes: "abc123")
    }

    @Test func generateLookupVariants_generatesEmphaticAndItaijiRepresentativeCases() {
        expectVariant("すっっごーーい", includes: "すっごーい")
        expectVariant("萬円札", includes: "万円札")
    }

    private func expectVariant(
        _ text: String,
        includes expected: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let variants = JapaneseTextNormalization.generateLookupVariants(for: text, maxVariants: 20)
        #expect(variants.map(\.text).contains(expected), sourceLocation: sourceLocation)
    }
}
