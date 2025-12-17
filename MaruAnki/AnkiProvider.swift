//
//  AnkiProvider.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/17/25.

/// The interface for Anki note creation.
protocol AnkiProvider {
    /// Mapping of note field names to their resolved values. Each field is constructed by concatenating the resolved values together.
    /// Types that implement this protocol may handle or ignore media values according to API constraints.
    func addNote(fields: [String: [TemplateResolvedValue]],
                 profileName: String,
                 deckName: String,
                 modelName: String,
                 duplicateOptions: DuplicateDetectionOptions) async throws
}

struct DuplicateDetectionOptions: Sendable, Codable {
    /// The scope for duplicate checking. `none` to disable duplicate checking.
    let scope: DuplicateNoteScope
    /// The deck to check for duplicates in, if `scope` is `.deck`. `nil` to check in the target deck.
    let deckName: String?
    /// Whether to check in child decks when `scope` is `.deck`.
    let includeChildDecks: Bool
    /// Whether to check across all note types.
    /// If `false`, only notes of the same type as the note being added are checked.
    let checkAllModels: Bool
}

enum DuplicateNoteScope: Sendable, Codable {
    case deck
    case collection
    case none
}
