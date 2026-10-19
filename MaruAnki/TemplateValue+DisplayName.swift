// TemplateValue+DisplayName.swift
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

public extension TemplateValue {
    static func singleDictionaryGlossary(dictionaryID: UUID, includeTitle: Bool, plain: Bool) -> TemplateValue {
        switch (includeTitle, plain) {
        case (true, false): .singleDictionaryGlossary(dictionaryID: dictionaryID)
        case (false, false): .singleDictionaryGlossaryNoDictionary(dictionaryID: dictionaryID)
        case (true, true): .singleDictionaryGlossaryPlain(dictionaryID: dictionaryID)
        case (false, true): .singleDictionaryGlossaryPlainNoDictionary(dictionaryID: dictionaryID)
        }
    }

    static func multiDictionaryGlossary(includeTitle: Bool, plain: Bool) -> TemplateValue {
        switch (includeTitle, plain) {
        case (true, false): .multiDictionaryGlossary
        case (false, false): .multiDictionaryGlossaryNoDictionary
        case (true, true): .multiDictionaryGlossaryPlain
        case (false, true): .multiDictionaryGlossaryPlainNoDictionary
        }
    }

    var dictionaryGlossaryOptions: (dictionaryID: UUID, includeTitle: Bool, plain: Bool)? {
        switch self {
        case let .singleDictionaryGlossary(id): (id, true, false)
        case let .singleDictionaryGlossaryNoDictionary(id): (id, false, false)
        case let .singleDictionaryGlossaryPlain(id): (id, true, true)
        case let .singleDictionaryGlossaryPlainNoDictionary(id): (id, false, true)
        default: nil
        }
    }

    /// Glossary formatting options for both single and multi dictionary values.
    var glossaryOptions: (includeTitle: Bool, plain: Bool)? {
        if let options = dictionaryGlossaryOptions {
            return (options.includeTitle, options.plain)
        }
        switch self {
        case .singleGlossary, .multiDictionaryGlossary: return (true, false)
        case .glossaryNoDictionary, .multiDictionaryGlossaryNoDictionary: return (false, false)
        case .singleGlossaryPlain, .multiDictionaryGlossaryPlain: return (true, true)
        case .singleGlossaryPlainNoDictionary, .multiDictionaryGlossaryPlainNoDictionary: return (false, true)
        default: return nil
        }
    }

    /// The dictionary a value refers to, when it refers to exactly one.
    var dictionaryID: UUID? {
        switch self {
        case let .singleDictionaryGlossary(id),
             let .singleDictionaryGlossaryNoDictionary(id),
             let .singleDictionaryGlossaryPlain(id),
             let .singleDictionaryGlossaryPlainNoDictionary(id),
             let .singlePitchAccentDictionary(id),
             let .singleFrequencyDictionary(id),
             let .frequencyRankSortField(id),
             let .frequencyOccurrenceSortField(id):
            id
        default:
            nil
        }
    }

    /// A display name that includes the dictionary's title for dictionary-specific values.
    func displayName(dictionaryTitle: String) -> String {
        if let glossary = dictionaryGlossaryOptions {
            return Self.glossaryDictionaryName(dictionaryTitle, includeTitle: glossary.includeTitle, plain: glossary.plain)
        }
        switch self {
        case .singleFrequencyDictionary:
            return AnkiLocalization.string("Frequency: \(dictionaryTitle)")
        case .frequencyRankSortField:
            return AnkiLocalization.string("Freq Sort (Rank): \(dictionaryTitle)")
        case .frequencyOccurrenceSortField:
            return AnkiLocalization.string("Freq Sort (Occ): \(dictionaryTitle)")
        case .singlePitchAccentDictionary:
            return AnkiLocalization.string("Pitch Accent: \(dictionaryTitle)")
        default:
            return displayName
        }
    }

    private static func glossaryDictionaryName(_ title: String, includeTitle: Bool, plain: Bool) -> String {
        switch (includeTitle, plain) {
        case (true, false): AnkiLocalization.string("Glossary: \(title)")
        case (false, false): AnkiLocalization.string("Glossary (No Title): \(title)")
        case (true, true): AnkiLocalization.string("Glossary (Plain): \(title)")
        case (false, true): AnkiLocalization.string("Glossary (Plain, No Title): \(title)")
        }
    }

    var displayName: String {
        switch self {
        case let .singleDictionaryGlossary(dictionaryID):
            let shortID = String(dictionaryID.uuidString.prefix(8))
            return AnkiLocalization.string("Glossary (\(shortID)…)")
        case let .singleDictionaryGlossaryNoDictionary(dictionaryID):
            return Self.glossaryDictionaryName("\(dictionaryID.uuidString.prefix(8))…", includeTitle: false, plain: false)
        case let .singleDictionaryGlossaryPlain(dictionaryID):
            return Self.glossaryDictionaryName("\(dictionaryID.uuidString.prefix(8))…", includeTitle: true, plain: true)
        case let .singleDictionaryGlossaryPlainNoDictionary(dictionaryID):
            return Self.glossaryDictionaryName("\(dictionaryID.uuidString.prefix(8))…", includeTitle: false, plain: true)
        case .singleGlossary: return AnkiLocalization.string("Single Glossary (First Dictionary)")
        case .singleGlossaryPlain: return AnkiLocalization.string("Single Glossary (First Dictionary, Plain)")
        case .singleGlossaryPlainNoDictionary: return AnkiLocalization.string("Single Glossary (First Dictionary, Plain, No Title)")
        case .multiDictionaryGlossary: return AnkiLocalization.string("Multi-Dictionary Glossary")
        case .multiDictionaryGlossaryNoDictionary: return AnkiLocalization.string("Multi-Dictionary Glossary (No Titles)")
        case .multiDictionaryGlossaryPlain: return AnkiLocalization.string("Multi-Dictionary Glossary (Plain)")
        case .multiDictionaryGlossaryPlainNoDictionary: return AnkiLocalization.string("Multi-Dictionary Glossary (Plain, No Titles)")
        case .pronunciationAudio: return AnkiLocalization.string("Pronunciation Audio")
        case .expression: return AnkiLocalization.string("Expression")
        case let .customHTMLValue(value):
            let truncated = value.count > 20 ? String(value.prefix(20)) + "..." : value
            return AnkiLocalization.string("Text: \(truncated)")
        case .furigana: return AnkiLocalization.string("Furigana")
        case .glossaryNoDictionary: return AnkiLocalization.string("Single Glossary (First Dictionary, No Title)")
        case .reading: return AnkiLocalization.string("Reading")
        case .selectionText: return AnkiLocalization.string("Selection Text")
        case .sentence: return AnkiLocalization.string("Sentence")
        case .clozePrefix: return AnkiLocalization.string("Cloze Prefix")
        case .clozeBody: return AnkiLocalization.string("Cloze Body")
        case .clozeSuffix: return AnkiLocalization.string("Cloze Suffix")
        case .clozeFuriganaPrefix: return AnkiLocalization.string("Cloze Furigana Prefix")
        case .clozeFuriganaBody: return AnkiLocalization.string("Cloze Furigana Body")
        case .clozeFuriganaSuffix: return AnkiLocalization.string("Cloze Furigana Suffix")
        case .tags: return AnkiLocalization.string("Tags")
        case .contextImage: return AnkiLocalization.string("Context Image")
        case .contextInfo: return AnkiLocalization.string("Context Info")
        case .singlePitchAccent: return AnkiLocalization.string("Single Pitch Accent")
        case .singlePitchAccentDictionary: return AnkiLocalization.string("Pitch Accent (Dictionary)")
        case .pitchAccentList: return AnkiLocalization.string("Pitch Accent List")
        case .pitchAccentDisambiguation: return AnkiLocalization.string("Pitch Disambiguation")
        case .pitchAccentCategories: return AnkiLocalization.string("Pitch Accent Categories")
        case .conjugation: return AnkiLocalization.string("Conjugation")
        case .frequencyList: return AnkiLocalization.string("Frequency List")
        case .singleFrequency: return AnkiLocalization.string("Single Frequency")
        case .singleFrequencyDictionary: return AnkiLocalization.string("Frequency (Dictionary)")
        case .frequencyRankSortField: return AnkiLocalization.string("Frequency Sort (Rank)")
        case .frequencyOccurrenceSortField: return AnkiLocalization.string("Frequency Sort (Occurrence)")
        case .frequencyRankHarmonicMeanSortField: return AnkiLocalization.string("Frequency Sort (Rank HM)")
        case .frequencyOccurrenceHarmonicMeanSortField: return AnkiLocalization.string("Frequency Sort (Occ HM)")
        case .partOfSpeech: return AnkiLocalization.string("Part of Speech")
        case .sentenceFurigana: return AnkiLocalization.string("Sentence (Furigana)")
        @unknown default: return AnkiLocalization.string("Unknown")
        }
    }
}
