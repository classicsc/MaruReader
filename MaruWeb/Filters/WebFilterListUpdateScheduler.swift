// WebFilterListUpdateScheduler.swift
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

import BackgroundTasks
import Foundation
import os.log

/// Schedules and runs periodic filter list refreshes.
///
/// The system grants `BGAppRefreshTask`s on a best-effort cadence, so we additionally
/// trigger an opportunistic refresh on app launch whenever the most recent successful
/// refresh is older than `WebContentBlocker.updateInterval`.
@MainActor
public final class WebFilterListUpdateScheduler {
    public static let shared = WebFilterListUpdateScheduler()

    private let log = Logger(subsystem: "MaruWeb", category: "filter-list-scheduler")
    private let downloader: WebFilterListDownloader
    private let storage: WebFilterListStorage
    private let submitRequest: (BGTaskRequest) throws -> Void
    private var didRegister = false
    private var inFlight: Task<Void, Never>?

    public convenience init(
        downloader: WebFilterListDownloader = .shared,
        storage: WebFilterListStorage = .shared
    ) {
        self.init(
            downloader: downloader,
            storage: storage,
            submitRequest: { try BGTaskScheduler.shared.submit($0) }
        )
    }

    init(
        downloader: WebFilterListDownloader,
        storage: WebFilterListStorage,
        submitRequest: @escaping (BGTaskRequest) throws -> Void
    ) {
        self.downloader = downloader
        self.storage = storage
        self.submitRequest = submitRequest
    }

    /// Registers the BGAppRefreshTask handler. Must be called from the host app's `init`
    /// (or before scene activation), exactly once per process.
    public func registerBackgroundTask() {
        guard !didRegister else { return }
        didRegister = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: WebContentBlocker.backgroundRefreshTaskIdentifier,
            using: DispatchQueue.main
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self?.handle(backgroundTask: task)
            }
        }
        if !didRegister {
            log.error("Failed to register background refresh task")
        }
    }

    /// Triggers a refresh if the most recent successful fetch across enabled lists is
    /// older than `WebContentBlocker.updateInterval`, or if no list has ever succeeded.
    public func refreshIfStale(now: Date = Date()) {
        guard isStale(now: now) else { return }
        refreshNow()
    }

    /// Manually triggers a refresh. UI calls this from the "Update Now" button.
    public func refreshNow() {
        _ = startRefresh()
    }

    @discardableResult
    func startRefresh() -> Task<Void, Never> {
        if let inFlight {
            return inFlight
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlight = nil }
            await self.downloader.refreshAll(force: false)
            self.scheduleNextRefresh()
        }
        inFlight = task
        return task
    }

    /// Submits the next BGAppRefreshTask request. Safe to call repeatedly.
    public func scheduleNextRefresh(now: Date = Date()) {
        let request = BGAppRefreshTaskRequest(
            identifier: WebContentBlocker.backgroundRefreshTaskIdentifier
        )
        request.earliestBeginDate = nextEligibleDate(now: now)
        do {
            try submitRequest(request)
        } catch {
            log.error("Failed to schedule background refresh: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - BG task handler

    private func handle(backgroundTask: BGAppRefreshTask) async {
        // Always reschedule first so we keep ticking even if this run is curtailed.
        scheduleNextRefresh()
        storage.start()
        storage.seedDefaultsIfNeeded()

        let task = startRefresh()
        backgroundTask.expirationHandler = {
            task.cancel()
        }
        await task.value
        backgroundTask.setTaskCompleted(success: !task.isCancelled)
    }

    // MARK: - Helpers

    private func isStale(now: Date) -> Bool {
        let enabled = storage.entries.filter(\.isEnabled)
        guard !enabled.isEmpty else { return false }
        let mostRecent = enabled.compactMap(\.lastFetchSuccessAt).max()
        guard let mostRecent else { return true }
        return now.timeIntervalSince(mostRecent) >= WebContentBlocker.updateInterval
    }

    private func nextEligibleDate(now: Date) -> Date {
        let mostRecent = storage.entries.compactMap(\.lastFetchSuccessAt).max() ?? now
        let candidate = mostRecent.addingTimeInterval(WebContentBlocker.updateInterval)
        return max(candidate, now.addingTimeInterval(60))
    }
}
