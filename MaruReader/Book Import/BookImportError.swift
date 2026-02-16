// BookImportError.swift
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

enum BookImportError: Error, Equatable {
    case notABook
    case unsupportedFormat
    case importNotFound
    case bookCreationFailed
    case invalidData
    case databaseError
    case fileAccessDenied
    case missingFile
    case fileCopyFailed(underlyingError: Error)
    case coverExtractionFailed(underlyingError: Error)
    case metadataExtractionFailed(underlyingError: Error)

    var localizedDescription: String {
        switch self {
        case .notABook:
            "The selected file is not a valid book."
        case .unsupportedFormat:
            "The book format is unsupported."
        case .importNotFound:
            "The import operation was not found."
        case .bookCreationFailed:
            "Failed to create book in database."
        case .invalidData:
            "The book contains invalid data."
        case .databaseError:
            "A database error occurred while importing the book."
        case .fileAccessDenied:
            "Could not access the book file."
        case .missingFile:
            "The book file is missing."
        case let .fileCopyFailed(underlyingError):
            "Failed to copy the book file: \(underlyingError.localizedDescription)"
        case let .coverExtractionFailed(underlyingError):
            "Failed to extract book cover: \(underlyingError.localizedDescription)"
        case let .metadataExtractionFailed(underlyingError):
            "Failed to extract book metadata: \(underlyingError.localizedDescription)"
        }
    }

    static func == (lhs: BookImportError, rhs: BookImportError) -> Bool {
        switch (lhs, rhs) {
        case (.notABook, .notABook),
             (.unsupportedFormat, .unsupportedFormat),
             (.importNotFound, .importNotFound),
             (.bookCreationFailed, .bookCreationFailed),
             (.invalidData, .invalidData),
             (.databaseError, .databaseError),
             (.fileAccessDenied, .fileAccessDenied),
             (.missingFile, .missingFile):
            true
        case (.fileCopyFailed, .fileCopyFailed),
             (.coverExtractionFailed, .coverExtractionFailed),
             (.metadataExtractionFailed, .metadataExtractionFailed):
            // Ignore underlying error when comparing for equality in tests
            true
        default:
            false
        }
    }
}
