//
//  BookImportError.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

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
