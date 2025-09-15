import Foundation
@testable import MaruReader
import Testing

/// Test suite for the JapaneseTextPreprocessor and its rules
/// Verifies text variant generation, caching, and specific preprocessor rules
struct TextPreprocessorTests {
    // MARK: - NormalizeCombiningCharactersRule Tests

    @Test func normalizeCombiningCharacters_DakutenHiragana_NormalizesCorrectly() throws {
        // Purpose: Test dakuten (voiced sound mark) normalization for hiragana
        // Input: Combining dakuten sequences
        // Expected: Properly combined characters
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("か\u{3099}", "が"), // ka + dakuten = ga
            ("き\u{3099}", "ぎ"), // ki + dakuten = gi
            ("く\u{3099}", "ぐ"), // ku + dakuten = gu
            ("け\u{3099}", "げ"), // ke + dakuten = ge
            ("こ\u{3099}", "ご"), // ko + dakuten = go
            ("さ\u{3099}", "ざ"), // sa + dakuten = za
            ("し\u{3099}", "じ"), // shi + dakuten = ji
            ("す\u{3099}", "ず"), // su + dakuten = zu
            ("せ\u{3099}", "ぜ"), // se + dakuten = ze
            ("そ\u{3099}", "ぞ"), // so + dakuten = zo
            ("た\u{3099}", "だ"), // ta + dakuten = da
            ("ち\u{3099}", "ぢ"), // chi + dakuten = dji
            ("つ\u{3099}", "づ"), // tsu + dakuten = dzu
            ("て\u{3099}", "で"), // te + dakuten = de
            ("と\u{3099}", "ど"), // to + dakuten = do
            ("は\u{3099}", "ば"), // ha + dakuten = ba
            ("ひ\u{3099}", "び"), // hi + dakuten = bi
            ("ふ\u{3099}", "ぶ"), // fu + dakuten = bu
            ("へ\u{3099}", "べ"), // he + dakuten = be
            ("ほ\u{3099}", "ぼ"), // ho + dakuten = bo
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_DakutenKatakana_NormalizesCorrectly() throws {
        // Purpose: Test dakuten (voiced sound mark) normalization for katakana
        // Input: Combining dakuten sequences
        // Expected: Properly combined characters
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("カ\u{3099}", "ガ"), // ka + dakuten = ga
            ("キ\u{3099}", "ギ"), // ki + dakuten = gi
            ("ク\u{3099}", "グ"), // ku + dakuten = gu
            ("ケ\u{3099}", "ゲ"), // ke + dakuten = ge
            ("コ\u{3099}", "ゴ"), // ko + dakuten = go
            ("サ\u{3099}", "ザ"), // sa + dakuten = za
            ("シ\u{3099}", "ジ"), // shi + dakuten = ji
            ("ス\u{3099}", "ズ"), // su + dakuten = zu
            ("セ\u{3099}", "ゼ"), // se + dakuten = ze
            ("ソ\u{3099}", "ゾ"), // so + dakuten = zo
            ("タ\u{3099}", "ダ"), // ta + dakuten = da
            ("チ\u{3099}", "ヂ"), // chi + dakuten = dji
            ("ツ\u{3099}", "ヅ"), // tsu + dakuten = dzu
            ("テ\u{3099}", "デ"), // te + dakuten = de
            ("ト\u{3099}", "ド"), // to + dakuten = do
            ("ハ\u{3099}", "バ"), // ha + dakuten = ba
            ("ヒ\u{3099}", "ビ"), // hi + dakuten = bi
            ("フ\u{3099}", "ブ"), // fu + dakuten = bu
            ("ヘ\u{3099}", "ベ"), // he + dakuten = be
            ("ホ\u{3099}", "ボ"), // ho + dakuten = bo
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_HandakutenHiragana_NormalizesCorrectly() throws {
        // Purpose: Test handakuten (semi-voiced sound mark) normalization for hiragana
        // Input: Combining handakuten sequences
        // Expected: Properly combined characters
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("は\u{309A}", "ぱ"), // ha + handakuten = pa
            ("ひ\u{309A}", "ぴ"), // hi + handakuten = pi
            ("ふ\u{309A}", "ぷ"), // fu + handakuten = pu
            ("へ\u{309A}", "ぺ"), // he + handakuten = pe
            ("ほ\u{309A}", "ぽ"), // ho + handakuten = po
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_HandakutenKatakana_NormalizesCorrectly() throws {
        // Purpose: Test handakuten (semi-voiced sound mark) normalization for katakana
        // Input: Combining handakuten sequences
        // Expected: Properly combined characters
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("ハ\u{309A}", "パ"), // ha + handakuten = pa
            ("ヒ\u{309A}", "ピ"), // hi + handakuten = pi
            ("フ\u{309A}", "プ"), // fu + handakuten = pu
            ("ヘ\u{309A}", "ペ"), // he + handakuten = pe
            ("ホ\u{309A}", "ポ"), // ho + handakuten = po
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_InvalidCombinations_IgnoresMarks() throws {
        // Purpose: Test that invalid dakuten/handakuten combinations are ignored
        // Input: Characters that cannot take diacritics + combining marks
        // Expected: Combining marks remain unchanged
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("な\u{3099}", "な\u{3099}"), // na + dakuten (invalid, no change)
            ("な\u{309A}", "な\u{309A}"), // na + handakuten (invalid, no change)
            ("あ\u{3099}", "あ\u{3099}"), // a + dakuten (invalid, no change)
            ("あ\u{309A}", "あ\u{309A}"), // a + handakuten (invalid, no change)
            ("カ\u{309A}", "カ\u{309A}"), // ka + handakuten (invalid, ka can't take handakuten)
            ("ナ\u{3099}", "ナ\u{3099}"), // na + dakuten (invalid, no change)
            ("ナ\u{309A}", "ナ\u{309A}"), // na + handakuten (invalid, no change)
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_LeadingCombiningMarks_IgnoresMarks() throws {
        // Purpose: Test that leading combining marks (first character) are ignored
        // Input: Combining marks at start of string
        // Expected: Marks remain unchanged
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("\u{3099}ハ", "\u{3099}ハ"), // dakuten + ha (no combination)
            ("\u{309A}ハ", "\u{309A}ハ"), // handakuten + ha (no combination)
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_ComplexSequence_NormalizesCorrectly() throws {
        // Purpose: Test complex sequences from Yomitan tests
        // Input: Complex text with multiple combining characters
        // Expected: All valid combinations normalized
        let rule = NormalizeCombiningCharactersRule()

        let testCases = [
            ("さくらし\u{3099}また\u{3099}いこん", "さくらじまだいこん"), // sakurashimadaikon
            ("いっほ\u{309A}ん", "いっぽん"), // ippon
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCombiningCharacters_EmptyString_ReturnsEmpty() throws {
        // Purpose: Test empty string handling
        // Input: Empty string ""
        // Expected: Empty string ""
        let rule = NormalizeCombiningCharactersRule()
        let input = ""

        let result = rule.process(input)

        #expect(result == "")
    }

    @Test func normalizeCombiningCharacters_SingleCharacter_NoChange() throws {
        // Purpose: Test single character input handling
        // Input: Single character without combining marks
        // Expected: Same character
        let rule = NormalizeCombiningCharactersRule()
        let input = "あ"

        let result = rule.process(input)

        #expect(result == "あ")
    }

    @Test func normalizeCombiningCharacters_OnlyCombiningMark_NoChange() throws {
        // Purpose: Test input with only combining mark
        // Input: Single combining mark
        // Expected: Same mark (no character to combine with)
        let rule = NormalizeCombiningCharactersRule()
        let input = "\u{3099}" // Only dakuten

        let result = rule.process(input)

        #expect(result == "\u{3099}")
    }

    @Test func normalizeCombiningCharacters_MixedText_NormalizesOnlyValid() throws {
        // Purpose: Test mixed text with valid and invalid combinations
        // Input: Text containing both valid and invalid combinations
        // Expected: Only valid combinations normalized
        let rule = NormalizeCombiningCharactersRule()
        let input = "か\u{3099}な\u{3099}は\u{309A}" // ga + invalid na + pa

        let result = rule.process(input)

        #expect(result == "がな\u{3099}ぱ") // ga + na with dakuten + pa
    }

    @Test func normalizeCombiningCharactersRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = NormalizeCombiningCharactersRule()

        #expect(rule.name == "normalizeCombiningCharacters")
        #expect(rule.description.contains("combining"))
        #expect(rule.description.contains("dakuten"))
        #expect(rule.description.contains("handakuten"))
    }

    // MARK: - ConvertHalfWidthCharactersRule Tests

    @Test func convertHalfWidthCharacters_BasicKatakana_ConvertsToFullWidth() throws {
        // Purpose: Test basic half-width katakana conversion
        // Input: Half-width katakana string "ﾖﾐﾁｬﾝ"
        // Expected: Full-width katakana "ヨミチャン"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let result = rule.process(input)

        #expect(result == "ヨミチャン")
    }

    @Test func convertHalfWidthCharacters_WithDakuten_ConvertsCorrectly() throws {
        // Purpose: Test conversion with dakuten (voiced sound marks)
        // Input: Half-width katakana with dakuten "ｶﾞ" (ka + dakuten = ga)
        // Expected: Full-width "ガ"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ｶﾞ"

        let result = rule.process(input)

        #expect(result == "ガ")
    }

    @Test func convertHalfWidthCharacters_WithHandakuten_ConvertsCorrectly() throws {
        // Purpose: Test conversion with handakuten (semi-voiced sound marks)
        // Input: Half-width katakana with handakuten "ﾊﾟ" (ha + handakuten = pa)
        // Expected: Full-width "パ"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾊﾟ"

        let result = rule.process(input)

        #expect(result == "パ")
    }

    @Test func convertHalfWidthCharacters_InvalidDakuten_UsesBaseForm() throws {
        // Purpose: Test handling of invalid dakuten combinations
        // Input: Character that can't take dakuten + dakuten mark "ｱﾞ" (a + dakuten = invalid)
        // Expected: Falls back to base form "ア" (dakuten ignored)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ｱﾞ"

        let result = rule.process(input)

        #expect(result == "ア")
    }

    @Test func convertHalfWidthCharacters_MixedText_ConvertsOnlyHalfWidth() throws {
        // Purpose: Test mixed text with half-width and full-width characters
        // Input: Mixed text "abcﾖﾐﾁｬﾝ123"
        // Expected: Only half-width katakana converted "abcヨミチャン123"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "abcﾖﾐﾁｬﾝ123"

        let result = rule.process(input)

        #expect(result == "abcヨミチャン123")
    }

    @Test func convertHalfWidthCharacters_AlreadyFullWidth_NoChange() throws {
        // Purpose: Test that already full-width characters are unchanged
        // Input: Full-width katakana "ヨミチャン"
        // Expected: Same string "ヨミチャン"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ヨミチャン"

        let result = rule.process(input)

        #expect(result == "ヨミチャン")
    }

    @Test func convertHalfWidthCharacters_EmptyString_ReturnsEmpty() throws {
        // Purpose: Test empty string handling
        // Input: Empty string ""
        // Expected: Empty string ""
        let rule = ConvertHalfWidthCharactersRule()
        let input = ""

        let result = rule.process(input)

        #expect(result == "")
    }

    @Test func convertHalfWidthCharacters_ComplexExample_ConvertsAllComponents() throws {
        // Purpose: Test complex real-world example with multiple components
        // Input: Complex half-width text "ｺﾝﾋﾟｭｰﾀｰ･ﾌﾟﾛｸﾞﾗﾑ" (computer program)
        // Expected: Full-width conversion "コンピューター・プログラム"
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ｺﾝﾋﾟｭｰﾀｰ･ﾌﾟﾛｸﾞﾗﾑ"

        let result = rule.process(input)

        #expect(result == "コンピューター・プログラム")
    }

    // MARK: - ConvertKatakanaToHiraganaRule Tests

    @Test func convertKatakanaToHiragana_BasicKatakana_ConvertsToHiragana() throws {
        // Purpose: Test basic katakana to hiragana conversion
        // Input: Katakana string "カタカナ"
        // Expected: Hiragana "かたかな"
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "カタカナ"

        let result = rule.process(input)

        #expect(result == "かたかな")
    }

    @Test func convertKatakanaToHiragana_WithProlongedSoundMark_ConvertsToVowel() throws {
        // Purpose: Test prolonged sound mark conversion to appropriate vowel
        // Input: Katakana with prolonged sound "コーヒー"
        // Expected: Hiragana with vowels "こうひい"
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "コーヒー"

        let result = rule.process(input)

        #expect(result == "こうひい")
    }

    @Test func convertKatakanaToHiragana_SmallKaKe_NoChange() throws {
        // Purpose: Test that small ka/ke characters remain unchanged
        // Input: Katakana with small ka/ke "ヵヶ"
        // Expected: Same characters "ヵヶ" (no conversion)
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "ヵヶ"

        let result = rule.process(input)

        #expect(result == "ヵヶ")
    }

    @Test func convertKatakanaToHiragana_MixedText_ConvertsOnlyKatakana() throws {
        // Purpose: Test mixed text with katakana, hiragana, and other characters
        // Input: Mixed text "あいうエオＡＢＣ"
        // Expected: Only katakana converted "あいうえおＡＢＣ"
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "あいうエオＡＢＣ"

        let result = rule.process(input)

        #expect(result == "あいうえおＡＢＣ")
    }

    @Test func convertKatakanaToHiragana_AlreadyHiragana_NoChange() throws {
        // Purpose: Test that already hiragana characters are unchanged
        // Input: Hiragana "ひらがな"
        // Expected: Same string "ひらがな"
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "ひらがな"

        let result = rule.process(input)

        #expect(result == "ひらがな")
    }

    @Test func convertKatakanaToHiragana_ComplexExample_ConvertsCorrectly() throws {
        // Purpose: Test complex example with various katakana
        // Input: Complex katakana "コンピューター" (computer)
        // Expected: Hiragana "こんぴゅうたあ" (ュー becomes ゅう)
        let rule = ConvertKatakanaToHiraganaRule()
        let input = "コンピューター"

        let result = rule.process(input)

        #expect(result == "こんぴゅうたあ")
    }

    @Test func convertKatakanaToHiragana_KeepProlongedSoundMarks_PreservesMarks() throws {
        // Purpose: Test that prolonged sound marks are preserved when option is set
        // Input: Katakana with prolonged sound "コーヒー" with keepProlongedSoundMarks: true
        // Expected: Hiragana with marks preserved "こーひー"
        let rule = ConvertKatakanaToHiraganaRule(keepProlongedSoundMarks: true)
        let input = "コーヒー"

        let result = rule.process(input)

        #expect(result == "こーひー")
    }

    // MARK: - ConvertHiraganaToKatakanaRule Tests

    @Test func convertHiraganaToKatakana_BasicHiragana_ConvertsToKatakana() throws {
        // Purpose: Test basic hiragana to katakana conversion
        // Input: Hiragana string "ひらがな"
        // Expected: Katakana "ヒラガナ"
        let rule = ConvertHiraganaToKatakanaRule()
        let input = "ひらがな"

        let result = rule.process(input)

        #expect(result == "ヒラガナ")
    }

    @Test func convertHiraganaToKatakana_MixedText_ConvertsOnlyHiragana() throws {
        // Purpose: Test mixed text with hiragana, katakana, and other characters
        // Input: Mixed text "あいうエオＡＢＣ"
        // Expected: Only hiragana converted "アイウエオＡＢＣ"
        let rule = ConvertHiraganaToKatakanaRule()
        let input = "あいうエオＡＢＣ"

        let result = rule.process(input)

        #expect(result == "アイウエオＡＢＣ")
    }

    @Test func convertHiraganaToKatakana_AlreadyKatakana_NoChange() throws {
        // Purpose: Test that already katakana characters are unchanged
        // Input: Katakana "カタカナ"
        // Expected: Same string "カタカナ"
        let rule = ConvertHiraganaToKatakanaRule()
        let input = "カタカナ"

        let result = rule.process(input)

        #expect(result == "カタカナ")
    }

    @Test func convertHiraganaToKatakana_WithDakutenAndHandakuten_ConvertsCorrectly() throws {
        // Purpose: Test conversion of hiragana with dakuten/handakuten marks
        // Input: Hiragana with marks "がぎぐげごばびぶべぼぱぴぷぺぽ"
        // Expected: Katakana with marks "ガギグゲゴバビブベボパピプペポ"
        let rule = ConvertHiraganaToKatakanaRule()
        let input = "がぎぐげごばびぶべぼぱぴぷぺぽ"

        let result = rule.process(input)

        #expect(result == "ガギグゲゴバビブベボパピプペポ")
    }

    @Test func convertHiraganaToKatakana_ComplexExample_ConvertsCorrectly() throws {
        // Purpose: Test complex example with various hiragana
        // Input: Complex hiragana "こんにちは" (hello)
        // Expected: Katakana "コンニチハ"
        let rule = ConvertHiraganaToKatakanaRule()
        let input = "こんにちは"

        let result = rule.process(input)

        #expect(result == "コンニチハ")
    }

    // MARK: - CollapseEmphaticSequencesRule Tests

    @Test func collapseEmphaticSequences_NoEmphaticCharacters_NoChange() throws {
        // Purpose: Test basic text with no emphatic characters
        // Input: Text without emphatic sequences "かこい"
        // Expected: No change regardless of fullCollapse setting
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "かこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "かこい")
        #expect(resultFull == "かこい")
    }

    @Test func collapseEmphaticSequences_SingleSmallTsu_NoChange() throws {
        // Purpose: Test single small tsu characters
        // Input: Text with single small tsu "かっこい"
        // Expected: No change in normal mode, collapse in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "かっこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "かっこい")
        #expect(resultFull == "かこい")
    }

    @Test func collapseEmphaticSequences_DoubleSmallTsu_CollapseToSingle() throws {
        // Purpose: Test double small tsu collapse
        // Input: Text with double small tsu "かっっこい"
        // Expected: Collapse to single in normal mode, full collapse in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "かっっこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "かっこい")
        #expect(resultFull == "かこい")
    }

    @Test func collapseEmphaticSequences_TripleSmallTsu_CollapseToSingle() throws {
        // Purpose: Test triple small tsu collapse
        // Input: Text with triple small tsu "かっっっこい"
        // Expected: Collapse to single in normal mode, full collapse in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "かっっっこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "かっこい")
        #expect(resultFull == "かこい")
    }

    @Test func collapseEmphaticSequences_ProlongedSoundMark_NoChange() throws {
        // Purpose: Test single prolonged sound mark
        // Input: Text with single prolonged sound mark "すごい"
        // Expected: No change in normal mode, no change in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "すごい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "すごい")
        #expect(resultFull == "すごい")
    }

    @Test func collapseEmphaticSequences_SingleProlongedSoundMark_NoChange() throws {
        // Purpose: Test single prolonged sound mark
        // Input: Text with single prolonged sound mark "すごーい"
        // Expected: No change in normal mode, collapse in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "すごーい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "すごーい")
        #expect(resultFull == "すごい")
    }

    @Test func collapseEmphaticSequences_DoubleProlongedSoundMark_CollapseToSingle() throws {
        // Purpose: Test double prolonged sound mark collapse
        // Input: Text with double prolonged sound mark "すごーーい"
        // Expected: Collapse to single in normal mode, full collapse in full mode
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "すごーーい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "すごーい")
        #expect(resultFull == "すごい")
    }

    @Test func collapseEmphaticSequences_MixedEmphaticSequences_CollapseCorrectly() throws {
        // Purpose: Test mixed emphatic sequences
        // Input: Text with mixed sequences "すっごーい"
        // Expected: Collapse each type appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "すっごーい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "すっごーい")
        #expect(resultFull == "すごい")
    }

    @Test func collapseEmphaticSequences_ComplexMixedSequences_CollapseCorrectly() throws {
        // Purpose: Test complex mixed emphatic sequences
        // Input: Complex text "すっっごーーい"
        // Expected: Collapse each sequence type appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "すっっごーーい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "すっごーい")
        #expect(resultFull == "すごい")
    }

    @Test func collapseEmphaticSequences_LeadingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test leading emphatic characters
        // Input: Text starting with emphatic "っこい"
        // Expected: Handle leading emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っこい")
        #expect(resultFull == "っこい")
    }

    @Test func collapseEmphaticSequences_MultipleLeadingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test multiple leading emphatic characters
        // Input: Text with multiple leading emphatic "っっこい"
        // Expected: Handle multiple leading emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっこい")
        #expect(resultFull == "っっこい")
    }

    @Test func collapseEmphaticSequences_TripleLeadingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test triple leading emphatic characters
        // Input: Text with triple leading emphatic "っっっこい"
        // Expected: Handle triple leading emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっっこい"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっっこい")
        #expect(resultFull == "っっっこい")
    }

    @Test func collapseEmphaticSequences_TrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test trailing emphatic characters
        // Input: Text ending with emphatic "こいっ"
        // Expected: Handle trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "こいっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "こいっ")
        #expect(resultFull == "こいっ")
    }

    @Test func collapseEmphaticSequences_MultipleTrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test multiple trailing emphatic characters
        // Input: Text with multiple trailing emphatic "こいっっ"
        // Expected: Handle multiple trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "こいっっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "こいっっ")
        #expect(resultFull == "こいっっ")
    }

    @Test func collapseEmphaticSequences_TripleTrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test triple trailing emphatic characters
        // Input: Text with triple trailing emphatic "こいっっっ"
        // Expected: Handle triple trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "こいっっっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "こいっっっ")
        #expect(resultFull == "こいっっっ")
    }

    @Test func collapseEmphaticSequences_LeadingAndTrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test both leading and trailing emphatic characters
        // Input: Text with both leading and trailing emphatic "っこいっ"
        // Expected: Handle both leading and trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っこいっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っこいっ")
        #expect(resultFull == "っこいっ")
    }

    @Test func collapseEmphaticSequences_MultipleLeadingAndTrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test multiple leading and trailing emphatic characters
        // Input: Text with multiple leading and trailing emphatic "っっこいっっ"
        // Expected: Handle multiple leading and trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっこいっっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっこいっっ")
        #expect(resultFull == "っっこいっっ")
    }

    @Test func collapseEmphaticSequences_TripleLeadingAndTrailingEmphatic_HandlesCorrectly() throws {
        // Purpose: Test triple leading and trailing emphatic characters
        // Input: Text with triple leading and trailing emphatic "っっっこいっっっ"
        // Expected: Handle triple leading and trailing emphatics appropriately
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっっこいっっっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっっこいっっっ")
        #expect(resultFull == "っっっこいっっっ")
    }

    @Test func collapseEmphaticSequences_EmptyString_ReturnsEmpty() throws {
        // Purpose: Test empty string handling
        // Input: Empty string ""
        // Expected: Empty string ""
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = ""

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "")
        #expect(resultFull == "")
    }

    @Test func collapseEmphaticSequences_OnlySmallTsu_NoChange() throws {
        // Purpose: Test string with only small tsu
        // Input: Only small tsu "っ"
        // Expected: No change
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っ")
        #expect(resultFull == "っ")
    }

    @Test func collapseEmphaticSequences_OnlyDoubleSmallTsu_NoChange() throws {
        // Purpose: Test string with only double small tsu
        // Input: Only double small tsu "っっ"
        // Expected: No change
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっ")
        #expect(resultFull == "っっ")
    }

    @Test func collapseEmphaticSequences_OnlyTripleSmallTsu_NoChange() throws {
        // Purpose: Test string with only triple small tsu
        // Input: Only triple small tsu "っっっ"
        // Expected: No change
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっっ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっっ")
        #expect(resultFull == "っっっ")
    }

    @Test func collapseEmphaticSequences_ComplexMixedKatakanaHiragana_HandlesCorrectly() throws {
        // Purpose: Test complex mixed katakana/hiragana with emphatic sequences
        // Input: Complex text "っーッかっこいいっーッ"
        // Expected: Handle mixed emphatic types correctly
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っーッかっこいいっーッ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っーッかっこいいっーッ")
        #expect(resultFull == "っーッかこいいっーッ")
    }

    @Test func collapseEmphaticSequences_VeryComplexMixed_HandlesCorrectly() throws {
        // Purpose: Test very complex mixed emphatic sequences
        // Input: Very complex text "っっーーッッかっこいいっっーーッッ"
        // Expected: Handle very complex mixed emphatic types correctly
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっーーッッかっこいいっっーーッッ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっーーッッかっこいいっっーーッッ")
        #expect(resultFull == "っっーーッッかこいいっっーーッッ")
    }

    @Test func collapseEmphaticSequences_OnlyMixedEmphatic_NoChange() throws {
        // Purpose: Test string with only mixed emphatic characters
        // Input: Only mixed emphatic "っーッ"
        // Expected: No change
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っーッ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っーッ")
        #expect(resultFull == "っーッ")
    }

    @Test func collapseEmphaticSequences_OnlyComplexMixedEmphatic_NoChange() throws {
        // Purpose: Test string with only complex mixed emphatic characters
        // Input: Only complex mixed emphatic "っっーーッッ"
        // Expected: No change
        let ruleNormal = CollapseEmphaticSequencesRule(fullCollapse: false)
        let ruleFull = CollapseEmphaticSequencesRule(fullCollapse: true)
        let input = "っっーーッッ"

        let resultNormal = ruleNormal.process(input)
        let resultFull = ruleFull.process(input)

        #expect(resultNormal == "っっーーッッ")
        #expect(resultFull == "っっーーッッ")
    }

    @Test func collapseEmphaticSequencesRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = CollapseEmphaticSequencesRule()

        #expect(rule.name == "collapseEmphaticSequences")
        #expect(rule.description.contains("Collapse emphatic sequences"))
        #expect(rule.description.contains("っっっ → っ"))
        #expect(rule.description.contains("ーーー → ー"))
    }

    // MARK: - Conversion Rule Properties Tests

    @Test func convertKatakanaToHiraganaRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = ConvertKatakanaToHiraganaRule()

        #expect(rule.name == "convertKatakanaToHiragana")
        #expect(rule.description.contains("katakana"))
        #expect(rule.description.contains("hiragana"))
        #expect(rule.description.contains("カタカナ → かたかな"))
    }

    @Test func convertHiraganaToKatakanaRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = ConvertHiraganaToKatakanaRule()

        #expect(rule.name == "convertHiraganaToKatakana")
        #expect(rule.description.contains("hiragana"))
        #expect(rule.description.contains("katakana"))
        #expect(rule.description.contains("ひらがな → ヒラガナ"))
    }

    // MARK: - JapaneseTextPreprocessor Tests

    @Test func generateVariants_SingleRule_ReturnsOriginalAndProcessed() throws {
        // Purpose: Test variant generation with a single preprocessor rule
        // Input: Half-width text with one rule
        // Expected: Array containing original and converted text
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 5)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let variants = preprocessor.generateVariants(input, using: [rule])

        #expect(variants.variants.count == 2)
        #expect(variants.variants.contains("ﾖﾐﾁｬﾝ")) // Original
        #expect(variants.variants.contains("ヨミチャン")) // Converted
    }

    @Test func generateVariants_NoChangingRules_ReturnsOnlyOriginal() throws {
        // Purpose: Test variant generation when rules don't change the input
        // Input: Full-width text with half-width conversion rule
        // Expected: Only original text (rule produces no change)
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 5)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ヨミチャン" // Already full-width

        let variants = preprocessor.generateVariants(input, using: [rule])

        #expect(variants.variants.count == 1)
        #expect(variants.variants.contains("ヨミチャン"))
    }

    @Test func generateVariants_EmptyRulesArray_ReturnsOnlyOriginal() throws {
        // Purpose: Test variant generation with no rules
        // Input: Any text with empty rules array
        // Expected: Only original text
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 5)
        let input = "test"

        let variants = preprocessor.generateVariants(input, using: [])

        #expect(variants.variants.count == 1)
        #expect(variants.variants.contains("test"))
    }

    @Test func generateVariants_MaxVariantsLimit_RespectsLimit() throws {
        // Purpose: Test that variant generation respects the maxVariants limit
        // Input: Text and rules that could generate many variants, with low limit
        // Expected: Variants array doesn't exceed maxVariants
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 2)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let variants = preprocessor.generateVariants(input, using: [rule])

        #expect(variants.variants.count <= 2)
        #expect(variants.variants.contains("ﾖﾐﾁｬﾝ")) // Original should always be included
    }

    // MARK: - Caching Tests

    @Test func generateVariants_SameInputAndRules_UsesCachedResult() throws {
        // Purpose: Test that identical inputs use cached results
        // Input: Same text and rules called twice
        // Expected: Same results both times (verifies caching works)
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 5)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let variants1 = preprocessor.generateVariants(input, using: [rule])
        let variants2 = preprocessor.generateVariants(input, using: [rule])

        #expect(variants1.variants.count == variants2.variants.count)
        #expect(Set(variants1.variants) == Set(variants2.variants))
    }

    @Test func generateVariants_DifferentRules_ReturnsDifferentResults() throws {
        // Purpose: Test that different rule sets produce different cache entries
        // Input: Same text with different rule combinations
        // Expected: Different results for different rule sets
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 5)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let variants1 = preprocessor.generateVariants(input, using: [rule])
        let variants2 = preprocessor.generateVariants(input, using: []) // No rules

        #expect(variants1.variants.count != variants2.variants.count)
    }

    // MARK: - Multiple Rules Simulation Tests

    // Note: These tests simulate what would happen with multiple rules
    // Once more preprocessor rules are implemented, these can be updated

    @Test func generateVariants_MultipleIdenticalRules_NoDuplication() throws {
        // Purpose: Test that identical rules don't create duplicate variants
        // Input: Same rule applied multiple times
        // Expected: No duplicate variants in result
        let preprocessor = JapaneseTextPreprocessor(maxVariants: 10)
        let rule = ConvertHalfWidthCharactersRule()
        let input = "ﾖﾐﾁｬﾝ"

        let variants = preprocessor.generateVariants(input, using: [rule, rule, rule])

        #expect(variants.variants.count == 2) // Original + converted, no duplicates
        #expect(variants.variants.contains("ﾖﾐﾁｬﾝ"))
        #expect(variants.variants.contains("ヨミチャン"))
    }

    // MARK: - Rule Properties Tests

    @Test func convertHalfWidthCharactersRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = ConvertHalfWidthCharactersRule()

        #expect(rule.name == "convertHalfWidthCharacters")
        #expect(rule.description.contains("half width"))
        #expect(rule.description.contains("full width"))
        #expect(rule.description.contains("ﾖﾐﾁｬﾝ → ヨミチャン"))
    }

    // MARK: - NormalizeCJKCompatibilityCharactersRule Tests

    @Test func normalizeCJKCompatibilityCharacters_BasicCompatibilityCharacters_NormalizesCorrectly() throws {
        // Purpose: Test basic CJK compatibility character normalization
        // Input: Common compatibility characters from the JavaScript test cases
        // Expected: Proper NFKD normalization matching Yomitan behavior
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌀", "アパート"), // Apartment
            ("㌁", "アルファ"), // Alpha
            ("㌂", "アンペア"), // Ampere
            ("㌃", "アール"), // Are
            ("㌄", "イニング"), // Inning
            ("㌅", "インチ"), // Inch
            ("㌆", "ウォン"), // Won
            ("㌇", "エスクード"), // Escudo
            ("㌈", "エーカー"), // Acre
            ("㌉", "オンス"), // Ounce
            ("㌊", "オーム"), // Ohm
            ("㌋", "カイリ"), // Nautical mile
            ("㌌", "カラット"), // Carat
            ("㌍", "カロリー"), // Calorie
            ("㌎", "ガロン"), // Gallon
            ("㌏", "ガンマ"), // Gamma
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_UnitsAndMeasures_NormalizesCorrectly() throws {
        // Purpose: Test CJK compatibility characters for units and measures
        // Input: Various unit and measurement compatibility characters
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌔", "キロ"), // Kilo
            ("㌕", "キログラム"), // Kilogram
            ("㌖", "キロメートル"), // Kilometer
            ("㌗", "キロワット"), // Kilowatt
            ("㌘", "グラム"), // Gram
            ("㌙", "グラムトン"), // Gram ton
            ("㌚", "クルゼイロ"), // Cruzeiro
            ("㌛", "クローネ"), // Krone
            ("㌜", "ケース"), // Case
            ("㌝", "コルナ"), // Koruna
            ("㌞", "コーポ"), // Corpo
            ("㌟", "サイクル"), // Cycle
            ("㌠", "サンチーム"), // Centime
            ("㌡", "シリング"), // Shilling
            ("㌢", "センチ"), // Centi
            ("㌣", "セント"), // Cent
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_CurrencyAndFinance_NormalizesCorrectly() throws {
        // Purpose: Test CJK compatibility characters for currency and finance
        // Input: Currency and financial compatibility characters
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌦", "ドル"), // Dollar
            ("㌧", "トン"), // Ton
            ("㌫", "パーセント"), // Percent
            ("㌬", "パーツ"), // Parts
            ("㌭", "バーレル"), // Barrel
            ("㌮", "ピアストル"), // Piastre
            ("㌯", "ピクル"), // Pickle
            ("㌰", "ピコ"), // Pico
            ("㌱", "ビル"), // Bill
            ("㌲", "ファラッド"), // Farad
            ("㌳", "フィート"), // Feet
            ("㌴", "ブッシェル"), // Bushel
            ("㌵", "フラン"), // Franc
            ("㌶", "ヘクタール"), // Hectare
            ("㌷", "ペソ"), // Peso
            ("㌸", "ペニヒ"), // Pfennig
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_MoreUnitsAndMeasures_NormalizesCorrectly() throws {
        // Purpose: Test more CJK compatibility characters for units and measures
        // Input: Additional unit and measurement compatibility characters
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌹", "ヘルツ"), // Hertz
            ("㌺", "ペンス"), // Pence
            ("㌻", "ページ"), // Page
            ("㌼", "ベータ"), // Beta
            ("㌽", "ポイント"), // Point
            ("㌾", "ボルト"), // Volt
            ("㌿", "ホン"), // Hon
            ("㍀", "ポンド"), // Pound
            ("㍁", "ホール"), // Hall
            ("㍂", "ホーン"), // Horn
            ("㍃", "マイクロ"), // Micro
            ("㍄", "マイル"), // Mile
            ("㍅", "マッハ"), // Mach
            ("㍆", "マルク"), // Mark
            ("㍇", "マンション"), // Mansion
            ("㍈", "ミクロン"), // Micron
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_FinalUnitsAndCurrencies_NormalizesCorrectly() throws {
        // Purpose: Test final set of CJK compatibility characters
        // Input: Remaining unit, currency, and measurement compatibility characters
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㍉", "ミリ"), // Milli
            ("㍊", "ミリバール"), // Millibar
            ("㍋", "メガ"), // Mega
            ("㍌", "メガトン"), // Megaton
            ("㍍", "メートル"), // Meter
            ("㍎", "ヤード"), // Yard
            ("㍏", "ヤール"), // Yard
            ("㍐", "ユアン"), // Yuan
            ("㍑", "リットル"), // Liter
            ("㍒", "リラ"), // Lira
            ("㍓", "ルピー"), // Rupee
            ("㍔", "ルーブル"), // Ruble
            ("㍕", "レム"), // Rem
            ("㍖", "レントゲン"), // Roentgen
            ("㍗", "ワット"), // Watt
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_ScoresAndPoints_NormalizesCorrectly() throws {
        // Purpose: Test CJK compatibility characters for scores and points
        // Input: Score and point compatibility characters from Yomitan tests
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㍘", "0点"), // 0 points
            ("㍙", "1点"), // 1 point
            ("㍚", "2点"), // 2 points
            ("㍛", "3点"), // 3 points
            ("㍜", "4点"), // 4 points
            ("㍝", "5点"), // 5 points
            ("㍞", "6点"), // 6 points
            ("㍟", "7点"), // 7 points
            ("㍠", "8点"), // 8 points
            ("㍡", "9点"), // 9 points
            ("㍢", "10点"), // 10 points
            ("㍣", "11点"), // 11 points
            ("㍤", "12点"), // 12 points
            ("㍥", "13点"), // 13 points
            ("㍦", "14点"), // 14 points
            ("㍧", "15点"), // 15 points
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_MoreScoresAndEras_NormalizesCorrectly() throws {
        // Purpose: Test more CJK compatibility characters for scores and Japanese eras
        // Input: More score characters and Japanese era names
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㍨", "16点"), // 16 points
            ("㍩", "17点"), // 17 points
            ("㍪", "18点"), // 18 points
            ("㍫", "19点"), // 19 points
            ("㍬", "20点"), // 20 points
            ("㍭", "21点"), // 21 points
            ("㍮", "22点"), // 22 points
            ("㍯", "23点"), // 23 points
            ("㍰", "24点"), // 24 points
            ("㍻", "平成"), // Heisei era
            ("㍼", "昭和"), // Showa era
            ("㍽", "大正"), // Taisho era
            ("㍾", "明治"), // Meiji era
            ("㍿", "株式会社"), // Corporation (KK)
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_DaysOfMonth_NormalizesCorrectly() throws {
        // Purpose: Test CJK compatibility characters for days of the month
        // Input: Day compatibility characters from Yomitan tests
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㏠", "1日"), // 1st day
            ("㏡", "2日"), // 2nd day
            ("㏢", "3日"), // 3rd day
            ("㏣", "4日"), // 4th day
            ("㏤", "5日"), // 5th day
            ("㏥", "6日"), // 6th day
            ("㏦", "7日"), // 7th day
            ("㏧", "8日"), // 8th day
            ("㏨", "9日"), // 9th day
            ("㏩", "10日"), // 10th day
            ("㏪", "11日"), // 11th day
            ("㏫", "12日"), // 12th day
            ("㏬", "13日"), // 13th day
            ("㏭", "14日"), // 14th day
            ("㏮", "15日"), // 15th day
            ("㏯", "16日"), // 16th day
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_RemainingDaysOfMonth_NormalizesCorrectly() throws {
        // Purpose: Test remaining CJK compatibility characters for days of the month
        // Input: Remaining day compatibility characters from Yomitan tests
        // Expected: Proper NFKD normalization
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㏰", "17日"), // 17th day
            ("㏱", "18日"), // 18th day
            ("㏲", "19日"), // 19th day
            ("㏳", "20日"), // 20th day
            ("㏴", "21日"), // 21st day
            ("㏵", "22日"), // 22nd day
            ("㏶", "23日"), // 23rd day
            ("㏷", "24日"), // 24th day
            ("㏸", "25日"), // 25th day
            ("㏹", "26日"), // 26th day
            ("㏺", "27日"), // 27th day
            ("㏻", "28日"), // 28th day
            ("㏼", "29日"), // 29th day
            ("㏽", "30日"), // 30th day
            ("㏾", "31日"), // 31st day
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_NonCompatibilityCharacters_NoChange() throws {
        // Purpose: Test that non-CJK compatibility characters remain unchanged
        // Input: Various non-compatibility characters including regular CJK
        // Expected: No change to characters outside the CJK compatibility range
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("あ", "あ"), // Hiragana a
            ("ア", "ア"), // Katakana a
            ("漢", "漢"), // Kanji "kan" (Chinese character)
            ("字", "字"), // Kanji "ji" (character)
            ("A", "A"), // Latin A
            ("1", "1"), // ASCII digit
            ("。", "。"), // Japanese period
            ("、", "、"), // Japanese comma
            ("！", "！"), // Full-width exclamation
            ("？", "？"), // Full-width question mark
            ("㌀以外", "アパート以外"), // Mixed: compatibility + non-compatibility
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_MixedText_NormalizesOnlyCompatibility() throws {
        // Purpose: Test mixed text with both compatibility and non-compatibility characters
        // Input: Mixed text containing various character types
        // Expected: Only CJK compatibility characters normalized
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("私は㌀に住んでいます", "私はアパートに住んでいます"), // I live in an apartment
            ("㌔と㍍の単位", "キロとメートルの単位"), // Units of kilo and meter
            ("㍻時代から㍼時代", "平成時代から昭和時代"), // From Heisei era to Showa era
            ("test㌀test", "testアパートtest"), // Mixed with English
            ("abc㌔123㍍xyz", "abcキロ123メートルxyz"), // Complex mixed text
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_EmptyString_ReturnsEmpty() throws {
        // Purpose: Test empty string handling
        // Input: Empty string ""
        // Expected: Empty string ""
        let rule = NormalizeCJKCompatibilityCharactersRule()
        let input = ""

        let result = rule.process(input)

        #expect(result == "")
    }

    @Test func normalizeCJKCompatibilityCharacters_SingleCompatibilityCharacter_NormalizesCorrectly() throws {
        // Purpose: Test single compatibility character processing
        // Input: Single CJK compatibility character
        // Expected: Properly normalized single result
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌀", "アパート"),
            ("㍻", "平成"),
            ("㏠", "1日"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharacters_MultipleCompatibilityCharacters_NormalizesAll() throws {
        // Purpose: Test multiple CJK compatibility characters in sequence
        // Input: Multiple CJK compatibility characters together
        // Expected: All characters properly normalized
        let rule = NormalizeCJKCompatibilityCharactersRule()

        let testCases = [
            ("㌀㌁", "アパートアルファ"),
            ("㍻㍼㍽", "平成昭和大正"),
            ("㏠㏡㏢", "1日2日3日"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func normalizeCJKCompatibilityCharactersRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = NormalizeCJKCompatibilityCharactersRule()

        #expect(rule.name == "normalizeCJKCompatibilityCharacters")
        #expect(rule.description.contains("CJK compatibility"))
        #expect(rule.description.contains("㌀ → アパート"))
        #expect(rule.description.contains("㍻ → 平成"))
    }

    // MARK: - ConvertKanjiVariantsRule Tests

    @Test func convertKanjiVariants_CommonVariants_ConvertsToStandardForms() throws {
        // Purpose: Test conversion of common kanji variants to standard forms
        // Input: Common variant kanji from the itaiji data
        // Expected: Proper conversion to standard oyaji forms
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("弌", "一"), // ichi variant → standard one
            ("萬", "万"), // man variant → standard 10,000
            ("弎", "三"), // san variant → standard three
            ("與", "与"), // yo variant → standard give
            ("兩", "両"), // ryou variant → standard both
            ("竝", "並"), // nami variant → standard line up
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_MixedText_ConvertsOnlyVariants() throws {
        // Purpose: Test mixed text with both variant and standard kanji
        // Input: Mixed text containing various character types
        // Expected: Only kanji variants converted, others unchanged
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("弌つの本", "一つの本"), // One book
            ("萬円札", "万円札"), // 10,000 yen bill
            ("弎人家族", "三人家族"), // Three-person family
            ("與える", "与える"), // To give
            ("standard漢字弌variant", "standard漢字一variant"), // Mixed standard/variant
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_NoVariants_NoChange() throws {
        // Purpose: Test text with no kanji variants
        // Input: Standard kanji and other characters
        // Expected: No changes made
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("一二三", "一二三"), // Standard numbers
            ("漢字変換", "漢字変換"), // Standard kanji
            ("ひらがな", "ひらがな"), // Hiragana
            ("カタカナ", "カタカナ"), // Katakana
            ("English文字", "English文字"), // Mixed with English
            ("", ""), // Empty string
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_MultipleVariantsInSequence_ConvertsAll() throws {
        // Purpose: Test multiple variant kanji in sequence
        // Input: Multiple variant kanji together
        // Expected: All variants converted to standard forms
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("弌弎", "一三"), // One three
            ("萬與", "万与"), // 10,000 give
            ("弌萬弎", "一万三"), // 13,000
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_SingleVariant_ConvertsCorrectly() throws {
        // Purpose: Test single variant kanji processing
        // Input: Single kanji variant character
        // Expected: Properly converted single result
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("弌", "一"),
            ("萬", "万"),
            ("弎", "三"),
            ("與", "与"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_ComplexText_ConvertsAppropriately() throws {
        // Purpose: Test complex realistic text with variants
        // Input: Natural Japanese text containing kanji variants
        // Expected: Variants converted while preserving text structure
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("弌日萬回", "一日万回"), // One day 10,000 times
            ("弎人兩親", "三人両親"), // Three-person both parents
            ("與えた弌つ", "与えた一つ"), // Gave one
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariants_JSONDataLoading_InitializesCorrectly() throws {
        // Purpose: Test that the rule initializes correctly with JSON data
        // Input: Rule initialization
        // Expected: Rule created without errors
        let rule = ConvertKanjiVariantsRule()

        // Test that rule has proper metadata
        #expect(rule.name == "convertKanjiVariants")
        #expect(rule.description.contains("kanji variants"))
        #expect(rule.description.contains("standard forms"))
    }

    @Test func convertKanjiVariants_UnknownCharacters_NoChange() throws {
        // Purpose: Test handling of characters not in the variant mapping
        // Input: Various non-variant characters
        // Expected: Characters remain unchanged
        let rule = ConvertKanjiVariantsRule()

        let testCases = [
            ("未知字", "未知字"), // Unknown characters
            ("🌸", "🌸"), // Emoji
            ("αβγ", "αβγ"), // Greek letters
            ("123", "123"), // Numbers
            ("ABC", "ABC"), // Latin letters
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertKanjiVariantsRule_HasCorrectMetadata() throws {
        // Purpose: Verify rule metadata is correctly set
        // Expected: Proper name and description for UI/debugging
        let rule = ConvertKanjiVariantsRule()

        #expect(rule.name == "convertKanjiVariants")
        #expect(rule.description.contains("kanji variants"))
        #expect(rule.description.contains("standard forms"))
        #expect(rule.description.contains("弌 → 一"))
        #expect(rule.description.contains("萬 → 万"))
    }

    // MARK: - ConvertAlphabeticToKanaRule Tests

    @Test func convertAlphabeticToKana_NumbersOnly_NoChange() throws {
        // Purpose: Test that numbers remain unchanged
        // Input: String with only digits "0123456789"
        // Expected: Same string "0123456789"
        let rule = ConvertAlphabeticToKanaRule()
        let input = "0123456789"

        let result = rule.process(input)

        #expect(result == "0123456789")
    }

    @Test func convertAlphabeticToKana_BasicRomaji_ConvertsToKana() throws {
        // Purpose: Test basic romaji to kana conversion from Yomitan test cases
        // Input: Various romaji sequences
        // Expected: Proper kana conversion matching Yomitan behavior
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("abcdefghij", "あbcでfgひj"), // Partial conversion as per Yomitan tests
            ("chikara", "ちから"), // "power" in Japanese
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_UppercaseRomaji_ConvertsToKanaLowercase() throws {
        // Purpose: Test that uppercase romaji converts to lowercase then to kana
        // Input: Uppercase romaji sequences
        // Expected: Kana conversion (wanakana.toHiragana converts to lowercase first)
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("ABCDEFGHIJ", "あbcでfgひj"), // Same as lowercase version
            ("CHIKARA", "ちから"), // Same as lowercase version
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_AlreadyKatakana_NoChange() throws {
        // Purpose: Test that existing katakana remains unchanged
        // Input: Katakana string "カタカナ"
        // Expected: Same string "カタカナ"
        let rule = ConvertAlphabeticToKanaRule()
        let input = "カタカナ"

        let result = rule.process(input)

        #expect(result == "カタカナ")
    }

    @Test func convertAlphabeticToKana_AlreadyHiragana_NoChange() throws {
        // Purpose: Test that existing hiragana remains unchanged
        // Input: Hiragana string "ひらがな"
        // Expected: Same string "ひらがな"
        let rule = ConvertAlphabeticToKanaRule()
        let input = "ひらがな"

        let result = rule.process(input)

        #expect(result == "ひらがな")
    }

    @Test func convertAlphabeticToKana_ComplexRomaji_ConvertsCorrectly() throws {
        // Purpose: Test complex romaji sequences with double consonants and combinations
        // Input: Complex romaji patterns
        // Expected: Proper kana conversion with small tsu and combinations
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("kka", "っか"), // Double k becomes small tsu + ka
            ("tsu", "つ"), // Special tsu combination
            ("sha", "しゃ"), // sh + a combination
            ("chu", "ちゅ"), // ch + u combination
            ("nya", "にゃ"), // n + ya combination
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_MixedTextTypes_ConvertsOnlyAlphabetic() throws {
        // Purpose: Test mixed text with alphabetic and non-alphabetic characters
        // Input: Text containing romaji, kana, and other characters
        // Expected: Only alphabetic parts converted
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("kanji漢字kana", "かんじ漢字かな"), // Mixed with kanji
            ("number123romaji", "ぬmべr123ろまじ"), // Mixed with numbers
            ("hello世界", "へっlお世界"), // Mixed English/Japanese
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_VowelCombinations_ConvertsCorrectly() throws {
        // Purpose: Test vowel combinations and sequences
        // Input: Various vowel patterns
        // Expected: Proper kana for vowels
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("a", "あ"),
            ("i", "い"),
            ("u", "う"),
            ("e", "え"),
            ("o", "お"),
            ("ai", "あい"), // a + i
            ("ao", "あお"), // a + o
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_SingleN_ConvertsToN() throws {
        // Purpose: Test single 'n' conversion (special case)
        // Input: Single 'n' character
        // Expected: ん (n kana)
        let rule = ConvertAlphabeticToKanaRule()
        let input = "n"

        let result = rule.process(input)

        #expect(result == "ん")
    }

    @Test func convertAlphabeticToKana_DoubleN_ConvertsToN() throws {
        // Purpose: Test double 'nn' conversion
        // Input: Double 'nn'
        // Expected: ん (single n kana)
        let rule = ConvertAlphabeticToKanaRule()
        let input = "nn"

        let result = rule.process(input)

        #expect(result == "ん")
    }

    @Test func convertAlphabeticToKana_EmptyString_ReturnsEmpty() throws {
        // Purpose: Test empty string handling
        // Input: Empty string ""
        // Expected: Empty string ""
        let rule = ConvertAlphabeticToKanaRule()
        let input = ""

        let result = rule.process(input)

        #expect(result == "")
    }

    @Test func convertAlphabeticToKana_NonAlphabeticCharacters_NoChange() throws {
        // Purpose: Test that non-alphabetic characters remain unchanged
        // Input: Various non-alphabetic characters
        // Expected: Same characters
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("123", "123"), // Numbers
            ("!@#$%", "!@#$%"), // Symbols
            ("　", "　"), // Full-width space
            ("。、", "。、"), // Japanese punctuation
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_PartialAlphabeticSequences_ConvertsAppropriately() throws {
        // Purpose: Test sequences where not all letters can form valid kana
        // Input: Sequences with some unconvertible letter combinations
        // Expected: Convertible parts converted, others remain as letters
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("abc", "あbc"), // 'a' converts, 'bc' stays
            ("xyz", "xyz"), // None convert individually in this context
            ("kana", "かな"), // All convert
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_Dashes_HandlesCorrectly() throws {
        // Purpose: Test handling of dashes in romaji
        // Input: Romaji with dashes (ASCII and fullwidth)
        // Expected: Proper handling and conversion
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("ka-na", "か-な"), // ASCII dash
            ("ka－na", "か-な"), // Fullwidth dash normalized to ASCII
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphabeticToKana_FullwidthAlphabetic_ConvertsCorrectly() throws {
        // Purpose: Test fullwidth alphabetic character handling
        // Input: Fullwidth alphabetic characters
        // Expected: Conversion to kana after normalization
        let rule = ConvertAlphabeticToKanaRule()

        let testCases = [
            ("ａｂｃ", "あbc"), // Fullwidth a converts
            ("ｋａｎａ", "かな"), // All fullwidth letters
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    // MARK: - ConvertAlphanumericToFullWidthRule Tests

    @Test func convertAlphanumericToFullWidth_BasicDigits_ConvertsCorrectly() throws {
        // Purpose: Test conversion of ASCII digits to full-width equivalents
        // Input: Normal ASCII digits 0-9
        // Expected: Full-width digits ０-９
        let rule = ConvertAlphanumericToFullWidthRule()

        let testCases = [
            ("0", "０"),
            ("1", "１"),
            ("2", "２"),
            ("3", "３"),
            ("4", "４"),
            ("5", "５"),
            ("6", "６"),
            ("7", "７"),
            ("8", "８"),
            ("9", "９"),
            ("0123456789", "０１２３４５６７８９"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphanumericToFullWidth_BasicLetters_ConvertsCorrectly() throws {
        // Purpose: Test conversion of ASCII letters to full-width equivalents
        // Input: Normal ASCII letters a-z, A-Z
        // Expected: Full-width letters ａ-ｚ, Ａ-Ｚ
        let rule = ConvertAlphanumericToFullWidthRule()

        let testCases = [
            ("a", "ａ"),
            ("z", "ｚ"),
            ("A", "Ａ"),
            ("Z", "Ｚ"),
            ("abcdefghij", "ａｂｃｄｅｆｇｈｉｊ"),
            ("ABCDEFGHIJ", "ＡＢＣＤＥＦＧＨＩＪ"),
            ("Hello", "Ｈｅｌｌｏ"),
            ("WORLD", "ＷＯＲＬＤ"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertAlphanumericToFullWidth_MixedContent_ConvertsOnlyAlphanumeric() throws {
        // Purpose: Test that only alphanumeric characters are converted, others left unchanged
        // Input: Mixed content including Japanese text, punctuation, symbols
        // Expected: Only ASCII alphanumeric converted to full-width
        let rule = ConvertAlphanumericToFullWidthRule()

        let testCases = [
            ("Hello123", "Ｈｅｌｌｏ１２３"),
            ("カタカナ", "カタカナ"), // Japanese should remain unchanged
            ("ひらがな", "ひらがな"), // Japanese should remain unchanged
            ("Test123!@#", "Ｔｅｓｔ１２３!@#"), // Punctuation unchanged
            ("abc カタカナ 123", "ａｂｃ カタカナ １２３"), // Mixed content
            ("", ""), // Empty string
            ("!@#$%", "!@#$%"), // Only symbols
            ("　", "　"), // Full-width space unchanged
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    // MARK: - ConvertFullWidthAlphanumericToNormalRule Tests

    @Test func convertFullWidthAlphanumericToNormal_BasicDigits_ConvertsCorrectly() throws {
        // Purpose: Test conversion of full-width digits to ASCII equivalents
        // Input: Full-width digits ０-９
        // Expected: Normal ASCII digits 0-9
        let rule = ConvertFullWidthAlphanumericToNormalRule()

        let testCases = [
            ("０", "0"),
            ("１", "1"),
            ("２", "2"),
            ("３", "3"),
            ("４", "4"),
            ("５", "5"),
            ("６", "6"),
            ("７", "7"),
            ("８", "8"),
            ("９", "9"),
            ("０１２３４５６７８９", "0123456789"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertFullWidthAlphanumericToNormal_BasicLetters_ConvertsCorrectly() throws {
        // Purpose: Test conversion of full-width letters to ASCII equivalents
        // Input: Full-width letters ａ-ｚ, Ａ-Ｚ
        // Expected: Normal ASCII letters a-z, A-Z
        let rule = ConvertFullWidthAlphanumericToNormalRule()

        let testCases = [
            ("ａ", "a"),
            ("ｚ", "z"),
            ("Ａ", "A"),
            ("Ｚ", "Z"),
            ("ａｂｃｄｅｆｇｈｉｊ", "abcdefghij"),
            ("ＡＢＣＤＥＦＧＨＩＪ", "ABCDEFGHIJ"),
            ("Ｈｅｌｌｏ", "Hello"),
            ("ＷＯＲＬＤ", "WORLD"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertFullWidthAlphanumericToNormal_MixedContent_ConvertsOnlyFullWidth() throws {
        // Purpose: Test that only full-width alphanumeric characters are converted
        // Input: Mixed content including Japanese text, punctuation, symbols
        // Expected: Only full-width alphanumeric converted to ASCII
        let rule = ConvertFullWidthAlphanumericToNormalRule()

        let testCases = [
            ("Ｈｅｌｌｏ１２３", "Hello123"),
            ("カタカナ", "カタカナ"), // Japanese should remain unchanged
            ("ひらがな", "ひらがな"), // Japanese should remain unchanged
            ("Ｔｅｓｔ１２３！＠＃", "Test123！＠＃"), // Full-width punctuation unchanged
            ("ａｂｃ カタカナ １２３", "abc カタカナ 123"), // Mixed content
            ("", ""), // Empty string
            ("！＠＃＄％", "！＠＃＄％"), // Only full-width symbols
            ("　", "　"), // Full-width space unchanged
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    @Test func convertFullWidthAlphanumericToNormal_AlreadyNormal_NoChange() throws {
        // Purpose: Test that normal ASCII characters are left unchanged
        // Input: Normal ASCII alphanumeric characters
        // Expected: Same characters (no conversion)
        let rule = ConvertFullWidthAlphanumericToNormalRule()

        let testCases = [
            ("Hello123", "Hello123"),
            ("abc", "abc"),
            ("XYZ", "XYZ"),
            ("0123456789", "0123456789"),
            ("Test!@#123", "Test!@#123"),
        ]

        for (input, expected) in testCases {
            let result = rule.process(input)
            #expect(result == expected, "Expected \(input) → \(expected), got \(result)")
        }
    }

    // MARK: - Round-trip Tests for Alphanumeric Width Conversion

    @Test func alphanumericWidthConversion_RoundTrip_PreservesOriginal() throws {
        // Purpose: Test that converting normal→full→normal preserves original text
        // Input: Various ASCII alphanumeric strings
        // Expected: Original text after round-trip conversion
        let toFullWidth = ConvertAlphanumericToFullWidthRule()
        let toNormal = ConvertFullWidthAlphanumericToNormalRule()

        let testCases = [
            "Hello123",
            "abc",
            "XYZ",
            "0123456789",
            "Test123",
            "Programming2024",
            "Swift5",
        ]

        for input in testCases {
            let fullWidth = toFullWidth.process(input)
            let backToNormal = toNormal.process(fullWidth)
            #expect(backToNormal == input, "Round-trip failed for \(input): normal→\(fullWidth)→\(backToNormal)")
        }
    }

    @Test func alphanumericWidthConversion_ReverseRoundTrip_PreservesOriginal() throws {
        // Purpose: Test that converting full→normal→full preserves original full-width text
        // Input: Various full-width alphanumeric strings
        // Expected: Original full-width text after round-trip conversion
        let toNormal = ConvertFullWidthAlphanumericToNormalRule()
        let toFullWidth = ConvertAlphanumericToFullWidthRule()

        let testCases = [
            "Ｈｅｌｌｏ１２３",
            "ａｂｃ",
            "ＸＹＺ",
            "０１２３４５６７８９",
            "Ｔｅｓｔ１２３",
            "Ｐｒｏｇｒａｍｍｉｎｇ２０２４",
            "Ｓｗｉｆｔ５",
        ]

        for input in testCases {
            let normal = toNormal.process(input)
            let backToFullWidth = toFullWidth.process(normal)
            #expect(backToFullWidth == input, "Reverse round-trip failed for \(input): full→\(normal)→\(backToFullWidth)")
        }
    }

    @Test func alphanumericWidthConversion_EdgeCases_HandlesCorrectly() throws {
        // Purpose: Test edge cases and boundary conditions
        // Input: Edge case strings including Unicode boundaries
        // Expected: Correct handling of edge cases
        let toFullWidth = ConvertAlphanumericToFullWidthRule()
        let toNormal = ConvertFullWidthAlphanumericToNormalRule()

        // Test Unicode boundary characters (just outside alphanumeric ranges)
        let testCases = [
            // Characters just before and after ASCII ranges
            "/", // 0x2F (before '0')
            ":", // 0x3A (after '9')
            "@", // 0x40 (before 'A')
            "[", // 0x5B (after 'Z')
            "`", // 0x60 (before 'a')
            "{", // 0x7B (after 'z')

            // Characters just before and after full-width ranges
            "／", // 0xFF0F (before '０')
            "：", // 0xFF1A (after '９')
            "＠", // 0xFF20 (before 'Ａ')
            "［", // 0xFF3B (after 'Ｚ')
            "｀", // 0xFF40 (before 'ａ')
            "｛", // 0xFF5B (after 'ｚ')
        ]

        for input in testCases {
            // These characters should not be converted by either rule
            let fullWidthResult = toFullWidth.process(input)
            let normalResult = toNormal.process(input)

            #expect(fullWidthResult == input, "toFullWidth should not convert \(input)")
            #expect(normalResult == input, "toNormal should not convert \(input)")
        }
    }
}

// MARK: - Mock Rules for Testing

/// Mock rule that always transforms input by appending a suffix
/// Used for testing preprocessor logic without relying on complex rules
private class MockTransformRule: TextPreprocessorRule {
    let name = "mockTransform"
    let description = "Adds suffix for testing"
    private let suffix: String

    init(suffix: String = "_transformed") {
        self.suffix = suffix
    }

    func process(_ text: String) -> String {
        text + suffix
    }
}

/// Mock rule that never changes input
/// Used for testing no-change scenarios
private class MockNoChangeRule: TextPreprocessorRule {
    let name = "mockNoChange"
    let description = "Never changes input"

    func process(_ text: String) -> String {
        text
    }
}
