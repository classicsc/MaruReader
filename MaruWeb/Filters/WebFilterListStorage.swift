// WebFilterListStorage.swift
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

// swiftformat:disable header
// This Source Code Form is subject to the terms of the Mozilla
// Public License, v. 2.0. If a copy of the MPL was not distributed
// with this file, You can obtain one at
// https://mozilla.org/MPL/2.0/.
//
// Copyright 2026 Samuel Smoker
// Original version Copyright 2022 The Brave Authors.

import CoreData
import CryptoKit
import Foundation
import Observation
import os.log

/// Manages the on-disk filter list files and the matching `WebFilterList` Core Data rows.
///
/// All public mutations run on the main actor against the persistence controller's view
/// context. Raw list contents (potentially several MB each) live as plain UTF-8 text
/// files under Application Support so the Core Data store stays small.
@MainActor
@Observable
public final class WebFilterListStorage {
    public static let shared = WebFilterListStorage()

    /// Current snapshot of all rows, ordered by `sortOrder` then `addedAt`.
    public private(set) var entries: [WebFilterListEntry] = []

    private let log = Logger(subsystem: "MaruWeb", category: "filter-list-storage")
    private let persistenceController: WebDataPersistenceController
    private let fileManager: FileManager
    private let filterListsDirectory: URL
    private var didStart = false
    private var saveObserver: NSObjectProtocol?

    init(
        persistenceController: WebDataPersistenceController = .shared,
        fileManager: FileManager = .default,
        filterListsDirectory: URL? = nil
    ) {
        self.persistenceController = persistenceController
        self.fileManager = fileManager
        self.filterListsDirectory = filterListsDirectory ?? Self.defaultFilterListsDirectory(fileManager: fileManager)
    }

    // MARK: - Lifecycle

    /// Loads the current snapshot and registers for save notifications. Idempotent.
    public func start() {
        guard !didStart else { return }
        didStart = true
        ensureDirectoryExists()
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let context = note.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === self.persistenceController.container.persistentStoreCoordinator
            else { return }
            MainActor.assumeIsolated {
                self.reloadEntries()
            }
        }
        reloadEntries()
    }

    /// Tears down observers. Useful in tests; the production singleton is started once
    /// and never stopped.
    public func stop() {
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        saveObserver = nil
        didStart = false
    }

    private func reloadEntries() {
        let context = persistenceController.container.viewContext
        let request = NSFetchRequest<WebFilterList>(entityName: "WebFilterList")
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "addedAt", ascending: true),
        ]
        do {
            let managed = try context.fetch(request)
            entries = managed.compactMap(WebFilterListEntry.init)
        } catch {
            log.error("Failed to load filter list entries: \(String(describing: error), privacy: .public)")
            entries = []
        }
    }

    // MARK: - Seeding

    /// Inserts the default filter lists if they have not been seeded for this user yet.
    /// Gated on a UserDefaults flag so removing a default list doesn't cause it to be
    /// re-added on next launch. The flag is only set once the inserts persist.
    public func seedDefaultsIfNeeded(
        defaults: UserDefaults = .standard,
        seeds: [WebFilterListSeed] = WebContentBlocker.defaultFilterListSeeds
    ) {
        guard !defaults.bool(forKey: WebContentBlocker.didSeedDefaultsKey) else { return }
        let context = persistenceController.container.viewContext
        for (offset, seed) in seeds.enumerated() {
            if fetchManaged(sourceURL: seed.sourceURL, context: context) != nil { continue }
            insert(seed: seed, sortOrder: offset, context: context)
        }
        guard saveContext(context) else { return }
        defaults.set(true, forKey: WebContentBlocker.didSeedDefaultsKey)
        reloadEntries()
    }

    // MARK: - Mutations

    @discardableResult
    public func add(seed: WebFilterListSeed) -> WebFilterListEntry? {
        let context = persistenceController.container.viewContext
        if let existing = fetchManaged(sourceURL: seed.sourceURL, context: context) {
            return WebFilterListEntry(existing)
        }
        let nextOrder = (entries.map(\.sortOrder).max() ?? -1) + 1
        let managed = insert(seed: seed, sortOrder: nextOrder, context: context)
        saveContext(context)
        reloadEntries()
        return managed.flatMap(WebFilterListEntry.init)
    }

    public func remove(id: UUID) {
        let context = persistenceController.container.viewContext
        guard let managed = fetchManaged(id: id, context: context) else { return }
        context.delete(managed)
        saveContext(context)
        removeContentsFile(for: id)
        reloadEntries()
    }

    public func setEnabled(id: UUID, _ isEnabled: Bool) {
        updateManaged(id: id) { $0.isEnabled = isEnabled }
    }

    public func rename(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateManaged(id: id) { $0.name = trimmed }
    }

    public func reorder(ids: [UUID]) {
        let context = persistenceController.container.viewContext
        for (offset, id) in ids.enumerated() {
            guard let managed = fetchManaged(id: id, context: context) else { continue }
            managed.sortOrder = Int64(offset)
        }
        saveContext(context)
        reloadEntries()
    }

    // MARK: - Contents I/O

    /// Returns the on-disk filter list contents for the given entry id, or `nil` if no
    /// successful download has produced a file yet.
    public func loadContents(for id: UUID) -> String? {
        let url = contentsURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Writes new contents to disk and updates the matching row's metadata. Returns the
    /// digest hex of the contents. Throws if the on-disk write fails (in which case Core
    /// Data metadata is left untouched).
    @discardableResult
    public func applyDownloadSuccess(
        id: UUID,
        contents: String,
        etag: String?,
        lastModified: String?,
        attemptedAt: Date,
        succeededAt: Date
    ) throws -> String {
        try writeContents(contents, for: id)
        let digest = Self.digest(of: contents)
        updateManaged(id: id) { managed in
            managed.contentDigest = digest
            managed.etag = etag
            managed.lastModifiedHeader = lastModified
            managed.lastFetchAttemptAt = attemptedAt
            managed.lastFetchSuccessAt = succeededAt
            managed.lastFetchError = nil
        }
        return digest
    }

    /// Records that a refresh attempt yielded HTTP 304 (Not Modified) — preserve contents,
    /// bump the success timestamp.
    public func applyDownloadNotModified(id: UUID, attemptedAt: Date, at: Date) {
        updateManaged(id: id) { managed in
            managed.lastFetchAttemptAt = attemptedAt
            managed.lastFetchSuccessAt = at
            managed.lastFetchError = nil
        }
    }

    /// Records a refresh failure — preserve last contents so blocking still works.
    public func applyDownloadFailure(id: UUID, attemptedAt: Date, message: String) {
        updateManaged(id: id) { managed in
            managed.lastFetchAttemptAt = attemptedAt
            managed.lastFetchError = message
        }
    }

    /// Records per-list rule counts after a successful compile.
    public func applyCompileMetrics(id: UUID, ruleCount: Int, convertedFilterCount: Int) {
        updateManaged(id: id) { managed in
            managed.ruleCount = Int64(ruleCount)
            managed.convertedFilterCount = Int64(convertedFilterCount)
        }
    }

    // MARK: - Private helpers

    @discardableResult
    private func insert(
        seed: WebFilterListSeed,
        sortOrder: Int,
        context: NSManagedObjectContext
    ) -> WebFilterList? {
        guard let entity = NSEntityDescription.entity(forEntityName: "WebFilterList", in: context) else {
            return nil
        }
        let managed = WebFilterList(entity: entity, insertInto: context)
        managed.id = UUID()
        managed.sourceURL = seed.sourceURL.absoluteString
        managed.name = seed.name
        managed.formatRaw = seed.format.rawValue
        managed.isEnabled = true
        managed.sortOrder = Int64(sortOrder)
        managed.addedAt = Date()
        managed.ruleCount = 0
        managed.convertedFilterCount = 0
        return managed
    }

    private func fetchManaged(id: UUID, context: NSManagedObjectContext) -> WebFilterList? {
        let request = NSFetchRequest<WebFilterList>(entityName: "WebFilterList")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchManaged(sourceURL: URL, context: NSManagedObjectContext) -> WebFilterList? {
        let request = NSFetchRequest<WebFilterList>(entityName: "WebFilterList")
        request.predicate = NSPredicate(format: "sourceURL == %@", sourceURL.absoluteString)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func updateManaged(id: UUID, _ apply: (WebFilterList) -> Void) {
        let context = persistenceController.container.viewContext
        guard let managed = fetchManaged(id: id, context: context) else { return }
        apply(managed)
        saveContext(context)
        reloadEntries()
    }

    @discardableResult
    private func saveContext(_ context: NSManagedObjectContext) -> Bool {
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            log.error("Filter list save failed: \(String(describing: error), privacy: .public)")
            context.rollback()
            return false
        }
    }

    // MARK: - Filesystem

    private func contentsURL(for id: UUID) -> URL {
        filterListsDirectory.appendingPathComponent("\(id.uuidString).txt")
    }

    private func writeContents(_ contents: String, for id: UUID) throws {
        ensureDirectoryExists()
        let url = contentsURL(for: id)
        try contents.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    private func removeContentsFile(for id: UUID) {
        let url = contentsURL(for: id)
        try? fileManager.removeItem(at: url)
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: filterListsDirectory.path) {
            try? fileManager.createDirectory(
                at: filterListsDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private static func defaultFilterListsDirectory(fileManager: FileManager) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MaruWebFilterLists", isDirectory: true)
    }

    static func digest(of contents: String) -> String {
        let hash = SHA256.hash(data: Data(contents.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
