// ImportBackgroundTaskCoordinator.swift
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

import MaruManga
import MaruReaderCore
import os
import UIKit

/// Coordinates `UIApplication.beginBackgroundTask` with import manager lifecycle
/// to prevent `0xdead10cc` crashes when the app is backgrounded during imports.
///
/// When the app enters background with active imports, the coordinator requests
/// extra execution time. If imports finish within that window, great. If background
/// time is running low, all active imports are proactively cancelled and awaited
/// so Core Data contexts flush and SQLite locks are released before suspension.
@MainActor
final class ImportBackgroundTaskCoordinator {
    private let logger = Logger.maru(category: "ImportBackgroundTask")

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var monitoringTask: Task<Void, Never>?

    /// The minimum remaining background time (in seconds) before triggering
    /// proactive cancellation. Must leave enough headroom for cleanup to finish.
    private let cancellationThreshold: TimeInterval = 5

    private let managers: [any BackgroundAwareImporting]

    init(managers: [any BackgroundAwareImporting]? = nil) {
        self.managers = managers ?? [
            DictionaryImportManager.shared,
            AudioSourceImportManager.shared,
            BookImportManager.shared,
            MangaImportManager.shared,
        ]
    }

    /// Call when the app enters background. Starts a background task if any
    /// import manager has active work, then monitors remaining time.
    func handleBackgrounding() {
        monitoringTask?.cancel()
        monitoringTask = Task { [managers, cancellationThreshold] in
            let hasActive = await managers.hasActiveImport()
            guard hasActive else { return }

            let logger = self.logger
            logger.info("Active imports detected, requesting background execution time")

            let taskID = UIApplication.shared.beginBackgroundTask(withName: "MaruReader.ImportCompletion") {
                logger.warning("Background task expiration handler fired")
                // Safety net — endBackgroundTask is called below after cancellation;
                // the expiration handler must also call it in case monitoring misses.
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
            }
            self.backgroundTaskID = taskID
            guard taskID != .invalid else {
                logger.warning("System refused background task request")
                return
            }

            while !Task.isCancelled {
                let remaining = UIApplication.shared.backgroundTimeRemaining
                let allDone = await !managers.hasActiveImport()

                if allDone {
                    logger.info("All imports finished within background window")
                    break
                }

                if remaining < cancellationThreshold {
                    logger.warning(
                        "Background time low (\(remaining, format: .fixed(precision: 1))s), cancelling active imports"
                    )
                    await withTaskGroup(of: Void.self) { group in
                        for manager in managers {
                            group.addTask { await manager.cancelForBackgrounding() }
                        }
                    }
                    logger.info("All import managers finished cleanup")
                    break
                }

                try? await Task.sleep(for: .seconds(1))
            }

            self.endBackgroundTaskIfNeeded()
        }
    }

    /// Call when the app returns to foreground. Cancels monitoring and ends
    /// any outstanding background task — imports can continue normally.
    func handleForegroundReturn() {
        monitoringTask?.cancel()
        monitoringTask = nil
        endBackgroundTaskIfNeeded()
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        logger.info("Ending background task")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

// MARK: - Helpers

private extension [any BackgroundAwareImporting] {
    func hasActiveImport() async -> Bool {
        for manager in self {
            if await manager.hasActiveImport { return true }
        }
        return false
    }
}
