// ImportError.swift
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

/// Errors that can occur during dictionary or audio source import.
public enum ImportError: Error, Equatable, LocalizedError {
    /// The archive does not contain a recognized dictionary or audio source.
    case unrecognizedArchive
    /// The archive is not a valid dictionary (missing required banks or structure).
    case notADictionary
    /// The archive is not a valid audio source (missing required index structure).
    case notAnAudioSource
    /// The archive is not a valid tokenizer dictionary (missing required manifest or resources).
    case notATokenizerDictionary
    /// The dictionary format version is not supported.
    case unsupportedFormat
    /// The import job was not found in Core Data.
    case importNotFound
    /// Failed to create the entity in Core Data.
    case entityCreationFailed
    /// The archive data is malformed or contains invalid entries.
    case invalidData
    /// A Core Data operation failed.
    case databaseError
    /// Unable to access the source file.
    case fileAccessDenied
    /// A required file is missing.
    case missingFile
    /// Failed to read the ZIP archive.
    case unzipFailed(underlyingError: Error)
    /// Failed to delete the entity and its data.
    case deletionFailed
    /// Failed to create a media directory.
    case mediaDirectoryCreationFailed

    public var errorDescription: String? {
        switch self {
        case .unrecognizedArchive:
            FrameworkLocalization.string("The selected file is not a recognized dictionary, grammar dictionary, tokenizer dictionary, or audio source.")
        case .notADictionary:
            FrameworkLocalization.string("The selected file is not a valid dictionary.")
        case .notAnAudioSource:
            FrameworkLocalization.string("The archive does not contain a valid audio source index.")
        case .notATokenizerDictionary:
            FrameworkLocalization.string("The archive does not contain a valid tokenizer dictionary.")
        case .unsupportedFormat:
            FrameworkLocalization.string("The dictionary format is unsupported.")
        case .importNotFound:
            FrameworkLocalization.string("The import job was not found.")
        case .entityCreationFailed:
            FrameworkLocalization.string("A database error occurred.")
        case .invalidData:
            FrameworkLocalization.string("The archive contains invalid data.")
        case .databaseError:
            FrameworkLocalization.string("A database error occurred during import.")
        case .fileAccessDenied:
            FrameworkLocalization.string("Could not access the file.")
        case .missingFile:
            FrameworkLocalization.string("The file is missing.")
        case let .unzipFailed(underlyingError):
            FrameworkLocalization.string("Failed to read the archive: \(underlyingError.localizedDescription)")
        case .deletionFailed:
            FrameworkLocalization.string("Failed to delete the item.")
        case .mediaDirectoryCreationFailed:
            FrameworkLocalization.string("Failed to create the media directory.")
        }
    }

    public static func == (lhs: ImportError, rhs: ImportError) -> Bool {
        switch (lhs, rhs) {
        case (.unrecognizedArchive, .unrecognizedArchive),
             (.notADictionary, .notADictionary),
             (.notAnAudioSource, .notAnAudioSource),
             (.notATokenizerDictionary, .notATokenizerDictionary),
             (.unsupportedFormat, .unsupportedFormat),
             (.importNotFound, .importNotFound),
             (.entityCreationFailed, .entityCreationFailed),
             (.invalidData, .invalidData),
             (.databaseError, .databaseError),
             (.fileAccessDenied, .fileAccessDenied),
             (.missingFile, .missingFile),
             (.deletionFailed, .deletionFailed),
             (.mediaDirectoryCreationFailed, .mediaDirectoryCreationFailed):
            true
        case (.unzipFailed, .unzipFailed):
            true
        default:
            false
        }
    }
}
