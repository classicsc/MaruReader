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

        for index in 0..<60 {
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

        for index in 0..<60 {
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

        for index in 0..<60 {
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

    @Test func insertInvalidatesLoadedWindow() async throws {
        let persistence = makeBookPersistenceController()
        let viewContext = persistence.container.viewContext
        let baseDate = Date(timeIntervalSince1970: 1_700_300_000)

        for index in 0..<60 {
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
            added: baseDate.addingTimeInterval(1_000)
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
            book.id = UUID()
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
        for _ in 0..<attempts {
            if await condition() {
                return
            }
            try? await Task.sleep(for: interval)
        }

        Issue.record("Timed out waiting for condition")
    }
}
