// LibraryObservationSupport.swift
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

public struct LibraryQueryState: Equatable, Sendable {
    public let title: String?
    public let author: String?
    public let sortDate: Date?
    public let pendingDeletion: Bool

    public init(
        title: String?,
        author: String?,
        sortDate: Date?,
        pendingDeletion: Bool
    ) {
        self.title = title
        self.author = author
        self.sortDate = sortDate
        self.pendingDeletion = pendingDeletion
    }
}

public struct CoreDataObjectIDChangeSet: Sendable {
    public let insertedObjectIDs: Set<NSManagedObjectID>
    public let updatedObjectIDs: Set<NSManagedObjectID>
    public let deletedObjectIDs: Set<NSManagedObjectID>
    public let refreshedObjectIDs: Set<NSManagedObjectID>
    public let invalidatedObjectIDs: Set<NSManagedObjectID>
    public let invalidatedAllObjects: Bool

    public init(notification: Notification) {
        insertedObjectIDs = CoreDataNotificationObjectIDs.objectIDs(forKey: NSInsertedObjectIDsKey, in: notification)
        updatedObjectIDs = CoreDataNotificationObjectIDs.objectIDs(forKey: NSUpdatedObjectIDsKey, in: notification)
        deletedObjectIDs = CoreDataNotificationObjectIDs.objectIDs(forKey: NSDeletedObjectIDsKey, in: notification)
        refreshedObjectIDs = CoreDataNotificationObjectIDs.objectIDs(forKey: NSRefreshedObjectIDsKey, in: notification)
        invalidatedObjectIDs = CoreDataNotificationObjectIDs.objectIDs(forKey: NSInvalidatedObjectIDsKey, in: notification)
        invalidatedAllObjects = notification.userInfo?[NSInvalidatedAllObjectsKey] != nil
    }

    public var changedObjectIDs: Set<NSManagedObjectID> {
        updatedObjectIDs
            .union(refreshedObjectIDs)
            .union(invalidatedObjectIDs)
    }
}

public enum CoreDataNotificationObjectIDs {
    public static func objectIDs(forKey key: String, in notification: Notification) -> Set<NSManagedObjectID> {
        if let rawIDs = notification.userInfo?[key] as? Set<NSManagedObjectID> {
            return rawIDs
        }

        if let rawObjects = notification.userInfo?[key] as? Set<NSManagedObject> {
            return Set(rawObjects.map(\.objectID))
        }

        return []
    }
}
