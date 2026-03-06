// AppLocalization.swift
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

enum AppLocalization {
    static let unknownDictionary = String(localized: "Unknown Dictionary")
    static let unknownSource = String(localized: "Unknown Source")
    static let unknownBook = String(localized: "Unknown Book")
    static let unnamed = String(localized: "Unnamed")
    static let defaultProfile = String(localized: "Default")
    static let defaultProfileLabel = String(localized: "Default Profile")

    static func deleteConfirmationActionCannotBeUndone(name: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Are you sure you want to delete \"%@\"? This action cannot be undone."),
            name
        )
    }

    static func deleteConfirmationCannotBeUndone(name: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Are you sure you want to delete \"%@\"? This cannot be undone."),
            name
        )
    }

    static func languagePair(source: String, target: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "%@ → %@"),
            source,
            target
        )
    }

    static func progress(received: String, total: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "%@ of %@"),
            received,
            total
        )
    }

    static func version(_ value: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Version %@"),
            value
        )
    }

    static func fieldsCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "%lld fields"),
            Int64(count)
        )
    }

    static func priority(_ value: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "Priority: %lld"),
            Int64(value)
        )
    }

    static func percentRead(_ value: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "%@ Read"),
            value
        )
    }

    static func fontScale(_ percent: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "Font Scale: %lld%%"),
            Int64(percent)
        )
    }

    static func loadedProfilesDecksModels(profiles: Int, decks: Int, models: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "Loaded %lld profiles, %lld decks, %lld note types."),
            Int64(profiles),
            Int64(decks),
            Int64(models)
        )
    }

    static func dictionaryTermsCount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "Terms: %lld"),
            value
        )
    }

    static func dictionaryKanjiCount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "Kanji: %lld"),
            value
        )
    }

    static func dictionaryFrequencyCount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "Frequency: %lld"),
            value
        )
    }

    static func dictionaryKanjiFrequencyCount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "Kanji Frequency: %lld"),
            value
        )
    }

    static func dictionaryPitchCount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "Pitch: %lld"),
            value
        )
    }

    static func dictionaryIPACount(_ value: Int64) -> String {
        String.localizedStringWithFormat(
            String(localized: "IPA: %lld"),
            value
        )
    }

    static func bookContextPosition(title: String, position: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "%@ - Position %lld"),
            title,
            Int64(position)
        )
    }

    static func bookContextPercent(title: String, percent: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "%@ - %lld%%"),
            title,
            Int64(percent)
        )
    }

    static func checkInDeck(_ deckName: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Check in %@"),
            deckName
        )
    }

    static func glossaryDictionary(_ title: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Glossary: %@"),
            title
        )
    }

    static func frequencyDictionary(_ title: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Frequency: %@"),
            title
        )
    }

    static func frequencyRankDictionary(_ title: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Freq Sort (Rank): %@"),
            title
        )
    }

    static func frequencyOccurrenceDictionary(_ title: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Freq Sort (Occ): %@"),
            title
        )
    }

    static func glossaryIdentifier(_ shortID: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Glossary (%@…)"),
            shortID
        )
    }

    static func htmlPreview(_ preview: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "HTML: %@"),
            preview
        )
    }

    static func ocrFailed(_ errorDescription: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "OCR failed: %@"),
            errorDescription
        )
    }

    static func failedToReorderDictionaries(_ errorDescription: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Failed to reorder dictionaries: %@"),
            errorDescription
        )
    }

    static func failedToUpdateFrequencyRanking(_ errorDescription: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Failed to update frequency ranking: %@"),
            errorDescription
        )
    }
}

extension SystemThemeManager.ThemeKind {
    var localizedDisplayName: String {
        switch self {
        case .light:
            String(localized: "Light")
        case .dark:
            String(localized: "Dark")
        case .sepia:
            String(localized: "Sepia")
        }
    }
}

extension SystemThemeManager {
    func localizedDisplayName(for theme: ReaderTheme?) -> String {
        if let kind = kind(for: theme) {
            return kind.localizedDisplayName
        }
        if let name = theme?.name, !name.isEmpty {
            return name
        }
        return AppLocalization.unnamed
    }

    func localizedDisplayName(for profile: ReaderProfile?) -> String {
        guard let profile else {
            return AppLocalization.unnamed
        }
        if profile.isDefault {
            return AppLocalization.defaultProfile
        }
        if let name = profile.name, !name.isEmpty {
            return name
        }
        return AppLocalization.unnamed
    }
}
