// TermAudioResults.swift
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

/// Audio results for a specific term+reading pair
public struct TermAudioResults: Sendable {
    /// The term (expression) this audio is for
    public let expression: String

    /// The reading this audio is for
    public let reading: String?

    /// All available audio sources for this term+reading
    public let sources: [AudioSourceResult]

    /// Whether any audio is available
    public var hasAudio: Bool { !sources.isEmpty }

    /// Primary audio URL (first available source)
    public var primaryAudioURL: URL? { sources.first?.url }

    /// Get audio sources matching a specific downstep position
    /// - Parameters:
    ///   - position: The downstep position string (e.g., "0", "1", "2-1")
    ///   - requireExactMatch: If true, returns empty array when no sources match the pitch.
    ///                        If false (default), falls back to all sources when none match.
    /// - Returns: Audio sources with matching pitch, or all sources if none match (unless requireExactMatch is true)
    public func sources(forPitchPosition position: String?, requireExactMatch: Bool = false) -> [AudioSourceResult] {
        guard let position else {
            return requireExactMatch ? [] : sources
        }

        let matching = sources.filter { $0.pitchNumber == position }

        if requireExactMatch {
            return matching
        }

        return matching.isEmpty ? sources : matching
    }

    /// Get the best audio URL for a specific pitch position
    /// - Parameters:
    ///   - position: The downstep position string
    ///   - requireExactMatch: If true, returns nil when no sources match the pitch exactly
    /// - Returns: URL of the first matching source, or first available if no match and requireExactMatch is false
    public func primaryURL(forPitchPosition position: String?, requireExactMatch: Bool = false) -> URL? {
        sources(forPitchPosition: position, requireExactMatch: requireExactMatch).first?.url
    }

    public init(expression: String, reading: String?, sources: [AudioSourceResult]) {
        self.expression = expression
        self.reading = reading
        self.sources = sources
    }
}
