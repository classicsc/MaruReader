// ContextImageConfiguration.swift
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
import MaruReaderCore

/// The preferred image type for the contextImage template value.
public enum ContextImagePreference: String, Sendable, Codable, CaseIterable {
    /// Prefer the document's cover image (e.g., book cover, manga cover)
    case cover
    /// Prefer a screenshot captured at lookup time
    case screenshot
}

/// Configuration for the contextImage template value.
///
/// This determines which image (cover or screenshot) is used for each source type
/// when resolving the `contextImage` template value.
public struct ContextImageConfiguration: Sendable, Codable, Equatable {
    /// Preferred image for book reader lookups. Default: cover
    public var bookPreference: ContextImagePreference

    /// Preferred image for manga reader lookups. Default: screenshot
    public var mangaPreference: ContextImagePreference

    public init(
        bookPreference: ContextImagePreference = .cover,
        mangaPreference: ContextImagePreference = .screenshot
    ) {
        self.bookPreference = bookPreference
        self.mangaPreference = mangaPreference
    }

    /// Returns the default configuration.
    public static var `default`: ContextImageConfiguration {
        ContextImageConfiguration()
    }

    /// Returns the preferred image type for a given source type.
    ///
    /// - Parameter sourceType: The source where the lookup originated.
    /// - Returns: The preferred image type, or `nil` if no image is available for this source type.
    public func preferredImage(for sourceType: ContextSourceType) -> ContextImagePreference? {
        switch sourceType {
        case .book:
            return bookPreference
        case .manga:
            return mangaPreference
        case .web:
            // Web lookups only have screenshots available
            return .screenshot
        case .dictionary:
            // Dictionary lookups have no images available
            return nil
        @unknown default:
            return nil
        }
    }
}
