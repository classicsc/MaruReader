// BookLibraryModelTests.swift
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
@testable import MaruReader
import Testing

struct BookLibraryModelTests {
    @Test func firstPageRespectsPredicateAndSort() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        for index in 0 ..< 60 {
            _ = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index)),
                pendingDeletion: index == 59
            )
        }

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Book 58")
        #expect(snapshots.contains { $0.title == "Book 59" } == false)
    }

    @Test func loadNextPageAppendsWithoutDuplicates() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_700_100_000)

        for index in 0 ..< 60 {
            _ = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)
        await model.loadNextPage()

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 60)
        #expect(Set(snapshots.map(\.objectID)).count == 60)
    }

    @Test func sortChangeResetsPaginationAndOrder() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_700_200_000)

        for index in 0 ..< 60 {
            _ = try await insertBook(
                into: viewContext,
                title: String(format: "%02d", 59 - index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)
        await model.loadNextPage()
        await MainActor.run {
            model.sortOption = .title
        }
        await model.reloadForCurrentSort()

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "00")
    }

    @Test func titlePaginationIsDeterministicWhenSortKeysTie() async throws {
        let ids = stableUUIDs(count: 60)
        let baseDate = Date(timeIntervalSince1970: 1_700_250_000)
        let seeds = ids.enumerated().map { index, id in
            BookPaginationSeed(
                id: id,
                title: index < 30 ? "Alpha" : "Beta",
                author: index.isMultiple(of: 3) ? "Author A" : "Author B",
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        try await assertDeterministicPagination(for: .title, seeds: seeds)
    }

    @Test func authorPaginationIsDeterministicWhenSortKeysTie() async throws {
        let ids = stableUUIDs(count: 60)
        let baseDate = Date(timeIntervalSince1970: 1_700_260_000)
        let seeds = ids.enumerated().map { index, id in
            BookPaginationSeed(
                id: id,
                title: index.isMultiple(of: 3) ? "Series A" : "Series B",
                author: index < 30 ? "Author A" : "Author B",
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        try await assertDeterministicPagination(for: .author, seeds: seeds)
    }

    @Test func dateAddedPaginationIsDeterministicWhenSortKeysTie() async throws {
        let ids = stableUUIDs(count: 60)
        let baseDate = Date(timeIntervalSince1970: 1_700_270_000)
        let seeds = ids.enumerated().map { index, id in
            BookPaginationSeed(
                id: id,
                title: "Shared Title",
                author: "Shared Author",
                added: baseDate.addingTimeInterval(TimeInterval(index / 15))
            )
        }

        try await assertDeterministicPagination(for: .dateAdded, seeds: seeds)
    }

    @Test func nonQueryUpdatePatchesLoadedSnapshot() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let bookID = try await insertBook(
            into: viewContext,
            title: "Patch Target",
            originalFileName: nil,
            added: Date(),
            progressPercent: nil,
            isComplete: true
        )

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await viewContext.perform {
            let book = try #require(viewContext.existingObject(with: bookID) as? Book)
            book.progressPercent = "50"
            try viewContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.progressPercent == "50"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.progressPercent == "50")
    }

    @Test func backgroundContextUpdatePatchesLoadedSnapshot() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let insertContext = persistence.newBackgroundContext()
        let updateContext = persistence.newBackgroundContext()
        let bookID = try await insertBook(
            into: insertContext,
            title: "Background Patch",
            originalFileName: nil,
            added: Date(),
            progressPercent: nil,
            isComplete: false
        )

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let book = try #require(updateContext.existingObject(with: bookID) as? Book)
            book.isComplete = true
            book.progressPercent = "100"
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.status == .complete
                && currentSnapshots.first?.progressPercent == "100"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.status == .complete)
        #expect(snapshots.first?.progressPercent == "100")
    }

    @Test func backgroundVisibleQueryUpdateReloadsLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let updateContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_700_300_000)

        var firstLoadedID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 59 {
                firstLoadedID = objectID
            }
        }
        let hiddenObjectID = try #require(firstLoadedID)

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let book = try #require(updateContext.existingObject(with: hiddenObjectID) as? Book)
            book.pendingDeletion = true
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Book 58"
                && currentSnapshots.contains { $0.objectID == hiddenObjectID } == false
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Book 58")
        #expect(snapshots.contains { $0.objectID == hiddenObjectID } == false)
    }

    @Test func backgroundOffscreenQueryUpdateReloadsLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let updateContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_700_310_000)

        var offscreenID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 0 {
                offscreenID = objectID
            }
        }
        let promotedObjectID = try #require(offscreenID)

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let book = try #require(updateContext.existingObject(with: promotedObjectID) as? Book)
            book.added = baseDate.addingTimeInterval(1000)
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.objectID == promotedObjectID
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.objectID == promotedObjectID)
        #expect(snapshots.first?.title == "Book 00")
    }

    @Test func backgroundInsertInvalidatesLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let insertContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_700_320_000)

        for index in 0 ..< 60 {
            _ = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        _ = try await insertBook(
            into: insertContext,
            title: "Newest Book",
            originalFileName: nil,
            added: baseDate.addingTimeInterval(1000)
        )

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Newest Book"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Newest Book")
    }

    @Test func backgroundDeleteInvalidatesLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let deleteContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_700_330_000)

        var firstLoadedID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 59 {
                firstLoadedID = objectID
            }
        }
        let deletedObjectID = try #require(firstLoadedID)

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await deleteContext.perform {
            let book = try #require(deleteContext.existingObject(with: deletedObjectID) as? Book)
            deleteContext.delete(book)
            try deleteContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Book 58"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Book 58")
        #expect(snapshots.contains { $0.objectID == deletedObjectID } == false)
    }

    @Test func insertInvalidatesLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_700_300_000)

        for index in 0 ..< 60 {
            _ = try await insertBook(
                into: viewContext,
                title: String(format: "Book %02d", index),
                originalFileName: nil,
                added: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            BookLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        _ = try await insertBook(
            into: viewContext,
            title: "Newest Book",
            originalFileName: nil,
            added: baseDate.addingTimeInterval(1000)
        )

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Newest Book"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Newest Book")
    }

    @Test func snapshotMappingMatchesLegacyDisplayRules() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let bookID = try await insertBook(
            into: viewContext,
            title: nil,
            originalFileName: "Original.epub",
            added: Date(),
            progressPercent: "33",
            displayProgressMessage: "Queued..."
        )

        let snapshot = try await viewContext.perform {
            let book = try #require(viewContext.existingObject(with: bookID) as? Book)
            return BookLibrarySnapshot(book: book)
        }

        #expect(snapshot.title == "Original.epub")
        #expect(snapshot.author == nil)
        #expect(snapshot.progressPercent == "33")
        #expect(snapshot.status == .inProgress)
        #expect(snapshot.statusMessage == "Queued...")
    }

    private func insertBook(
        into viewContext: NSManagedObjectContext,
        id: UUID = UUID(),
        title: String?,
        originalFileName: String?,
        added: Date,
        author: String? = nil,
        progressPercent: String? = nil,
        displayProgressMessage: String? = nil,
        pendingDeletion: Bool = false,
        isComplete: Bool = false
    ) async throws -> NSManagedObjectID {
        try await viewContext.perform {
            let book = Book(context: viewContext)
            book.id = id
            book.title = title
            book.originalFileName = originalFileName
            book.author = author
            book.added = added
            book.pendingDeletion = pendingDeletion
            book.progressPercent = progressPercent
            book.displayProgressMessage = displayProgressMessage
            book.isComplete = isComplete
            try viewContext.save()
            return book.objectID
        }
    }

    private func currentSnapshots(of model: BookLibraryModel) async -> [BookLibrarySnapshot] {
        await MainActor.run {
            model.snapshots
        }
    }

    private func waitUntil(
        attempts: Int = 100,
        interval: Duration = .milliseconds(20),
        condition: @escaping () async -> Bool
    ) async {
        for _ in 0 ..< attempts {
            if await condition() {
                return
            }
            try? await Task.sleep(for: interval)
        }

        Issue.record("Timed out waiting for condition")
    }

    private func assertDeterministicPagination(
        for sortOption: BookSortOption,
        seeds: [BookPaginationSeed]
    ) async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext

        for seed in seeds.reversed() {
            _ = try await insertBook(
                into: viewContext,
                id: seed.id,
                title: seed.title,
                originalFileName: nil,
                added: seed.added,
                author: seed.author
            )
        }

        let model = await MainActor.run {
            let model = BookLibraryModel(debounceDuration: .milliseconds(5))
            model.sortOption = sortOption
            return model
        }
        await model.configureIfNeeded(viewContext: viewContext)
        await model.loadNextPage()

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == seeds.count)
        #expect(Set(snapshots.map(\.objectID)).count == seeds.count)

        let actualIDs = try await bookIDs(for: snapshots, in: viewContext)
        let expectedIDs = sortedSeeds(seeds, for: sortOption).map(\.id)
        #expect(actualIDs == expectedIDs)
    }

    private func bookIDs(
        for snapshots: [BookLibrarySnapshot],
        in viewContext: NSManagedObjectContext
    ) async throws -> [UUID] {
        try await viewContext.perform {
            try snapshots.map { snapshot in
                let book = try #require(viewContext.existingObject(with: snapshot.objectID) as? Book)
                return try #require(book.id)
            }
        }
    }

    private func sortedSeeds(
        _ seeds: [BookPaginationSeed],
        for sortOption: BookSortOption
    ) -> [BookPaginationSeed] {
        seeds.sorted { lhs, rhs in
            switch sortOption {
            case .title:
                if lhs.title != rhs.title {
                    return lhs.title < rhs.title
                }
                if lhs.author != rhs.author {
                    return lhs.author < rhs.author
                }
            case .author:
                if lhs.author != rhs.author {
                    return lhs.author < rhs.author
                }
                if lhs.title != rhs.title {
                    return lhs.title < rhs.title
                }
            case .dateAdded:
                if lhs.added != rhs.added {
                    return lhs.added > rhs.added
                }
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func stableUUIDs(count: Int) -> [UUID] {
        (0 ..< count).map { index in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
        }
    }
}

private struct BookPaginationSeed {
    let id: UUID
    let title: String
    let author: String
    let added: Date
}
