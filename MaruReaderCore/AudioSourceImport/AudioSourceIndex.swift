// AudioSourceIndex.swift
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

/// Root structure for an audio source index JSON file.
///
/// The format supports both local sources (with audio files in a ZIP)
/// and online sources (with a remote base URL for audio files).
///
/// Example:
/// ```json
/// {
///   "meta": {
///     "name": "Source name",
///     "year": 2025,
///     "version": 2,
///     "media_dir": "media",
///     "media_dir_abs": "https://example.com/audio"
///   },
///   "headwords": {
///     "私": ["file1.ogg", "file2.ogg"]
///   },
///   "files": {
///     "file1.ogg": {
///       "kana_reading": "わたし",
///       "pitch_number": "0"
///     }
///   }
/// }
/// ```
struct AudioSourceIndex: Codable, Sendable {
    let meta: AudioSourceMeta
    let headwords: [String: [String]]
    let files: [String: AudioFileInfo]
}

/// Metadata for an audio source.
struct AudioSourceMeta: Codable, Sendable {
    let name: String
    let year: Int?
    let version: Int?
    /// Relative directory for media files within the ZIP (for local sources).
    let mediaDir: String?
    /// Absolute URL base for media files (for online sources). If present, this is an online source.
    let mediaDirAbs: String?

    enum CodingKeys: String, CodingKey {
        case name
        case year
        case version
        case mediaDir = "media_dir"
        case mediaDirAbs = "media_dir_abs"
    }
}

/// Information about a single audio file.
struct AudioFileInfo: Codable, Sendable {
    /// The kana reading for this audio file.
    let kanaReading: String
    /// Optional pitch pattern visualization (e.g., "わたし━").
    let pitchPattern: String?
    /// Optional pitch accent number (e.g., "0" for heiban).
    let pitchNumber: String?

    enum CodingKeys: String, CodingKey {
        case kanaReading = "kana_reading"
        case pitchPattern = "pitch_pattern"
        case pitchNumber = "pitch_number"
    }
}
