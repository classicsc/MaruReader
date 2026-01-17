// TextLookupRequest.swift
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

/// The source type where a dictionary lookup originated.
public enum ContextSourceType: String, Sendable, Codable, CaseIterable {
    /// Lookup from the ePub book reader
    case book
    /// Lookup from the manga/comic reader
    case manga
    /// Lookup from the web viewer
    case web
    /// Lookup from the dictionary search (standalone or nested lookups)
    case dictionary
}

/// Context values provided by the caller for template resolution.
///
/// These are values that come from the lookup scenario (reader, share extension, OCR, etc.)
/// rather than from dictionary search results. They are passed through to the response
/// and used when resolving template values for Anki note creation.
public struct LookupContextValues: Sendable {
    /// Title of the document being read (for reader context).
    public let documentTitle: String?

    /// URL of the document (for reader context).
    public let documentURL: URL?

    /// URL to the document's cover image.
    public let documentCoverImageURL: URL?

    /// URL to a screenshot taken at lookup time (for OCR or visual context).
    public let screenshotURL: URL?

    /// The source type where the lookup originated.
    public let sourceType: ContextSourceType

    public init(
        documentTitle: String? = nil,
        documentURL: URL? = nil,
        documentCoverImageURL: URL? = nil,
        screenshotURL: URL? = nil,
        sourceType: ContextSourceType = .dictionary
    ) {
        self.documentTitle = documentTitle
        self.documentURL = documentURL
        self.documentCoverImageURL = documentCoverImageURL
        self.screenshotURL = screenshotURL
        self.sourceType = sourceType
    }

    /// Creates a copy of this context values with a different source type.
    ///
    /// This is useful when transitioning from one lookup context to another,
    /// such as when tapping on a term within dictionary results.
    public func withSourceType(_ newType: ContextSourceType) -> LookupContextValues {
        LookupContextValues(
            documentTitle: self.documentTitle,
            documentURL: self.documentURL,
            documentCoverImageURL: self.documentCoverImageURL,
            screenshotURL: self.screenshotURL,
            sourceType: newType
        )
    }
}

public struct TextLookupRequest: Sendable, Identifiable {
    public let id: UUID
    public let offset: Int // Offset of tapped character within context
    public let context: String // Surrounding text
    public let contextStartOffset: Int // Where context starts in the full element text
    public let rubyContext: RubyText? // Context including ruby annotations if available
    public let cssSelector: String? // CSS selector if applicable
    public let contextValues: LookupContextValues? // Scenario-specific context for template resolution

    public init(
        context: String,
        offset: Int = 0,
        contextStartOffset: Int = 0,
        rubyContext: RubyText? = nil,
        cssSelector: String? = nil,
        contextValues: LookupContextValues? = nil
    ) {
        self.id = UUID()
        self.offset = offset
        self.context = context
        self.contextStartOffset = contextStartOffset
        self.rubyContext = rubyContext
        self.cssSelector = cssSelector
        self.contextValues = contextValues
    }
}
