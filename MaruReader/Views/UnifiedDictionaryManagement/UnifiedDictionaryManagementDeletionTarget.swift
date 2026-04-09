// UnifiedDictionaryManagementDeletionTarget.swift
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

import CoreData
import MaruDictionaryManagement
import MaruReaderCore

enum UnifiedDictionaryManagementDeletionTarget: Identifiable {
    case dictionary(Dictionary)
    case audioSource(AudioSource)

    var id: NSManagedObjectID {
        switch self {
        case let .dictionary(dictionary):
            dictionary.objectID
        case let .audioSource(audioSource):
            audioSource.objectID
        }
    }

    var name: String {
        switch self {
        case let .dictionary(dictionary):
            dictionary.title ?? AppLocalization.unknownDictionary
        case let .audioSource(audioSource):
            audioSource.name ?? AppLocalization.unknownSource
        }
    }

    var detailMessage: String {
        switch self {
        case let .dictionary(dictionary):
            var items: [String] = []

            if dictionary.termCount > 0 {
                items.append(AppLocalization.dictionaryTermsCount(dictionary.termCount))
            }
            if dictionary.termFrequencyCount > 0 {
                items.append(AppLocalization.dictionaryFrequencyCount(dictionary.termFrequencyCount))
            }
            if dictionary.kanjiCount > 0 {
                items.append(AppLocalization.dictionaryKanjiCount(dictionary.kanjiCount))
            }
            if dictionary.kanjiFrequencyCount > 0 {
                items.append(AppLocalization.dictionaryKanjiFrequencyCount(dictionary.kanjiFrequencyCount))
            }
            if dictionary.pitchesCount > 0 {
                items.append(AppLocalization.dictionaryPitchCount(dictionary.pitchesCount))
            }
            if dictionary.ipaCount > 0 {
                items.append(AppLocalization.dictionaryIPACount(dictionary.ipaCount))
            }

            if items.isEmpty {
                return String(localized: "This action cannot be undone.")
            }

            let summary = items.joined(separator: "\n")
            return String(localized: "This will delete:\n\(summary)\n\nThis action cannot be undone.")

        case let .audioSource(audioSource):
            let name = audioSource.name ?? AppLocalization.unknownSource
            return String(localized: "This will delete the audio source \"\(name)\" and all its data. This action cannot be undone.")
        }
    }
}
