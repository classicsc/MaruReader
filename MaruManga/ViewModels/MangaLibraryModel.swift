// MangaLibraryModel.swift
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
import Observation

private let mangaLibraryPageSize = 48
private let mangaLibraryBasePredicateFormat = "pendingDeletion == NO"
private let mangaLibraryQueryAffectingKeys: Set<String> = [
    "author",
    "dateAdded",
    "pendingDeletion",
    "title",
]

enum MangaArchiveSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"

    var localizedName: String {
        switch self {
        case .title:
            MangaLocalization.string("Title")
        case .author:
            MangaLocalization.string("Author")
        case .dateAdded:
            MangaLocalization.string("Date Added")
        }
    }

    var id: String {
        rawValue
    }

    var nsSortDescriptors: [NSSortDescriptor] {
        switch self {
        case .title:
            [
                NSSortDescriptor(keyPath: \MangaArchive.title, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.author, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.id, ascending: true),
            ]
        case .author:
            [
                NSSortDescriptor(keyPath: \MangaArchive.author, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.title, ascending: true),
                NSSortDescriptor(keyPath: \MangaArchive.id, ascending: true),
            ]
        case .dateAdded:
            [
                NSSortDescriptor(keyPath: \MangaArchive.dateAdded, ascending: false),
                NSSortDescriptor(keyPath: \MangaArchive.id, ascending: true),
            ]
        }
    }
}

extension MangaArchiveSortOption: Sendable {}

struct MangaLibrarySnapshot: Identifiable, Equatable {
    enum Status: Equatable {
        case complete
        case inProgress
        case failed
        case cancelled
    }

    let objectID: NSManagedObjectID
    let title: String
    let author: String?
    let progressText: String?
    let coverFileName: String?
    let status: Status
    let statusMessage: String?

    var id: NSManagedObjectID {
        objectID
    }

    var isComplete: Bool {
        status == .complete
    }

    var actionLabel: String? {
        switch status {
        case .complete:
            nil
        case .inProgress:
            MangaLocalization.string("Cancel")
        case .failed, .cancelled:
            MangaLocalization.string("Remove")
        }
    }

    init(manga: MangaArchive) {
        objectID = manga.objectID
        if let title = manga.title, !title.isEmpty {
            self.title = title
        } else {
            self.title = MangaLocalization.string("Untitled")
        }

        if let author = manga.author, !author.isEmpty {
            self.author = author
        } else {
            self.author = nil
        }

        progressText = MangaLibraryProgressFormatter.displayProgress(
            lastReadPage: manga.lastReadPage,
            totalPages: manga.totalPages
        )
        coverFileName = manga.coverFileName

        if manga.importComplete {
            status = .complete
        } else if let errorMessage = manga.importErrorMessage, !errorMessage.isEmpty {
            status = .failed
        } else {
            status = .inProgress
        }

        switch status {
        case .complete:
            statusMessage = nil
        case .inProgress:
            statusMessage = MangaLocalization.string("Importing...")
        case .failed:
            statusMessage = manga.importErrorMessage ?? MangaLocalization.string("Import failed.")
        case .cancelled:
            statusMessage = MangaLocalization.string("Import cancelled.")
        }
    }
}

@MainActor
@Observable
public final class MangaLibraryModel {
    private(set) var snapshots: [MangaLibrarySnapshot] = []
    private(set) var hasMorePages = true
    private(set) var isLoadingPage = false
    private(set) var hasLoadedInitialPage = false

    var sortOption: MangaArchiveSortOption = .dateAdded
    var selectedMangaID: NSManagedObjectID?
    var pendingDeleteMangaID: NSManagedObjectID?
    var metadataEditorMangaID: NSManagedObjectID?

    private var contextObserverTask: Task<Void, Never>?
    private var mergeObserverTask: Task<Void, Never>?
    private var saveObserverTask: Task<Void, Never>?
    private var debouncedReloadTask: Task<Void, Never>?
    private var currentOffset = 0
    private var loadToken = UUID()
    private let debounceDuration: Duration
    private let notificationCenter: NotificationCenter
    private var viewContext: NSManagedObjectContext?

    public init(
        debounceDuration: Duration = .milliseconds(200),
        notificationCenter: NotificationCenter = .default
    ) {
        self.debounceDuration = debounceDuration
        self.notificationCenter = notificationCenter
    }

    func configureIfNeeded(viewContext: NSManagedObjectContext) async {
        if self.viewContext !== viewContext {
            contextObserverTask?.cancel()
            mergeObserverTask?.cancel()
            saveObserverTask?.cancel()
            debouncedReloadTask?.cancel()
            self.viewContext = viewContext
            observeContextChanges()
            observeMergedObjectIDChanges()
            observeSavedObjectIDChanges()
            invalidateInFlightLoads()
            snapshots = []
            currentOffset = 0
            hasMorePages = true
            hasLoadedInitialPage = false
        }

        guard !hasLoadedInitialPage, !isLoadingPage else { return }
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoadingPage, hasMorePages else { return }
        guard viewContext != nil else { return }

        isLoadingPage = true
        let offset = currentOffset
        let token = loadToken

        do {
            let nextSnapshots = try await fetchSnapshots(offset: offset, limit: mangaLibraryPageSize)
            guard token == loadToken else { return }

            let existingIDs = Set(snapshots.map(\.objectID))
            let uniqueSnapshots = nextSnapshots.filter { !existingIDs.contains($0.objectID) }
            snapshots.append(contentsOf: uniqueSnapshots)
            currentOffset = snapshots.count
            hasMorePages = nextSnapshots.count == mangaLibraryPageSize
            hasLoadedInitialPage = true
        } catch {
            hasMorePages = false
        }

        if token == loadToken {
            isLoadingPage = false
        }
    }

    func reloadForCurrentSort() async {
        invalidateInFlightLoads()
        snapshots = []
        currentOffset = 0
        hasMorePages = true
        hasLoadedInitialPage = false
        await loadNextPage()
    }

    func dismissDeleteConfirmation() {
        pendingDeleteMangaID = nil
    }

    func showDeleteConfirmation(for objectID: NSManagedObjectID) {
        pendingDeleteMangaID = objectID
    }

    private func observeContextChanges() {
        guard let viewContext else { return }

        contextObserverTask = Task { [weak self, notificationCenter, viewContext] in
            for await notification in notificationCenter.notifications(
                named: .NSManagedObjectContextObjectsDidChange,
                object: viewContext
            ) {
                guard let self else { return }
                await self.handleContextChange(notification)
            }
        }
    }

    private func observeMergedObjectIDChanges() {
        guard let viewContext else { return }

        mergeObserverTask = Task { [weak self, notificationCenter, viewContext] in
            for await notification in notificationCenter.notifications(
                named: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
                object: viewContext
            ) {
                guard let self else { return }
                await self.handleMergedObjectIDChange(notification)
            }
        }
    }

    private func observeSavedObjectIDChanges() {
        guard let viewContext else { return }
        guard let persistentStoreCoordinator = viewContext.persistentStoreCoordinator else { return }

        saveObserverTask = Task { [weak self, notificationCenter, viewContext, persistentStoreCoordinator] in
            for await notification in notificationCenter.notifications(
                named: NSManagedObjectContext.didSaveObjectIDsNotification
            ) {
                guard let self else { return }
                guard let sourceContext = notification.object as? NSManagedObjectContext else { continue }
                guard sourceContext !== viewContext else { continue }
                guard sourceContext.persistentStoreCoordinator === persistentStoreCoordinator else { continue }
                await self.handleSavedObjectIDChange(notification)
            }
        }
    }

    private func handleContextChange(_ notification: Notification) async {
        guard !snapshots.isEmpty || hasLoadedInitialPage else { return }

        let inserted = objectIDs(forKey: NSInsertedObjectsKey, in: notification)
        let deleted = objectIDs(forKey: NSDeletedObjectsKey, in: notification)
        let updatedObjects = managedObjects(forKey: NSUpdatedObjectsKey, in: notification)
        let loadedIDs = Set(snapshots.map(\.objectID))

        if !inserted.isEmpty || !deleted.isEmpty {
            scheduleReloadLoadedWindow()
            return
        }

        var patchIDs: [NSManagedObjectID] = []
        for object in updatedObjects {
            guard object is MangaArchive else { continue }

            if !loadedIDs.contains(object.objectID) {
                if mangaLibraryQueryAffectingKeys.intersection(Set(object.changedValues().keys)).isEmpty == false {
                    scheduleReloadLoadedWindow()
                    return
                }
                continue
            }

            if mangaLibraryQueryAffectingKeys.intersection(Set(object.changedValues().keys)).isEmpty == false {
                scheduleReloadLoadedWindow()
                return
            }

            patchIDs.append(object.objectID)
        }

        if !patchIDs.isEmpty {
            await patchLoadedSnapshots(for: patchIDs)
        }
    }

    private func scheduleReloadLoadedWindow() {
        let targetCount = max(snapshots.count, mangaLibraryPageSize)

        debouncedReloadTask?.cancel()
        debouncedReloadTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: debounceDuration)
            guard !Task.isCancelled else { return }
            await self.reloadLoadedWindow(targetCount: targetCount)
        }
    }

    private func reloadLoadedWindow(targetCount: Int) async {
        guard targetCount > 0 else {
            await reloadForCurrentSort()
            return
        }
        guard viewContext != nil else { return }

        invalidateInFlightLoads()
        isLoadingPage = true
        let token = loadToken

        do {
            let refreshedSnapshots = try await fetchSnapshots(offset: 0, limit: targetCount)
            guard token == loadToken else { return }

            snapshots = refreshedSnapshots
            currentOffset = refreshedSnapshots.count
            hasMorePages = refreshedSnapshots.count == targetCount
            hasLoadedInitialPage = true
        } catch {
            guard token == loadToken else { return }
            snapshots = []
            currentOffset = 0
            hasMorePages = false
            hasLoadedInitialPage = true
        }

        if token == loadToken {
            isLoadingPage = false
        }
    }

    private func patchLoadedSnapshots(for objectIDs: [NSManagedObjectID]) async {
        let uniqueIDs = Array(Set(objectIDs))
        guard !uniqueIDs.isEmpty else { return }

        do {
            let refreshedSnapshots = try await fetchSnapshots(for: uniqueIDs)
            let snapshotsByID = Dictionary(uniqueKeysWithValues: refreshedSnapshots.map { ($0.objectID, $0) })
            snapshots = snapshots.map { snapshot in
                snapshotsByID[snapshot.objectID] ?? snapshot
            }
        } catch {
            scheduleReloadLoadedWindow()
        }
    }

    private func handleMergedObjectIDChange(_ notification: Notification) async {
        guard !snapshots.isEmpty || hasLoadedInitialPage else { return }
        if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil {
            scheduleReloadLoadedWindow()
            return
        }

        let inserted = objectIDs(forKey: NSInsertedObjectIDsKey, in: notification)
        let deleted = objectIDs(forKey: NSDeletedObjectIDsKey, in: notification)
        if !inserted.isEmpty || !deleted.isEmpty {
            scheduleReloadLoadedWindow()
            return
        }

        let changedIDs = objectIDs(forKey: NSUpdatedObjectIDsKey, in: notification)
            .union(objectIDs(forKey: NSRefreshedObjectIDsKey, in: notification))
            .union(objectIDs(forKey: NSInvalidatedObjectIDsKey, in: notification))
        let loadedIDs = Set(snapshots.map(\.objectID))
        let visibleChangedIDs = Array(changedIDs.intersection(loadedIDs))

        if !visibleChangedIDs.isEmpty {
            await patchLoadedSnapshots(for: visibleChangedIDs)
        }
    }

    private func handleSavedObjectIDChange(_ notification: Notification) async {
        guard !snapshots.isEmpty || hasLoadedInitialPage else { return }
        if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil {
            scheduleReloadLoadedWindow()
            return
        }

        let inserted = objectIDs(forKey: NSInsertedObjectIDsKey, in: notification)
        let deleted = objectIDs(forKey: NSDeletedObjectIDsKey, in: notification)
        if !inserted.isEmpty || !deleted.isEmpty {
            scheduleReloadLoadedWindow()
            return
        }

        let changedIDs = objectIDs(forKey: NSUpdatedObjectIDsKey, in: notification)
            .union(objectIDs(forKey: NSRefreshedObjectIDsKey, in: notification))
            .union(objectIDs(forKey: NSInvalidatedObjectIDsKey, in: notification))
        let loadedIDs = Set(snapshots.map(\.objectID))
        let visibleChangedIDs = Array(changedIDs.intersection(loadedIDs))

        if !visibleChangedIDs.isEmpty {
            await patchLoadedSnapshots(for: visibleChangedIDs)
        }
    }

    private func fetchSnapshots(offset: Int, limit: Int) async throws -> [MangaLibrarySnapshot] {
        guard let viewContext else { return [] }

        let sortOption = sortOption
        let context = viewContext.makeLibraryBackgroundContext()
        return try await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.sortDescriptors = sortOption.nsSortDescriptors
            request.predicate = NSPredicate(format: mangaLibraryBasePredicateFormat)
            request.fetchBatchSize = max(limit, 1)
            request.fetchLimit = limit
            request.fetchOffset = offset
            let manga = try context.fetch(request)
            return manga.map(MangaLibrarySnapshot.init(manga:))
        }
    }

    private func fetchSnapshots(for objectIDs: [NSManagedObjectID]) async throws -> [MangaLibrarySnapshot] {
        guard let viewContext else { return [] }

        let sortOption = sortOption
        let context = viewContext.makeLibraryBackgroundContext()
        return try await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.sortDescriptors = sortOption.nsSortDescriptors
            request.fetchBatchSize = max(objectIDs.count, 1)
            request.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: mangaLibraryBasePredicateFormat),
                    NSPredicate(format: "self IN %@", objectIDs),
                ]
            )
            let manga = try context.fetch(request)
            return manga.map(MangaLibrarySnapshot.init(manga:))
        }
    }

    private func invalidateInFlightLoads() {
        loadToken = UUID()
        isLoadingPage = false
    }

    private func managedObjects(forKey key: String, in notification: Notification) -> Set<NSManagedObject> {
        notification.userInfo?[key] as? Set<NSManagedObject> ?? []
    }

    private func objectIDs(forKey key: String, in notification: Notification) -> Set<NSManagedObjectID> {
        if let rawIDs = notification.userInfo?[key] as? Set<NSManagedObjectID> {
            return rawIDs
        }
        let rawObjects = managedObjects(forKey: key, in: notification)
        return Set(rawObjects.map(\.objectID))
    }
}

private extension NSManagedObjectContext {
    func makeLibraryBackgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
}
