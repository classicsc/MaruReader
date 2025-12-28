//
//  AnkiProvider.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/17/25.

/// The interface for Anki note creation.
protocol AnkiProvider: Sendable {
    /// Mapping of note field names to their resolved values. Each field is constructed by concatenating the resolved values together.
    /// Types that implement this protocol may handle or ignore media values according to API constraints.
    func addNote(fields: [String: [TemplateResolvedValue]],
                 profileName: String,
                 deckName: String,
                 modelName: String,
                 duplicateOptions: DuplicateDetectionOptions) async throws
    func getAnkiProfiles() async -> AnkiProfileListingResponse
    func getAnkiDecks(forProfile profileName: String) async -> AnkiDeckListingResponse
    func getAnkiModels(forProfile profileName: String) async -> AnkiModelListingResponse
}

public struct DuplicateDetectionOptions: Sendable, Codable {
    /// The scope for duplicate checking. `none` to disable duplicate checking.
    public let scope: DuplicateNoteScope
    /// The deck to check for duplicates in, if `scope` is `.deck`. `nil` to check in the target deck.
    public let deckName: String?
    /// Whether to check in child decks when `scope` is `.deck`.
    public let includeChildDecks: Bool
    /// Whether to check across all note types.
    /// If `false`, only notes of the same type as the note being added are checked.
    public let checkAllModels: Bool

    public init(scope: DuplicateNoteScope, deckName: String?, includeChildDecks: Bool, checkAllModels: Bool) {
        self.scope = scope
        self.deckName = deckName
        self.includeChildDecks = includeChildDecks
        self.checkAllModels = checkAllModels
    }
}

public enum DuplicateNoteScope: Sendable, Codable {
    case deck
    case collection
    case none
}

public struct AnkiDeckMeta: Sendable {
    public let id: String
    public let name: String
    public let profileName: String
}

public struct AnkiModelMeta: Sendable {
    public let id: String
    public let name: String
    public let profileName: String
    public let fields: [String]
}

public struct AnkiProfileMeta: Sendable {
    public let id: String
    public let isActiveProfile: Bool
}

enum AnkiProfileListingResponse {
    case success([AnkiProfileMeta])
    case failure(Error)
    case apiCapabilityMissing
}

enum AnkiDeckListingResponse {
    case success([AnkiDeckMeta])
    case failure(Error)
    case apiCapabilityMissing
}

enum AnkiModelListingResponse {
    case success([AnkiModelMeta])
    case failure(Error)
    case apiCapabilityMissing
}
