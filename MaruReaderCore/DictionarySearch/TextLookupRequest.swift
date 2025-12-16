//
//  TextLookupRequest.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

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

    public init(
        documentTitle: String? = nil,
        documentURL: URL? = nil,
        documentCoverImageURL: URL? = nil,
        screenshotURL: URL? = nil
    ) {
        self.documentTitle = documentTitle
        self.documentURL = documentURL
        self.documentCoverImageURL = documentCoverImageURL
        self.screenshotURL = screenshotURL
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
