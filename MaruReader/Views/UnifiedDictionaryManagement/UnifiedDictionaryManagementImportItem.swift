// UnifiedDictionaryManagementImportItem.swift
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

enum UnifiedDictionaryManagementImportItem: Identifiable {
    case dictionary(Dictionary)
    case audioSource(AudioSource)
    case tokenizerDictionary(TokenizerDictionary)

    var id: NSManagedObjectID {
        objectID
    }

    var objectID: NSManagedObjectID {
        switch self {
        case let .dictionary(dictionary):
            dictionary.objectID
        case let .audioSource(audioSource):
            audioSource.objectID
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.objectID
        }
    }

    var displayName: String {
        switch self {
        case let .dictionary(dictionary):
            if let title = dictionary.title, !title.isEmpty {
                return title
            }

            return dictionary.file?.deletingPathExtension().lastPathComponent ?? AppLocalization.unknownDictionary

        case let .audioSource(audioSource):
            if let name = audioSource.name, !name.isEmpty {
                return name
            }

            return audioSource.file?.deletingPathExtension().lastPathComponent ?? AppLocalization.unknownSource

        case let .tokenizerDictionary(tokenizerDictionary):
            if let name = tokenizerDictionary.name, !name.isEmpty {
                return name
            }

            return tokenizerDictionary.file?.deletingPathExtension().lastPathComponent ?? String(localized: "Unknown Tokenizer Dictionary")
        }
    }

    var isStarted: Bool {
        switch self {
        case let .dictionary(dictionary):
            dictionary.isStarted
        case let .audioSource(audioSource):
            audioSource.isStarted
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.isStarted
        }
    }

    var isFailed: Bool {
        switch self {
        case let .dictionary(dictionary):
            dictionary.isFailed
        case let .audioSource(audioSource):
            audioSource.isFailed
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.isFailed
        }
    }

    var isCancelled: Bool {
        switch self {
        case let .dictionary(dictionary):
            dictionary.isCancelled
        case let .audioSource(audioSource):
            audioSource.isCancelled
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.isCancelled
        }
    }

    var pendingDeletion: Bool {
        switch self {
        case let .dictionary(dictionary):
            dictionary.pendingDeletion
        case let .audioSource(audioSource):
            audioSource.pendingDeletion
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.pendingDeletion
        }
    }

    var displayProgressMessage: String? {
        switch self {
        case let .dictionary(dictionary):
            dictionary.displayProgressMessage
        case let .audioSource(audioSource):
            audioSource.displayProgressMessage
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.displayProgressMessage
        }
    }

    var errorMessage: String? {
        switch self {
        case let .dictionary(dictionary):
            dictionary.errorMessage
        case let .audioSource(audioSource):
            audioSource.displayProgressMessage
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.errorMessage
        }
    }

    var timeQueued: Date? {
        switch self {
        case let .dictionary(dictionary):
            dictionary.timeQueued
        case let .audioSource(audioSource):
            audioSource.timeQueued
        case let .tokenizerDictionary(tokenizerDictionary):
            tokenizerDictionary.timeQueued
        }
    }

    var canCancel: Bool {
        !isFailed && !isCancelled && !pendingDeletion
    }
}
