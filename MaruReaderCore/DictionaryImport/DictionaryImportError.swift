// DictionaryImportError.swift
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

enum DictionaryImportError: Error, Equatable, LocalizedError {
    case notADictionary
    case unsupportedFormat
    case importNotFound
    case dictionaryCreationFailed
    case invalidData
    case databaseError
    case fileAccessDenied
    case missingFile
    case unzipFailed(underlyingError: Error)
    case deletionFailed
    case mediaDirectoryCreationFailed

    var errorDescription: String {
        switch self {
        case .notADictionary:
            String(localized: "The selected file is not a valid dictionary.")
        case .unsupportedFormat:
            String(localized: "The dictionary format is unsupported.")
        case .importNotFound:
            String(localized: "The import operation the component requested was not found.")
        case .dictionaryCreationFailed:
            String(localized: "A database error occurred.")
        case .invalidData:
            String(localized: "The dictionary contains invalid data.")
        case .databaseError:
            String(localized: "A database error occurred while importing the dictionary.")
        case .fileAccessDenied:
            String(localized: "Could not access the dictionary file.")
        case .missingFile:
            String(localized: "The dictionary file is missing.")
        case let .unzipFailed(underlyingError):
            String(localized: "Failed to read the dictionary archive: \(underlyingError.localizedDescription)")
        case .deletionFailed:
            String(localized: "Failed to delete the dictionary.")
        case .mediaDirectoryCreationFailed:
            String(localized: "Failed to create media directory for the dictionary.")
        }
    }

    static func == (lhs: DictionaryImportError, rhs: DictionaryImportError) -> Bool {
        switch (lhs, rhs) {
        case (.notADictionary, .notADictionary),
             (.unsupportedFormat, .unsupportedFormat),
             (.importNotFound, .importNotFound),
             (.dictionaryCreationFailed, .dictionaryCreationFailed),
             (.invalidData, .invalidData),
             (.databaseError, .databaseError),
             (.fileAccessDenied, .fileAccessDenied),
             (.missingFile, .missingFile),
             (.deletionFailed, .deletionFailed):
            true
        case (.unzipFailed, .unzipFailed):
            // Ignore underlying error when comparing for equality in tests
            true
        default:
            false
        }
    }
}
