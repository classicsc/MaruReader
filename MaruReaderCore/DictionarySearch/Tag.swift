// Tag.swift
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

import CoreData
import Foundation

/// Represents a dictionary tag with metadata
public struct Tag: Codable, Sendable, Identifiable, Hashable {
    public let name: String
    public let category: String
    public let notes: String
    public let order: Double
    public let score: Double

    public var id: String {
        name
    }

    /// Initialize from Core Data DictionaryTagMeta entity
    init(from tagMeta: DictionaryTagMeta) {
        self.name = tagMeta.name ?? ""
        self.category = tagMeta.category ?? ""
        self.notes = tagMeta.notes ?? ""
        self.order = tagMeta.order
        self.score = tagMeta.score
    }

    /// Direct initializer for testing
    init(name: String, category: String = "", notes: String = "", order: Double = 0, score: Double = 0) {
        self.name = name
        self.category = category
        self.notes = notes
        self.order = order
        self.score = score
    }

    // MARK: - HTML Generation

    /// Generate HTML representation of this tag
    func toHTML(type: TagType = .term) -> String {
        let typeClass = type == .term ? "term-tag" : "definition-tag"
        let categoryClass = "tag-category-\(normalizedCategory.cssClassName)"
        let escapedName = escapeHTML(name)
        let escapedNotes = notes.isEmpty ? "" : " title=\"\(escapeHTML(notes))\""
        return "<span class=\"tag \(typeClass) \(categoryClass)\"\(escapedNotes)>\(escapedName)</span>"
    }
}

extension Tag {
    enum TagType {
        case term
        case definition
    }

    /// Known tag categories with corresponding CSS class names
    enum TagCategory: String {
        case name
        case expression
        case popular
        case frequent
        case archaism
        case dictionary
        case frequency
        case partOfSpeech
        case search
        case pronunciationDictionary = "pronunciation-dictionary"
        case unknown

        /// CSS class name for this category
        var cssClassName: String {
            switch self {
            case .pronunciationDictionary:
                "pronunciation-dictionary"
            case .unknown:
                "unknown"
            default:
                rawValue
            }
        }

        /// Initialize from a category string, defaulting to unknown
        init(from categoryString: String) {
            self = TagCategory(rawValue: categoryString) ?? .unknown
        }
    }

    /// Get the normalized category for CSS class generation
    var normalizedCategory: TagCategory {
        TagCategory(from: category)
    }
}

// MARK: - Array Extensions

extension [Tag] {
    /// Generate HTML for an array of tags
    func toHTML(type: Tag.TagType = .term) -> String {
        guard !isEmpty else { return "" }

        let tagsHTML = self
            .sorted { $0.order < $1.order }
            .map { $0.toHTML(type: type) }
            .joined()

        return "<span class=\"tag-list\">\(tagsHTML)</span>"
    }

    /// Merge and deduplicate tags from multiple arrays
    static func merge(_ tagArrays: [[Tag]]) -> [Tag] {
        var uniqueTags: [String: Tag] = [:]

        for tags in tagArrays {
            for tag in tags {
                // Use the first occurrence of each tag name
                if uniqueTags[tag.name] == nil {
                    uniqueTags[tag.name] = tag
                }
            }
        }

        return Array(uniqueTags.values).sorted { $0.order < $1.order }
    }
}
