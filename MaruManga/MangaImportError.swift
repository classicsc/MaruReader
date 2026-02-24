// MangaImportError.swift
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

enum MangaImportError: Error, Equatable, LocalizedError {
    case noImagesFound
    case invalidArchive
    case archiveNotFound
    case databaseError
    case fileAccessDenied
    case missingFile
    case fileCopyFailed(underlyingError: Error)
    case coverExtractionFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .noImagesFound:
            String(localized: "The archive contains no supported image files.")
        case .invalidArchive:
            String(localized: "The selected file is not a valid ZIP or CBZ archive.")
        case .archiveNotFound:
            String(localized: "The import operation was not found.")
        case .databaseError:
            String(localized: "A database error occurred while importing the manga.")
        case .fileAccessDenied:
            String(localized: "Could not access the archive file.")
        case .missingFile:
            String(localized: "The archive file is missing.")
        case let .fileCopyFailed(underlyingError):
            String(localized: "Failed to copy the archive file: \(underlyingError.localizedDescription)")
        case let .coverExtractionFailed(underlyingError):
            String(localized: "Failed to extract cover image: \(underlyingError.localizedDescription)")
        }
    }

    static func == (lhs: MangaImportError, rhs: MangaImportError) -> Bool {
        switch (lhs, rhs) {
        case (.noImagesFound, .noImagesFound),
             (.invalidArchive, .invalidArchive),
             (.archiveNotFound, .archiveNotFound),
             (.databaseError, .databaseError),
             (.fileAccessDenied, .fileAccessDenied),
             (.missingFile, .missingFile):
            true
        case (.fileCopyFailed, .fileCopyFailed),
             (.coverExtractionFailed, .coverExtractionFailed):
            // Ignore underlying error when comparing for equality in tests
            true
        default:
            false
        }
    }
}
