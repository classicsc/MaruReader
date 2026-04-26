// JapaneseTextNormalization.swift
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

public struct JapaneseTextVariant: Sendable, Hashable {
    public let text: String
    public let transformationChain: [String]

    public init(text: String, transformationChain: [String]) {
        self.text = text
        self.transformationChain = transformationChain
    }
}

public enum JapaneseTextNormalization {
    public static func normalizeForLookup(_ text: String) -> String {
        normalizedWithSudachi(text) ?? text
    }

    public static func generateLookupVariants(
        for text: String,
        maxVariants: Int = 5
    ) -> [JapaneseTextVariant] {
        guard maxVariants > 0 else { return [] }

        var variants = [JapaneseTextVariant(text: text, transformationChain: [])]
        var seenTexts: Set<String> = [text]

        for transform in lookupTransforms {
            let sourceVariants = variants
            for variant in sourceVariants {
                guard let transformed = transform.apply(variant.text),
                      transformed != variant.text,
                      seenTexts.insert(transformed).inserted
                else {
                    continue
                }

                variants.append(JapaneseTextVariant(
                    text: transformed,
                    transformationChain: variant.transformationChain + [transform.name]
                ))

                if variants.count >= maxVariants {
                    return variants
                }
            }
        }

        return variants
    }

    private static let lookupTransforms: [LookupTransform] = [
        LookupTransform(name: "sudachiNormalizedForm", apply: normalizedWithSudachi),
        LookupTransform(name: "convertKanjiVariants", apply: convertKanjiVariants),
        LookupTransform(name: "collapseEmphaticSequences", apply: collapseEmphaticSequences),
        LookupTransform(name: "convertHalfWidthCharacters", apply: convertHalfWidthKanaToFullWidth),
        LookupTransform(name: "convertAlphabeticToKana", apply: convertRomajiToKana),
        LookupTransform(name: "convertHiraganaToKatakana", apply: convertHiraganaToKatakana),
        LookupTransform(name: "convertKatakanaToHiragana", apply: convertKatakanaToHiragana),
        LookupTransform(name: "convertFullWidthAlphanumericToNormal", apply: convertFullWidthAlphanumericToASCII),
        LookupTransform(name: "convertAlphanumericToFullWidth", apply: convertASCIIAlphanumericToFullWidth),
    ]

    private static func normalizedWithSudachi(_ text: String) -> String? {
        guard case let .success(analyzer) = SharedSudachiAnalyzer.result else {
            return nil
        }
        return try? analyzer.normalizedForm(text: text)
    }

    private static func convertKanjiVariants(_ text: String) -> String? {
        let result = String(text.map { kanjiVariantFallback[$0] ?? $0 })
        return changed(result, from: text)
    }

    private static func collapseEmphaticSequences(_ text: String) -> String? {
        let characters = Array(text)
        guard !characters.isEmpty else { return nil }

        var left = 0
        while left < characters.count, isEmphatic(characters[left]) {
            left += 1
        }

        var right = characters.count - 1
        while right >= 0, isEmphatic(characters[right]) {
            right -= 1
        }

        guard left <= right else { return nil }

        var result = String(characters[..<left])
        var previousCollapsed: Character?

        for character in characters[left ... right] {
            if isEmphatic(character) {
                if previousCollapsed != character {
                    result.append(character)
                    previousCollapsed = character
                }
            } else {
                result.append(character)
                previousCollapsed = nil
            }
        }

        result += String(characters[(right + 1)...])
        return changed(result, from: text)
    }

    private static func convertHalfWidthKanaToFullWidth(_ text: String) -> String? {
        var result = ""
        let scalars = Array(text.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let character = Character(scalars[index])
            guard let mapping = halfWidthKatakanaMapping[character] else {
                result.append(character)
                index += 1
                continue
            }

            var mappingIndex = 0
            if index + 1 < scalars.count {
                switch scalars[index + 1].value {
                case 0xFF9E:
                    mappingIndex = 1
                case 0xFF9F:
                    mappingIndex = 2
                default:
                    break
                }
            }

            let characterIndex = mapping.index(mapping.startIndex, offsetBy: mappingIndex)
            let converted = mapping[characterIndex]
            result.append(converted == "-" ? mapping[mapping.startIndex] : converted)
            index += mappingIndex == 0 ? 1 : 2
        }

        return changed(result, from: text)
    }

    private static func convertRomajiToKana(_ text: String) -> String? {
        var part = ""
        var result = ""

        for character in text {
            guard let scalar = character.unicodeScalars.first else {
                result.append(character)
                continue
            }

            if let normalized = normalizedRomajiScalar(scalar.value) {
                part.append(Character(normalized))
            } else {
                if !part.isEmpty {
                    result += convertRomajiPartToHiragana(part)
                    part = ""
                }
                result.append(character)
            }
        }

        if !part.isEmpty {
            result += convertRomajiPartToHiragana(part)
        }

        return changed(result, from: text)
    }

    private static func convertRomajiPartToHiragana(_ text: String) -> String {
        var result = ""
        let lowercaseText = text.lowercased()
        var index = 0

        while index < lowercaseText.count {
            let current = lowercaseText[lowercaseText.index(lowercaseText.startIndex, offsetBy: index)]
            if index + 1 < lowercaseText.count {
                let next = lowercaseText[lowercaseText.index(lowercaseText.startIndex, offsetBy: index + 1)]
                if current == next, current != "n", "bcdfghjklmnpqrstvwxyz".contains(current) {
                    result += "っ"
                    index += 1
                    continue
                }
            }

            let remaining = String(lowercaseText.dropFirst(index))
            var matched = false
            for length in (1 ... min(4, remaining.count)).reversed() {
                let prefix = String(remaining.prefix(length))
                if let hiragana = romajiToHiragana[prefix] {
                    result += hiragana
                    index += length
                    matched = true
                    break
                }
            }

            if !matched {
                result.append(current)
                index += 1
            }
        }

        return result
    }

    private static func convertHiraganaToKatakana(_ text: String) -> String? {
        let result = String(text.unicodeScalars.map { scalar in
            if (0x3041 ... 0x3096).contains(scalar.value),
               let converted = UnicodeScalar(scalar.value + 0x60)
            {
                return Character(converted)
            }
            return Character(scalar)
        })
        return changed(result, from: text)
    }

    private static func convertKatakanaToHiragana(_ text: String) -> String? {
        var result = ""

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x30F5, 0x30F6:
                result.append(Character(scalar))
            case 0x30FC:
                if let last = result.last, let prolonged = prolongedHiraganaVowel(for: last) {
                    result.append(prolonged)
                } else {
                    result.append(Character(scalar))
                }
            case 0x30A1 ... 0x30F6:
                result.append(Character(UnicodeScalar(scalar.value - 0x60)!))
            default:
                result.append(Character(scalar))
            }
        }

        return changed(result, from: text)
    }

    private static func convertFullWidthAlphanumericToASCII(_ text: String) -> String? {
        let result = String(text.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0xFF10 ... 0xFF19:
                Character(UnicodeScalar(scalar.value - (0xFF10 - 0x30))!)
            case 0xFF21 ... 0xFF3A:
                Character(UnicodeScalar(scalar.value - (0xFF21 - 0x41))!)
            case 0xFF41 ... 0xFF5A:
                Character(UnicodeScalar(scalar.value - (0xFF41 - 0x61))!)
            default:
                Character(scalar)
            }
        })
        return changed(result, from: text)
    }

    private static func convertASCIIAlphanumericToFullWidth(_ text: String) -> String? {
        let result = String(text.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0x30 ... 0x39:
                Character(UnicodeScalar(scalar.value + (0xFF10 - 0x30))!)
            case 0x41 ... 0x5A:
                Character(UnicodeScalar(scalar.value + (0xFF21 - 0x41))!)
            case 0x61 ... 0x7A:
                Character(UnicodeScalar(scalar.value + (0xFF41 - 0x61))!)
            default:
                Character(scalar)
            }
        })
        return changed(result, from: text)
    }

    private static func changed(_ result: String, from input: String) -> String? {
        result == input ? nil : result
    }

    private static func isEmphatic(_ character: Character) -> Bool {
        character == "っ" || character == "ッ" || character == "ー"
    }

    private static func normalizedRomajiScalar(_ value: UInt32) -> UnicodeScalar? {
        switch value {
        case 0x41 ... 0x5A:
            UnicodeScalar(value - 0x41 + 0x61)
        case 0x61 ... 0x7A:
            UnicodeScalar(value)
        case 0xFF21 ... 0xFF3A:
            UnicodeScalar(value - 0xFF21 + 0x61)
        case 0xFF41 ... 0xFF5A:
            UnicodeScalar(value - 0xFF41 + 0x61)
        case 0x2D, 0xFF0D:
            UnicodeScalar(0x2D)
        default:
            nil
        }
    }

    private static func prolongedHiraganaVowel(for character: Character) -> Character? {
        prolongedHiraganaVowels[character]
    }

    private static let kanjiVariantFallback: [Character: Character] = [
        "弌": "一",
        "弎": "三",
        "萬": "万",
        "與": "与",
        "兩": "両",
        "竝": "並",
    ]

    private static let halfWidthKatakanaMapping: [Character: String] = [
        "･": "・--", "ｦ": "ヲヺ-", "ｧ": "ァ--", "ｨ": "ィ--", "ｩ": "ゥ--", "ｪ": "ェ--", "ｫ": "ォ--",
        "ｬ": "ャ--", "ｭ": "ュ--", "ｮ": "ョ--", "ｯ": "ッ--", "ｰ": "ー--", "ｱ": "ア--", "ｲ": "イ--",
        "ｳ": "ウヴ-", "ｴ": "エ--", "ｵ": "オ--", "ｶ": "カガ-", "ｷ": "キギ-", "ｸ": "クグ-",
        "ｹ": "ケゲ-", "ｺ": "コゴ-", "ｻ": "サザ-", "ｼ": "シジ-", "ｽ": "スズ-", "ｾ": "セゼ-",
        "ｿ": "ソゾ-", "ﾀ": "タダ-", "ﾁ": "チヂ-", "ﾂ": "ツヅ-", "ﾃ": "テデ-", "ﾄ": "トド-",
        "ﾅ": "ナ--", "ﾆ": "ニ--", "ﾇ": "ヌ--", "ﾈ": "ネ--", "ﾉ": "ノ--", "ﾊ": "ハバパ",
        "ﾋ": "ヒビピ", "ﾌ": "フブプ", "ﾍ": "ヘベペ", "ﾎ": "ホボポ", "ﾏ": "マ--", "ﾐ": "ミ--",
        "ﾑ": "ム--", "ﾒ": "メ--", "ﾓ": "モ--", "ﾔ": "ヤ--", "ﾕ": "ユ--", "ﾖ": "ヨ--",
        "ﾗ": "ラ--", "ﾘ": "リ--", "ﾙ": "ル--", "ﾚ": "レ--", "ﾛ": "ロ--", "ﾜ": "ワ--",
        "ﾝ": "ン--",
    ]

    private static let prolongedHiraganaVowels: [Character: Character] = [
        "あ": "あ", "か": "あ", "が": "あ", "さ": "あ", "ざ": "あ", "た": "あ", "だ": "あ", "な": "あ", "は": "あ", "ば": "あ", "ぱ": "あ", "ま": "あ", "や": "あ", "ら": "あ", "わ": "あ", "ぁ": "あ", "ゃ": "あ",
        "い": "い", "き": "い", "ぎ": "い", "し": "い", "じ": "い", "ち": "い", "ぢ": "い", "に": "い", "ひ": "い", "び": "い", "ぴ": "い", "み": "い", "り": "い", "ぃ": "い",
        "う": "う", "く": "う", "ぐ": "う", "す": "う", "ず": "う", "つ": "う", "づ": "う", "ぬ": "う", "ふ": "う", "ぶ": "う", "ぷ": "う", "む": "う", "ゆ": "う", "る": "う", "ぅ": "う", "ゅ": "う", "っ": "う",
        "え": "え", "け": "え", "げ": "え", "せ": "え", "ぜ": "え", "て": "え", "で": "え", "ね": "え", "へ": "え", "べ": "え", "ぺ": "え", "め": "え", "れ": "え", "ぇ": "え",
        "お": "う", "こ": "う", "ご": "う", "そ": "う", "ぞ": "う", "と": "う", "ど": "う", "の": "う", "ほ": "う", "ぼ": "う", "ぽ": "う", "も": "う", "よ": "う", "ろ": "う", "を": "う", "ぉ": "う", "ょ": "う",
    ]

    private static let romajiToHiragana: [String: String] = [
        "kk": "っ", "gg": "っ", "ss": "っ", "zz": "っ", "jj": "っ", "tt": "っ", "dd": "っ", "hh": "っ", "ff": "っ", "bb": "っ", "pp": "っ", "mm": "っ", "yy": "っ", "rr": "っ", "ww": "っ", "cc": "っ",
        "hwyu": "ふゅ", "xtsu": "っ", "ltsu": "っ",
        "kya": "きゃ", "kyi": "きぃ", "kyu": "きゅ", "kye": "きぇ", "kyo": "きょ",
        "gya": "ぎゃ", "gyi": "ぎぃ", "gyu": "ぎゅ", "gye": "ぎぇ", "gyo": "ぎょ",
        "sha": "しゃ", "shi": "し", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
        "sya": "しゃ", "syi": "しぃ", "syu": "しゅ", "sye": "しぇ", "syo": "しょ",
        "cha": "ちゃ", "chi": "ち", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
        "tya": "ちゃ", "tyi": "ちぃ", "tyu": "ちゅ", "tye": "ちぇ", "tyo": "ちょ",
        "nya": "にゃ", "nyi": "にぃ", "nyu": "にゅ", "nye": "にぇ", "nyo": "にょ",
        "hya": "ひゃ", "hyi": "ひぃ", "hyu": "ひゅ", "hye": "ひぇ", "hyo": "ひょ",
        "bya": "びゃ", "byi": "びぃ", "byu": "びゅ", "bye": "びぇ", "byo": "びょ",
        "pya": "ぴゃ", "pyi": "ぴぃ", "pyu": "ぴゅ", "pye": "ぴぇ", "pyo": "ぴょ",
        "mya": "みゃ", "myi": "みぃ", "myu": "みゅ", "mye": "みぇ", "myo": "みょ",
        "rya": "りゃ", "ryi": "りぃ", "ryu": "りゅ", "rye": "りぇ", "ryo": "りょ",
        "tsu": "つ", "xtu": "っ", "ltu": "っ",
        "nn": "ん", "n'": "ん",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        "ja": "じゃ", "ji": "じ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "sa": "さ", "si": "し", "su": "す", "se": "せ", "so": "そ",
        "za": "ざ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ta": "た", "ti": "ち", "tu": "つ", "te": "て", "to": "と",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "ya": "や", "yu": "ゆ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お", "n": "ん",
    ]
}

private struct LookupTransform {
    let name: String
    let apply: @Sendable (String) -> String?
}
