//
//  TemplateValue.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/15/25.
//

import Foundation

/// The values that can be used to populate note fields.
public enum TemplateValue: Sendable, Codable, Hashable {
    case singleDictionaryGlossary(dictionaryID: UUID)
    case multiDictionaryGlossary
    case pronunciationAudio
    case character
    case expression
    case customHTMLValue(value: String)
    case dictionaryTitle
    case furigana
    case glossaryNoDictionary
    case kunyomi
    case onyomi
    case onyomiAsHiragana
    case reading
    case sentence
    case clozePrefix
    case clozeBody
    case clozeSuffix
    case tags
    case documentURL
    case screenshot
    case documentCoverImage
    case documentTitle
    case singlePitchAccent
    case singlePitchAccentDictionary(dictionaryID: UUID)
    case pitchAccentList
    case pitchAccentDisambiguation
    case conjugation
    case frequencyList
    case singleFrequency
    case singleFrequencyDictionary(dictionaryID: UUID)
    case frequencyRankSortField(dictionaryID: UUID)
    case frequencyOccurrenceSortField(dictionaryID: UUID)
    case frequencyRankHarmonicMeanSortField
    case frequencyOccurrenceHarmonicMeanSortField
    case strokeCount
    case partOfSpeech
    case sentenceFurigana
}
