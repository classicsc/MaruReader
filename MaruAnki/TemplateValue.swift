// TemplateValue.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// The values that can be used to populate note fields.
public enum TemplateValue: Sendable, Codable, Hashable {
    case singleDictionaryGlossary(dictionaryID: UUID)
    case singleGlossary
    case multiDictionaryGlossary
    case pronunciationAudio
    case expression
    case customHTMLValue(value: String)
    case furigana
    case glossaryNoDictionary
    case reading
    case sentence
    case clozePrefix
    case clozeBody
    case clozeSuffix
    case clozeFuriganaPrefix
    case clozeFuriganaBody
    case clozeFuriganaSuffix
    case tags
    case contextImage
    case contextInfo
    case singlePitchAccent
    case singlePitchAccentDictionary(dictionaryID: UUID)
    case pitchAccentList
    case pitchAccentDisambiguation
    case pitchAccentCategories
    case conjugation
    case frequencyList
    case singleFrequency
    case singleFrequencyDictionary(dictionaryID: UUID)
    case frequencyRankSortField(dictionaryID: UUID)
    case frequencyOccurrenceSortField(dictionaryID: UUID)
    case frequencyRankHarmonicMeanSortField
    case frequencyOccurrenceHarmonicMeanSortField
    case partOfSpeech
    case sentenceFurigana
}
