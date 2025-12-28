//
//  AnkiNoteService.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/28/25.
//

import CoreData
import Foundation
import os.log

/// Service for managing persisted Anki notes and checking note existence.
public actor AnkiNoteService {
    private let persistence: AnkiPersistenceController
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AnkiNoteService")

    public init(persistence: AnkiPersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Note Existence Checking

    /// Check if a note exists for the given expression, reading, and profile.
    public func noteExists(expression: String, reading: String?, profileName: String) async -> Bool {
        let context = persistence.newBackgroundContext()
        return await context.perform {
            let request = NSFetchRequest<AnkiNote>(entityName: "AnkiNote")
            request.predicate = Self.buildNotePredicate(
                expression: expression,
                reading: reading,
                profileName: profileName
            )
            request.fetchLimit = 1

            do {
                let count = try context.count(for: request)
                return count > 0
            } catch {
                self.logger.error("Failed to check note existence: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Get term keys (expression|reading) for notes that already exist for the given profile.
    /// This is useful for batch checking when rendering dictionary results.
    public func getExistingNoteTermKeys(
        for terms: [(expression: String, reading: String?)],
        profileName: String
    ) async -> Set<String> {
        guard !terms.isEmpty else { return [] }

        let context = persistence.newBackgroundContext()
        return await context.perform {
            // Build compound predicate for all terms
            var predicates: [NSPredicate] = []
            for (expression, reading) in terms {
                let termPredicate = Self.buildNotePredicate(
                    expression: expression,
                    reading: reading,
                    profileName: profileName
                )
                predicates.append(termPredicate)
            }

            let request = NSFetchRequest<AnkiNote>(entityName: "AnkiNote")
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            request.propertiesToFetch = ["expression", "reading"]

            do {
                let results = try context.fetch(request)
                return Set(results.map { Self.termKey(expression: $0.expression ?? "", reading: $0.reading) })
            } catch {
                self.logger.error("Failed to fetch existing notes: \(error.localizedDescription)")
                return []
            }
        }
    }

    // MARK: - Note Recording

    /// Record a newly created Anki note in local storage.
    @discardableResult
    public func recordNote(
        expression: String,
        reading: String?,
        profileName: String,
        deckName: String,
        modelName: String,
        fields: [String: String],
        tags: [String] = [],
        ankiID: Int64?
    ) async throws -> UUID {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let note = AnkiNote(context: context)
            note.id = UUID()
            note.expression = expression
            note.reading = reading
            note.profileName = profileName
            note.deckName = deckName
            note.modelName = modelName
            note.createdAt = Date()
            note.pendingSync = false

            // Serialize fields to JSON
            let fieldsJSON = try JSONEncoder().encode(fields)
            note.fields = String(data: fieldsJSON, encoding: .utf8) ?? "{}"

            // Serialize tags to JSON
            let tagsJSON = try JSONEncoder().encode(tags)
            note.tags = String(data: tagsJSON, encoding: .utf8) ?? "[]"

            // Store Anki's note ID if we got one
            if let ankiID {
                note.ankiID = String(ankiID)
            }

            try context.save()
            self.logger.debug("Recorded note for '\(expression)' with ID \(note.id?.uuidString ?? "nil")")

            return note.id!
        }
    }

    // MARK: - Note Deletion

    /// Delete a note record by its local UUID.
    public func deleteNote(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<AnkiNote>(entityName: "AnkiNote")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let note = try context.fetch(request).first {
                context.delete(note)
                try context.save()
            }
        }
    }

    /// Delete note records matching expression, reading, and profile.
    public func deleteNotes(expression: String, reading: String?, profileName: String) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<AnkiNote>(entityName: "AnkiNote")
            request.predicate = Self.buildNotePredicate(
                expression: expression,
                reading: reading,
                profileName: profileName
            )

            let notes = try context.fetch(request)
            for note in notes {
                context.delete(note)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Private Helpers

    private static func buildNotePredicate(
        expression: String,
        reading: String?,
        profileName: String
    ) -> NSPredicate {
        if let reading, !reading.isEmpty {
            NSPredicate(
                format: "expression == %@ AND reading == %@ AND profileName == %@",
                expression, reading, profileName
            )
        } else {
            NSPredicate(
                format: "expression == %@ AND (reading == nil OR reading == %@) AND profileName == %@",
                expression, "", profileName
            )
        }
    }

    /// Build term key matching the format used in GroupedSearchResults.
    public static func termKey(expression: String, reading: String?) -> String {
        "\(expression)|\(reading ?? "")"
    }
}
