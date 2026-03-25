// MangaLibraryModelTests.swift
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
@testable import MaruManga
import Testing

struct MangaLibraryModelTests {
    @Test func firstPageRespectsPredicateAndSort() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

        for index in 0..<60 {
            _ = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index)),
                pendingDeletion: index == 59
            )
        }

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Manga 58")
        #expect(snapshots.contains { $0.title == "Manga 59" } == false)
    }

    @Test func loadNextPageAppendsWithoutDuplicates() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_800_100_000)

        for index in 0..<60 {
            _ = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)
        await model.loadNextPage()

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 60)
        #expect(Set(snapshots.map(\.objectID)).count == 60)
    }

    @Test func sortChangeResetsPaginationAndOrder() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_800_200_000)

        for index in 0..<60 {
            _ = try await insertManga(
                into: viewContext,
                title: String(format: "%02d", 59 - index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
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
        let baseDate = Date(timeIntervalSince1970: 1_800_250_000)
        let seeds = ids.enumerated().map { index, id in
            MangaPaginationSeed(
                id: id,
                title: index < 30 ? "Alpha" : "Beta",
                author: index.isMultiple(of: 3) ? "Author A" : "Author B",
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        try await assertDeterministicPagination(for: .title, seeds: seeds)
    }

    @Test func authorPaginationIsDeterministicWhenSortKeysTie() async throws {
        let ids = stableUUIDs(count: 60)
        let baseDate = Date(timeIntervalSince1970: 1_800_260_000)
        let seeds = ids.enumerated().map { index, id in
            MangaPaginationSeed(
                id: id,
                title: index.isMultiple(of: 3) ? "Series A" : "Series B",
                author: index < 30 ? "Author A" : "Author B",
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        try await assertDeterministicPagination(for: .author, seeds: seeds)
    }

    @Test func dateAddedPaginationIsDeterministicWhenSortKeysTie() async throws {
        let ids = stableUUIDs(count: 60)
        let baseDate = Date(timeIntervalSince1970: 1_800_270_000)
        let seeds = ids.enumerated().map { index, id in
            MangaPaginationSeed(
                id: id,
                title: "Shared Title",
                author: "Shared Author",
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index / 15))
            )
        }

        try await assertDeterministicPagination(for: .dateAdded, seeds: seeds)
    }

    @Test func nonQueryUpdatePatchesLoadedSnapshot() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let mangaID = try await insertManga(
            into: viewContext,
            title: "Patch Target",
            dateAdded: Date(),
            totalPages: 100,
            lastReadPage: 0,
            importComplete: true
        )

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await viewContext.perform {
            let manga = try #require(viewContext.existingObject(with: mangaID) as? MangaArchive)
            manga.lastReadPage = 50
            try viewContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.progressText == "51 / 100 Read"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.progressText == "51 / 100 Read")
    }

    @Test func backgroundContextUpdatePatchesLoadedSnapshot() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let insertContext = persistence.newBackgroundContext()
        let updateContext = persistence.newBackgroundContext()
        let mangaID = try await insertManga(
            into: insertContext,
            title: "Background Patch",
            dateAdded: Date(),
            totalPages: 100,
            lastReadPage: 0,
            importComplete: false
        )

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let manga = try #require(updateContext.existingObject(with: mangaID) as? MangaArchive)
            manga.importComplete = true
            manga.lastReadPage = 99
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.status == .complete
                && currentSnapshots.first?.progressText == "100 / 100 Read"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.status == .complete)
        #expect(snapshots.first?.progressText == "100 / 100 Read")
    }

    @Test func backgroundVisibleQueryUpdateReloadsLoadedWindow() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let updateContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_800_300_000)

        var firstLoadedID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 59 {
                firstLoadedID = objectID
            }
        }
        let hiddenObjectID = try #require(firstLoadedID)

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let manga = try #require(updateContext.existingObject(with: hiddenObjectID) as? MangaArchive)
            manga.pendingDeletion = true
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Manga 58"
                && currentSnapshots.contains { $0.objectID == hiddenObjectID } == false
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Manga 58")
        #expect(snapshots.contains { $0.objectID == hiddenObjectID } == false)
    }

    @Test func backgroundOffscreenQueryUpdateReloadsLoadedWindow() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let updateContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_800_310_000)

        var offscreenID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 0 {
                offscreenID = objectID
            }
        }
        let promotedObjectID = try #require(offscreenID)

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await updateContext.perform {
            let manga = try #require(updateContext.existingObject(with: promotedObjectID) as? MangaArchive)
            manga.dateAdded = baseDate.addingTimeInterval(1000)
            try updateContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.objectID == promotedObjectID
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.first?.objectID == promotedObjectID)
        #expect(snapshots.first?.title == "Manga 00")
    }

    @Test func backgroundInsertInvalidatesLoadedWindow() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let insertContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_800_320_000)

        for index in 0 ..< 60 {
            _ = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        _ = try await insertManga(
            into: insertContext,
            title: "Newest Manga",
            dateAdded: baseDate.addingTimeInterval(1000)
        )

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Newest Manga"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Newest Manga")
    }

    @Test func backgroundDeleteInvalidatesLoadedWindow() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let deleteContext = persistence.newBackgroundContext()
        let baseDate = Date(timeIntervalSince1970: 1_800_330_000)

        var firstLoadedID: NSManagedObjectID?
        for index in 0 ..< 60 {
            let objectID = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 59 {
                firstLoadedID = objectID
            }
        }
        let deletedObjectID = try #require(firstLoadedID)

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await deleteContext.perform {
            let manga = try #require(deleteContext.existingObject(with: deletedObjectID) as? MangaArchive)
            deleteContext.delete(manga)
            try deleteContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Manga 58"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Manga 58")
        #expect(snapshots.contains { $0.objectID == deletedObjectID } == false)
    }

    @Test func deleteInvalidatesLoadedWindow() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_800_300_000)

        var firstLoadedID: NSManagedObjectID?
        for index in 0..<60 {
            let objectID = try await insertManga(
                into: viewContext,
                title: String(format: "Manga %02d", index),
                dateAdded: baseDate.addingTimeInterval(TimeInterval(index))
            )
            if index == 59 {
                firstLoadedID = objectID
            }
        }
        let deletedObjectID = try #require(firstLoadedID)

        let model = await MainActor.run {
            MangaLibraryModel(debounceDuration: .milliseconds(5))
        }
        await model.configureIfNeeded(viewContext: viewContext)

        try await viewContext.perform {
            let manga = try #require(viewContext.existingObject(with: deletedObjectID) as? MangaArchive)
            viewContext.delete(manga)
            try viewContext.save()
        }

        await waitUntil {
            let currentSnapshots = await currentSnapshots(of: model)
            return currentSnapshots.first?.title == "Manga 58"
        }

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == 48)
        #expect(snapshots.first?.title == "Manga 58")
    }

    @Test func snapshotMappingMatchesLegacyDisplayRules() async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext
        let mangaID = try await insertManga(
            into: viewContext,
            title: "",
            dateAdded: Date(),
            author: "",
            totalPages: 120,
            lastReadPage: 30,
            importComplete: false,
            importErrorMessage: nil
        )

        let snapshot = try await viewContext.perform {
            let manga = try #require(viewContext.existingObject(with: mangaID) as? MangaArchive)
            return MangaLibrarySnapshot(manga: manga)
        }

        #expect(snapshot.title == MangaLocalization.string("Untitled"))
        #expect(snapshot.author == nil)
        #expect(snapshot.progressText == "31 / 120 Read")
        #expect(snapshot.status == .inProgress)
        #expect(snapshot.statusMessage == MangaLocalization.string("Importing..."))
    }

    private func insertManga(
        into viewContext: NSManagedObjectContext,
        id: UUID = UUID(),
        title: String,
        dateAdded: Date,
        author: String? = nil,
        pendingDeletion: Bool = false,
        totalPages: Int64 = 0,
        lastReadPage: Int64 = 0,
        importComplete: Bool = true,
        importErrorMessage: String? = nil
    ) async throws -> NSManagedObjectID {
        try await viewContext.perform {
            let manga = MangaArchive(context: viewContext)
            manga.id = id
            manga.title = title
            manga.author = author
            manga.dateAdded = dateAdded
            manga.pendingDeletion = pendingDeletion
            manga.totalPages = totalPages
            manga.lastReadPage = lastReadPage
            manga.importComplete = importComplete
            manga.importErrorMessage = importErrorMessage
            try viewContext.save()
            return manga.objectID
        }
    }

    private func currentSnapshots(of model: MangaLibraryModel) async -> [MangaLibrarySnapshot] {
        await MainActor.run {
            model.snapshots
        }
    }

    private func waitUntil(
        attempts: Int = 100,
        interval: Duration = .milliseconds(20),
        condition: @escaping () async -> Bool
    ) async {
        for _ in 0..<attempts {
            if await condition() {
                return
            }
            try? await Task.sleep(for: interval)
        }

        Issue.record("Timed out waiting for condition")
    }

    private func assertDeterministicPagination(
        for sortOption: MangaArchiveSortOption,
        seeds: [MangaPaginationSeed]
    ) async throws {
        let persistence = makeMangaPersistenceController()
        let viewContext = persistence.container.viewContext

        for seed in seeds.reversed() {
            _ = try await insertManga(
                into: viewContext,
                id: seed.id,
                title: seed.title,
                dateAdded: seed.dateAdded,
                author: seed.author
            )
        }

        let model = await MainActor.run {
            let model = MangaLibraryModel(debounceDuration: .milliseconds(5))
            model.sortOption = sortOption
            return model
        }
        await model.configureIfNeeded(viewContext: viewContext)
        await model.loadNextPage()

        let snapshots = await currentSnapshots(of: model)
        #expect(snapshots.count == seeds.count)
        #expect(Set(snapshots.map(\.objectID)).count == seeds.count)

        let actualIDs = try await mangaIDs(for: snapshots, in: viewContext)
        let expectedIDs = sortedSeeds(seeds, for: sortOption).map(\.id)
        #expect(actualIDs == expectedIDs)
    }

    private func mangaIDs(
        for snapshots: [MangaLibrarySnapshot],
        in viewContext: NSManagedObjectContext
    ) async throws -> [UUID] {
        try await viewContext.perform {
            try snapshots.map { snapshot in
                let manga = try #require(viewContext.existingObject(with: snapshot.objectID) as? MangaArchive)
                return try #require(manga.id)
            }
        }
    }

    private func sortedSeeds(
        _ seeds: [MangaPaginationSeed],
        for sortOption: MangaArchiveSortOption
    ) -> [MangaPaginationSeed] {
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
                if lhs.dateAdded != rhs.dateAdded {
                    return lhs.dateAdded > rhs.dateAdded
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

private struct MangaPaginationSeed {
    let id: UUID
    let title: String
    let author: String
    let dateAdded: Date
}
