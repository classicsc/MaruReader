//
//  TextLookupRequest.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

struct TextLookupRequest: Identifiable {
    let id: UUID
    let offset: Int // Offset of tapped character within context
    let context: String // Surrounding text
    let rubyContext: RubyText? // Ruby-aware representation
}
