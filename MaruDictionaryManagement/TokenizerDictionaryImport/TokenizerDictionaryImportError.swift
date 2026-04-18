// TokenizerDictionaryImportError.swift
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

enum TokenizerDictionaryImportError: Error, Equatable, LocalizedError {
    case notATokenizerDictionary
    case unsupportedFormat
    case importNotFound
    case tokenizerDictionaryCreationFailed
    case invalidData
    case databaseError
    case missingFile
    case unzipFailed(underlyingError: Error)
    case installationFailed

    var errorDescription: String? {
        switch self {
        case .notATokenizerDictionary:
            FrameworkLocalization.string("The selected file is not a valid tokenizer dictionary.")
        case .unsupportedFormat:
            FrameworkLocalization.string("The tokenizer dictionary format is unsupported.")
        case .importNotFound:
            FrameworkLocalization.string("The tokenizer dictionary import job was not found.")
        case .tokenizerDictionaryCreationFailed:
            FrameworkLocalization.string("A database error occurred.")
        case .invalidData:
            FrameworkLocalization.string("The tokenizer dictionary contains invalid data.")
        case .databaseError:
            FrameworkLocalization.string("A database error occurred while importing the tokenizer dictionary.")
        case .missingFile:
            FrameworkLocalization.string("A required tokenizer dictionary file is missing.")
        case let .unzipFailed(underlyingError):
            FrameworkLocalization.string("Failed to read the tokenizer dictionary archive: \(underlyingError.localizedDescription)")
        case .installationFailed:
            FrameworkLocalization.string("Failed to install the tokenizer dictionary.")
        }
    }

    static func == (lhs: TokenizerDictionaryImportError, rhs: TokenizerDictionaryImportError) -> Bool {
        switch (lhs, rhs) {
        case (.notATokenizerDictionary, .notATokenizerDictionary),
             (.unsupportedFormat, .unsupportedFormat),
             (.importNotFound, .importNotFound),
             (.tokenizerDictionaryCreationFailed, .tokenizerDictionaryCreationFailed),
             (.invalidData, .invalidData),
             (.databaseError, .databaseError),
             (.missingFile, .missingFile),
             (.installationFailed, .installationFailed):
            true
        case (.unzipFailed, .unzipFailed):
            true
        default:
            false
        }
    }
}
