//
//  DictionaryImportError.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/6/25.
//

enum DictionaryImportError: Error, Equatable {
    case notADictionary
    case unsupportedFormat
    case importNotFound
    case dictionaryCreationFailed
    case invalidData
    case databaseError
    case fileAccessDenied
    case missingFile
    case noWorkingDirectory
    case unzipFailed(underlyingError: Error)
    case deletionFailed

    var localizedDescription: String {
        switch self {
        case .notADictionary:
            "The selected file is not a valid dictionary."
        case .unsupportedFormat:
            "The dictionary format is unsupported."
        case .importNotFound:
            "The import operation the component requested was not found."
        case .dictionaryCreationFailed:
            "A database error occurred."
        case .invalidData:
            "The dictionary contains invalid data."
        case .databaseError:
            "A database error occurred while importing the dictionary."
        case .fileAccessDenied:
            "Could not access the dictionary file."
        case .missingFile:
            "The dictionary file is missing."
        case .noWorkingDirectory:
            "No working directory is available."
        case let .unzipFailed(underlyingError):
            "Failed to unzip the dictionary file: \(underlyingError.localizedDescription)"
        case .deletionFailed:
            "Failed to delete the dictionary."
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
             (.noWorkingDirectory, .noWorkingDirectory),
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
