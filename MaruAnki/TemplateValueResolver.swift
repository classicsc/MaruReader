// TemplateValueResolver.swift
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

/// The result of resolving a template value.
public struct TemplateResolvedValue: Sendable {
    /// Text content of the resolved value, or nil if not available.
    public let text: String?

    /// Media files associated with this value.
    /// Key is a unique file identifier, value is the file URL (local or remote).
    /// The API layer handles formatting these for specific APIs (AnkiConnect, AnkiMobile).
    public let mediaFiles: [String: URL]

    public init(text: String? = nil, mediaFiles: [String: URL] = [:]) {
        self.text = text
        self.mediaFiles = mediaFiles
    }

    /// Convenience initializer for text-only values.
    public static func text(_ value: String?) -> TemplateResolvedValue {
        TemplateResolvedValue(text: value)
    }

    /// Convenience initializer for media-only values.
    public static func media(_ files: [String: URL]) -> TemplateResolvedValue {
        TemplateResolvedValue(mediaFiles: files)
    }

    /// An empty resolved value (no text, no media).
    public static var empty: TemplateResolvedValue {
        TemplateResolvedValue()
    }
}

/// Protocol for types that can resolve template values to concrete values.
///
/// Implementations provide the mapping from `TemplateValue` cases to actual
/// content that can be used to populate Anki note fields.
public protocol TemplateValueResolver: Sendable {
    /// Resolves a template value to its concrete representation.
    ///
    /// - Parameter templateValue: The template value to resolve.
    /// - Returns: The resolved value containing text and/or media files.
    func resolve(_ templateValue: TemplateValue) async -> TemplateResolvedValue
}
