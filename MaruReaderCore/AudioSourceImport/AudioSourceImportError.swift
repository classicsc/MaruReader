//
//  AudioSourceImportError.swift
//  MaruReader
//
//  Created by Claude on 12/12/25.
//

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
    /// The working directory is not set or does not exist.
    case noWorkingDirectory
    /// Failed to extract the ZIP archive.
    case unzipFailed(underlyingError: Error)
    /// Failed to delete the audio source and its data.
    case deletionFailed
    /// Failed to create the media directory for audio files.
    case mediaDirectoryCreationFailed

    public var errorDescription: String? {
        switch self {
        case .notAnAudioSource:
            "The archive does not contain a valid audio source index."
        case .invalidFormat:
            "The audio source index has an invalid format."
        case .importNotFound:
            "The import job was not found."
        case .sourceCreationFailed:
            "Failed to create the audio source."
        case .invalidData:
            "The audio source data is invalid."
        case .databaseError:
            "A database error occurred."
        case .fileAccessDenied:
            "Unable to access the source file."
        case .missingFile:
            "A required file is missing."
        case .noWorkingDirectory:
            "No working directory available."
        case let .unzipFailed(error):
            "Failed to extract archive: \(error.localizedDescription)"
        case .deletionFailed:
            "Failed to delete the audio source."
        case .mediaDirectoryCreationFailed:
            "Failed to create the audio media directory."
        }
    }
}
