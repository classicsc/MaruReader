// SystemProfileManager.swift
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

import CoreData
import Foundation

public enum SystemProfileManager {
    /// The UUID for the "Basic" system profile.
    public static let basicProfileUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Ensures all system profiles exist in the given context.
    /// This is idempotent - calling multiple times is safe.
    public static func ensureSystemProfilesExist(in context: NSManagedObjectContext) async {
        await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "id == %@", basicProfileUUID as CVarArg)
            request.fetchLimit = 1

            do {
                let existing = try context.fetch(request)
                if existing.isEmpty {
                    createBasicProfile(in: context)
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("Failed to ensure system profiles: \(error)")
            }
        }
    }

    private static func createBasicProfile(in context: NSManagedObjectContext) {
        let profile = MaruModelSettings(context: context)
        profile.id = basicProfileUUID
        profile.displayName = "Basic"
        profile.isSystemProfile = true

        let fieldMap = AnkiFieldMap(map: [
            "Front": [.expression],
            "Back": [.multiDictionaryGlossary],
        ])

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(fieldMap)
            profile.fieldMap = String(data: data, encoding: .utf8)
        } catch {
            print("Failed to encode field map for Basic profile: \(error)")
        }
    }

    /// Fetches all available field mapping profiles.
    public static func fetchAllProfiles(in context: NSManagedObjectContext) async -> [MaruModelSettings] {
        await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isSystemProfile", ascending: false),
                NSSortDescriptor(key: "displayName", ascending: true),
            ]

            return (try? context.fetch(request)) ?? []
        }
    }

    /// Creates or updates a configured profile from a template.
    /// - Parameters:
    ///   - templateID: The template identifier (e.g., "lapis")
    ///   - fieldMap: The complete field map with user configuration applied
    ///   - configuration: The user's configuration choices for storage/re-editing
    ///   - context: The managed object context to use
    /// - Returns: The UUID of the created/updated profile
    public static func saveConfiguredProfile(
        templateID: String,
        fieldMap: AnkiFieldMap,
        configuration: ConfiguredProfileData,
        in context: NSManagedObjectContext
    ) async throws -> UUID {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        try await context.perform {
            // Find existing or create new
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "sourceTemplateID == %@", templateID)
            request.fetchLimit = 1

            let profile: MaruModelSettings
            if let existing = try context.fetch(request).first {
                profile = existing
            } else {
                profile = MaruModelSettings(context: context)
                profile.id = profileID
            }

            // Update profile
            let template = ConfigurableProfileTemplates.template(for: templateID)
            profile.displayName = template?.displayName ?? templateID
            profile.isSystemProfile = false
            profile.isHidden = true
            profile.sourceTemplateID = templateID

            // Store field map
            let encoder = JSONEncoder()
            let fieldMapData = try encoder.encode(fieldMap)
            profile.fieldMap = String(data: fieldMapData, encoding: .utf8)

            // Store configuration for re-editing
            let configData = try encoder.encode(configuration)
            profile.templateConfiguration = String(data: configData, encoding: .utf8)

            try context.save()
        }

        return profileID
    }

    /// Retrieves the configuration data for a template-based profile.
    /// - Parameters:
    ///   - templateID: The template identifier to look up
    ///   - context: The managed object context to use
    /// - Returns: The configuration data, or nil if no configured profile exists
    public static func getConfiguredProfileData(
        for templateID: String,
        in context: NSManagedObjectContext
    ) async -> ConfiguredProfileData? {
        await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "sourceTemplateID == %@", templateID)
            request.fetchLimit = 1

            guard let profile = try? context.fetch(request).first,
                  let configString = profile.templateConfiguration,
                  let data = configString.data(using: .utf8)
            else {
                return nil
            }

            return try? JSONDecoder().decode(ConfiguredProfileData.self, from: data)
        }
    }

    /// Checks if a template has been configured.
    /// - Parameters:
    ///   - templateID: The template identifier to check
    ///   - context: The managed object context to use
    /// - Returns: True if the template has a configured profile
    public static func isTemplateConfigured(
        _ templateID: String,
        in context: NSManagedObjectContext
    ) async -> Bool {
        await context.perform {
            let request = NSFetchRequest<MaruModelSettings>(entityName: "MaruModelSettings")
            request.predicate = NSPredicate(format: "sourceTemplateID == %@", templateID)
            request.fetchLimit = 1

            return (try? context.count(for: request)) ?? 0 > 0
        }
    }
}
