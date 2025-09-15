//
//  ConvertKatakanaToHiraganaRule.swift
//  MaruReader
//
//  Created by Sam Smoker on 8/15/25.
//

import Foundation

/// Converts katakana characters to hiragana equivalents
/// Based on Yomitan's convertKatakanaToHiragana function
class ConvertKatakanaToHiraganaRule: TextPreprocessorRule {
    let name = "convertKatakanaToHiragana"
    let description = "Convert katakana to hiragana: カタカナ → かたかな"

    private let keepProlongedSoundMarks: Bool

    // Unicode code points for special characters
    private static let hiraganaSmallTsuCodePoint: UInt32 = 0x3063
    private static let katakanaSmallTsuCodePoint: UInt32 = 0x30C3
    private static let katakanaSmallKaCodePoint: UInt32 = 0x30F5
    private static let katakanaSmallKeCodePoint: UInt32 = 0x30F6
    private static let kanaProlongedSoundMarkCodePoint: UInt32 = 0x30FC

    // Unicode ranges for conversion
    private static let hiraganaConversionRange: ClosedRange<UInt32> = 0x3041 ... 0x3096
    private static let katakanaConversionRange: ClosedRange<UInt32> = 0x30A1 ... 0x30F6

    init(keepProlongedSoundMarks: Bool = false) {
        self.keepProlongedSoundMarks = keepProlongedSoundMarks
    }

    /// Get the prolonged hiragana vowel for the given character
    /// Based on Yomitan's getProlongedHiragana function
    private func getProlongedHiragana(for previousCharacter: Character) -> Character? {
        // Map character to vowel sound, then return appropriate prolonged vowel
        let vowelMapping: [Character: Character] = [
            // Hiragana a-sounds -> あ
            "あ": "あ", "か": "あ", "が": "あ", "さ": "あ", "ざ": "あ", "た": "あ", "だ": "あ", "な": "あ", "は": "あ", "ば": "あ", "ぱ": "あ", "ま": "あ", "や": "あ", "ら": "あ", "わ": "あ", "ぁ": "あ", "ゃ": "あ",
            // Hiragana i-sounds -> い
            "い": "い", "き": "い", "ぎ": "い", "し": "い", "じ": "い", "ち": "い", "ぢ": "い", "に": "い", "ひ": "い", "び": "い", "ぴ": "い", "み": "い", "り": "い", "ぃ": "い",
            // Hiragana u-sounds -> う
            "う": "う", "く": "う", "ぐ": "う", "す": "う", "ず": "う", "つ": "う", "づ": "う", "ぬ": "う", "ふ": "う", "ぶ": "う", "ぷ": "う", "む": "う", "ゆ": "う", "る": "う", "ぅ": "う", "ゅ": "う", "っ": "う",
            // Hiragana e-sounds -> え
            "え": "え", "け": "え", "げ": "え", "せ": "え", "ぜ": "え", "て": "え", "で": "え", "ね": "え", "へ": "え", "べ": "え", "ぺ": "え", "め": "え", "れ": "え", "ぇ": "え",
            // Hiragana o-sounds -> う (o-sounds use う for prolongation)
            "お": "う", "こ": "う", "ご": "う", "そ": "う", "ぞ": "う", "と": "う", "ど": "う", "の": "う", "ほ": "う", "ぼ": "う", "ぽ": "う", "も": "う", "よ": "う", "ろ": "う", "を": "う", "ぉ": "う", "ょ": "う",
        ]

        return vowelMapping[previousCharacter]
    }

    func process(_ text: String) -> String {
        var result = ""
        let offset = Int(Self.hiraganaConversionRange.lowerBound) - Int(Self.katakanaConversionRange.lowerBound)

        for char in text {
            guard let codePoint = char.unicodeScalars.first?.value else {
                result.append(char)
                continue
            }

            var convertedChar = char

            switch codePoint {
            case Self.katakanaSmallKaCodePoint, Self.katakanaSmallKeCodePoint:
                // No change for these special katakana characters
                break
            case Self.kanaProlongedSoundMarkCodePoint:
                // Convert prolonged sound mark to appropriate vowel if not keeping marks
                if !keepProlongedSoundMarks, !result.isEmpty {
                    let lastChar = result.last!
                    if let prolongedVowel = getProlongedHiragana(for: lastChar) {
                        convertedChar = prolongedVowel
                    }
                }
            default:
                // Convert katakana in conversion range to hiragana
                if Self.katakanaConversionRange.contains(codePoint) {
                    let newCodePoint = UInt32(Int(codePoint) + offset)
                    convertedChar = Character(UnicodeScalar(newCodePoint)!)
                }
            }

            result.append(convertedChar)
        }

        return result
    }
}
