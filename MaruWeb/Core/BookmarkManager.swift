// BookmarkManager.swift
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

struct WebBookmarkSnapshot: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let title: String
    let createdAt: Date
    let lastVisitedAt: Date?
    let sortOrder: Int64
    let favicon: Data?
}

actor WebBookmarkManager {
    static let shared = WebBookmarkManager()

    private let persistenceController: WebDataPersistenceController

    init(persistenceController: WebDataPersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    func addBookmark(url: URL, title: String?, favicon: Data? = nil) async throws -> WebBookmarkSnapshot {
        let context = persistenceController.newBackgroundContext()
        return try await context.perform {
            let now = Date()
            let bookmark = try self.fetchBookmark(url: url, in: context) ?? WebBookmark(context: context)

            if bookmark.id == nil {
                bookmark.id = UUID()
                bookmark.createdAt = now
                bookmark.sortOrder = try self.nextSortOrder(in: context)
            }

            bookmark.url = url.absoluteString
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bookmark.title = title
            } else if bookmark.title?.isEmpty != false {
                bookmark.title = url.host ?? url.absoluteString
            }
            bookmark.favicon = favicon ?? bookmark.favicon
            bookmark.lastVisitedAt = now

            try context.save()
            return try self.snapshot(from: bookmark)
        }
    }

    func toggleBookmark(url: URL, title: String?, favicon: Data? = nil) async throws -> Bool {
        let context = persistenceController.newBackgroundContext()
        return try await context.perform {
            if let existing = try self.fetchBookmark(url: url, in: context) {
                context.delete(existing)
                try context.save()
                return false
            }

            let now = Date()
            let bookmark = WebBookmark(context: context)
            bookmark.id = UUID()
            bookmark.createdAt = now
            bookmark.sortOrder = try self.nextSortOrder(in: context)
            bookmark.url = url.absoluteString
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bookmark.title = title
            } else {
                bookmark.title = url.host ?? url.absoluteString
            }
            bookmark.favicon = favicon
            bookmark.lastVisitedAt = now

            try context.save()
            return true
        }
    }

    func updateBookmarkMetadata(url: URL, title: String?, favicon: Data? = nil) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            guard let bookmark = try self.fetchBookmark(url: url, in: context) else { return }
            var needsSave = false
            bookmark.lastVisitedAt = Date()
            needsSave = true
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if bookmark.title != title {
                    bookmark.title = title
                    needsSave = true
                }
            }
            if let favicon, bookmark.favicon != favicon {
                bookmark.favicon = favicon
                needsSave = true
            }
            if needsSave {
                try context.save()
            }
        }
    }

    func removeBookmark(id: UUID) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<WebBookmark>(entityName: "WebBookmark")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let bookmark = try context.fetch(request).first {
                context.delete(bookmark)
                try context.save()
            }
        }
    }

    func removeBookmark(url: URL) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            if let bookmark = try self.fetchBookmark(url: url, in: context) {
                context.delete(bookmark)
                try context.save()
            }
        }
    }

    func fetchBookmarks() async throws -> [WebBookmarkSnapshot] {
        let context = persistenceController.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<WebBookmark>(entityName: "WebBookmark")
            request.sortDescriptors = [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: true),
            ]
            return try context.fetch(request).compactMap { try? self.snapshot(from: $0) }
        }
    }

    func isBookmarked(url: URL) async -> Bool {
        let context = persistenceController.newBackgroundContext()
        return await context.perform {
            (try? self.fetchBookmark(url: url, in: context)) != nil
        }
    }

    func updateSortOrder(idsInOrder: [UUID]) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<WebBookmark>(entityName: "WebBookmark")
            request.predicate = NSPredicate(format: "id IN %@", idsInOrder)
            let results = try context.fetch(request)
            let pairs: [(UUID, WebBookmark)] = results.compactMap { bookmark in
                guard let id = bookmark.id else { return nil }
                return (id, bookmark)
            }
            let lookup = Dictionary(uniqueKeysWithValues: pairs)

            for (index, id) in idsInOrder.enumerated() {
                lookup[id]?.sortOrder = Int64(index)
            }
            try context.save()
        }
    }

    private nonisolated func fetchBookmark(url: URL, in context: NSManagedObjectContext) throws -> WebBookmark? {
        let request = NSFetchRequest<WebBookmark>(entityName: "WebBookmark")
        request.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private nonisolated func nextSortOrder(in context: NSManagedObjectContext) throws -> Int64 {
        let request = NSFetchRequest<WebBookmark>(entityName: "WebBookmark")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: false)]
        request.fetchLimit = 1
        let maxSortOrder = try context.fetch(request).first?.sortOrder ?? 0
        return maxSortOrder + 1
    }

    private nonisolated func snapshot(from bookmark: WebBookmark) throws -> WebBookmarkSnapshot {
        guard let id = bookmark.id,
              let urlString = bookmark.url,
              let url = URL(string: urlString)
        else {
            throw NSError(domain: "MaruWeb.Bookmark", code: 1)
        }

        let title = (bookmark.title?.isEmpty == false) ? (bookmark.title ?? url.absoluteString) : (url.host ?? url.absoluteString)

        return WebBookmarkSnapshot(
            id: id,
            url: url,
            title: title,
            createdAt: bookmark.createdAt ?? Date(),
            lastVisitedAt: bookmark.lastVisitedAt,
            sortOrder: bookmark.sortOrder,
            favicon: bookmark.favicon
        )
    }
}
