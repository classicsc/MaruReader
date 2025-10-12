//
//  Tag.swift
//  MaruReader
//
//  Dictionary tag representation for term and definition tags.
//

import CoreData
import Foundation

/// Represents a dictionary tag with metadata
struct Tag: Codable, Sendable, Identifiable, Hashable {
    let name: String
    let category: String
    let notes: String
    let order: Double
    let score: Double

    var id: String { name }

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
        let escapedName = escapeHTML(name)
        let escapedNotes = notes.isEmpty ? "" : " title=\"\(escapeHTML(notes))\""
        return "<span class=\"tag \(typeClass)\"\(escapedNotes)>\(escapedName)</span>"
    }
}

extension Tag {
    enum TagType {
        case term
        case definition
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
