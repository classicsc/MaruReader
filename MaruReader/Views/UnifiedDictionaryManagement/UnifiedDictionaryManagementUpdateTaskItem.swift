// UnifiedDictionaryManagementUpdateTaskItem.swift
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

enum UnifiedDictionaryManagementUpdateTaskItem: Identifiable {
    case dictionary(DictionaryUpdateTask)
    case tokenizerDictionary(TokenizerDictionaryUpdateTask)

    var id: NSManagedObjectID {
        objectID
    }

    var objectID: NSManagedObjectID {
        switch self {
        case let .dictionary(task):
            task.objectID
        case let .tokenizerDictionary(task):
            task.objectID
        }
    }

    var displayName: String {
        switch self {
        case let .dictionary(task):
            task.dictionaryTitle ?? String(localized: "Dictionary Update")
        case let .tokenizerDictionary(task):
            task.tokenizerDictionaryName ?? String(localized: "Tokenizer Dictionary Update")
        }
    }

    var displayProgressMessage: String? {
        switch self {
        case let .dictionary(task):
            task.displayProgressMessage
        case let .tokenizerDictionary(task):
            task.displayProgressMessage
        }
    }

    var bytesReceived: Int64 {
        switch self {
        case let .dictionary(task):
            task.bytesReceived
        case let .tokenizerDictionary(task):
            task.bytesReceived
        }
    }

    var totalBytes: Int64 {
        switch self {
        case let .dictionary(task):
            task.totalBytes
        case let .tokenizerDictionary(task):
            task.totalBytes
        }
    }

    var isStarted: Bool {
        switch self {
        case let .dictionary(task):
            task.isStarted
        case let .tokenizerDictionary(task):
            task.isStarted
        }
    }
}
