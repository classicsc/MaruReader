// MangaImportError.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

enum MangaImportError: Error, Equatable {
    case noImagesFound
    case invalidArchive
    case archiveNotFound
    case databaseError
    case fileAccessDenied
    case missingFile
    case fileCopyFailed(underlyingError: Error)
    case coverExtractionFailed(underlyingError: Error)

    var localizedDescription: String {
        switch self {
        case .noImagesFound:
            "The archive contains no supported image files."
        case .invalidArchive:
            "The selected file is not a valid ZIP or CBZ archive."
        case .archiveNotFound:
            "The import operation was not found."
        case .databaseError:
            "A database error occurred while importing the manga."
        case .fileAccessDenied:
            "Could not access the archive file."
        case .missingFile:
            "The archive file is missing."
        case let .fileCopyFailed(underlyingError):
            "Failed to copy the archive file: \(underlyingError.localizedDescription)"
        case let .coverExtractionFailed(underlyingError):
            "Failed to extract cover image: \(underlyingError.localizedDescription)"
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
