// TextLookupResponse.swift
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

public struct TextLookupResponse: Sendable {
    public let request: TextLookupRequest
    public let results: [GroupedSearchResults] // Dictionary content
    public let primaryResult: String // The matched term
    public let primaryResultSourceRange: Range<String.Index> // Range in context
    public let styles: DisplayStyles

    /// User-edited context. When set, this overrides the original request.context.
    public var editedContext: String?

    /// User-edited highlight range. When set, this overrides the original primaryResultSourceRange.
    public var editedPrimaryResultSourceRange: Range<String.Index>?

    /// The original request ID (for backward compatibility).
    public var requestID: UUID {
        request.id
    }

    /// Where context starts in full element text (convenience accessor).
    public var contextStartOffset: Int {
        request.contextStartOffset
    }

    /// The original context string (convenience accessor).
    public var context: String {
        request.context
    }

    /// The effective context for display and Anki note creation (edited or original).
    public var effectiveContext: String {
        editedContext ?? request.context
    }

    /// The effective highlight range for display (edited or original).
    /// Returns nil only when context was edited but the term is no longer found.
    public var effectivePrimaryResultSourceRange: Range<String.Index>? {
        if editedContext != nil {
            // When context is edited, only use the edited range (may be nil if term not found)
            return editedPrimaryResultSourceRange
        }
        return primaryResultSourceRange
    }

    /// Attempts to locate the primary result in the edited context and update the edited range.
    /// When the term appears multiple times, prefers the occurrence at a similar proportional position.
    /// - Parameter newContext: The new edited context string.
    /// - Returns: `true` if the term was found in the new context, `false` otherwise.
    public mutating func updateEditedRange(for newContext: String) -> Bool {
        editedContext = newContext

        guard let firstRange = newContext.range(of: primaryResult) else {
            editedPrimaryResultSourceRange = nil
            return false
        }

        // Find all occurrences
        var allRanges: [Range<String.Index>] = []
        var searchStart = newContext.startIndex
        while let range = newContext.range(of: primaryResult, range: searchStart ..< newContext.endIndex) {
            allRanges.append(range)
            searchStart = range.upperBound
        }

        if allRanges.count == 1 {
            editedPrimaryResultSourceRange = firstRange
            return true
        }

        // Multiple occurrences: pick closest to original proportional position
        let originalContext = request.context
        let originalStart = originalContext.distance(
            from: originalContext.startIndex,
            to: primaryResultSourceRange.lowerBound
        )
        let originalProportion = Double(originalStart) / Double(max(1, originalContext.count))
        let targetPosition = Int(originalProportion * Double(newContext.count))

        var bestRange = firstRange
        var bestDistance = Int.max
        for range in allRanges {
            let position = newContext.distance(from: newContext.startIndex, to: range.lowerBound)
            let distance = abs(position - targetPosition)
            if distance < bestDistance {
                bestDistance = distance
                bestRange = range
            }
        }

        editedPrimaryResultSourceRange = bestRange
        return true
    }

    /// Start offset of the matched text within the context (UTF-16 code units for JS compatibility)
    public var matchStartInContext: Int {
        guard let utf16Lower = primaryResultSourceRange.lowerBound.samePosition(in: context.utf16) else {
            return 0
        }
        return context.utf16.distance(from: context.utf16.startIndex, to: utf16Lower)
    }

    /// End offset of the matched text within the context (UTF-16 code units for JS compatibility)
    public var matchEndInContext: Int {
        guard let utf16Upper = primaryResultSourceRange.upperBound.samePosition(in: context.utf16) else {
            return 0
        }
        return context.utf16.distance(from: context.utf16.startIndex, to: utf16Upper)
    }

    /// Start offset of match in effective context (UTF-16 for JS compatibility)
    public var effectiveMatchStartInContext: Int? {
        guard let range = effectivePrimaryResultSourceRange else { return nil }
        let ctx = effectiveContext
        guard let utf16Lower = range.lowerBound.samePosition(in: ctx.utf16) else { return nil }
        return ctx.utf16.distance(from: ctx.utf16.startIndex, to: utf16Lower)
    }

    /// End offset of match in effective context (UTF-16 for JS compatibility)
    public var effectiveMatchEndInContext: Int? {
        guard let range = effectivePrimaryResultSourceRange else { return nil }
        let ctx = effectiveContext
        guard let utf16Upper = range.upperBound.samePosition(in: ctx.utf16) else { return nil }
        return ctx.utf16.distance(from: ctx.utf16.startIndex, to: utf16Upper)
    }
}
