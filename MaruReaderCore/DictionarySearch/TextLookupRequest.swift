//
//  TextLookupRequest.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

public struct TextLookupRequest: Identifiable {
    public let id: UUID
    let offset: Int // Offset of tapped character within context
    let context: String // Surrounding text
    let contextStartOffset: Int // Where context starts in the full element text
    let rubyContext: RubyText? // Context including ruby annotations if available
    let cssSelector: String? // CSS selector if applicable

    public init(context: String, offset: Int = 0, contextStartOffset: Int = 0, rubyContext: RubyText? = nil, cssSelector: String? = nil) {
        self.id = UUID()
        self.offset = offset
        self.context = context
        self.contextStartOffset = contextStartOffset
        self.rubyContext = rubyContext
        self.cssSelector = cssSelector
    }
}
