// AudioSourceImportError.swift
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

/// Errors that can occur during audio source import.
public enum AudioSourceImportError: Error, LocalizedError {
    /// The archive does not contain a valid audio source index JSON file.
    case notAnAudioSource
    /// The JSON structure is invalid or missing required fields.
    case invalidFormat
    /// The import job was not found in Core Data.
    case importNotFound
    /// Failed to create the AudioSource entity.
    case sourceCreationFailed
    /// The JSON data is malformed or contains invalid entries.
    case invalidData
    /// A Core Data operation failed.
    case databaseError
    /// Unable to access the source file.
    case fileAccessDenied
    /// A required file is missing from the archive.
    case missingFile
    /// Failed to extract the ZIP archive.
    case unzipFailed(underlyingError: Error)
    /// Failed to delete the audio source and its data.
    case deletionFailed
    /// Failed to create the media directory for audio files.
    case mediaDirectoryCreationFailed

    public var errorDescription: String? {
        switch self {
        case .notAnAudioSource:
            FrameworkLocalization.string("The archive does not contain a valid audio source index.")
        case .invalidFormat:
            FrameworkLocalization.string("The audio source index has an invalid format.")
        case .importNotFound:
            FrameworkLocalization.string("The import job was not found.")
        case .sourceCreationFailed:
            FrameworkLocalization.string("Failed to create the audio source.")
        case .invalidData:
            FrameworkLocalization.string("The audio source data is invalid.")
        case .databaseError:
            FrameworkLocalization.string("A database error occurred.")
        case .fileAccessDenied:
            FrameworkLocalization.string("Unable to access the source file.")
        case .missingFile:
            FrameworkLocalization.string("A required file is missing.")
        case let .unzipFailed(error):
            FrameworkLocalization.string("Failed to read archive: \(error.localizedDescription)")
        case .deletionFailed:
            FrameworkLocalization.string("Failed to delete the audio source.")
        case .mediaDirectoryCreationFailed:
            FrameworkLocalization.string("Failed to create the audio media directory.")
        }
    }
}
