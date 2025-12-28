//
//  SystemProfileManager.swift
//  MaruAnki
//
//  Manages system-defined field mapping profiles.
//

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
}
