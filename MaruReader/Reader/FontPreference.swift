//
//  FontPreference.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/6/25.
//

struct FontPreference: Codable {
    let preferredFontFamily: String
    let fallbackFontFamilies: [String]
}

enum SystemDefaultFontPreferenceForLanguage {
    case japanese
    case chineseSimplified
    case chineseTraditional
    case korean
    case english
    case otherLatin
    case other

    var fontPreference: FontPreference {
        switch self {
        case .japanese:
            FontPreference(
                preferredFontFamily: "Hiragino Mincho ProN",
                fallbackFontFamilies: [
                    "Noto Serif JP", "Source Han Serif JP", "serif",
                ]
            )
        case .chineseSimplified:
            FontPreference(
                preferredFontFamily: "Songti SC",
                fallbackFontFamilies: ["Noto Serif SC", "Source Han Serif SC", "serif"]
            )
        case .chineseTraditional:
            FontPreference(
                preferredFontFamily: "Songti TC",
                fallbackFontFamilies: ["Noto Serif TC", "Source Han Serif TC", "serif"]
            )
        case .korean:
            FontPreference(
                preferredFontFamily: "Noto Serif KR",
                fallbackFontFamilies: ["Source Han Serif KR", "serif"]
            )
        case .english:
            FontPreference(
                preferredFontFamily: "New York",
                fallbackFontFamilies: ["Georgia", "serif"]
            )
        case .otherLatin:
            FontPreference(
                preferredFontFamily: "New York",
                fallbackFontFamilies: ["Georgia", "Noto Serif", "serif"]
            )
        case .other:
            FontPreference(
                preferredFontFamily: "New York",
                fallbackFontFamilies: ["Georgia", "Noto Serif", "serif"]
            )
        }
    }
}
