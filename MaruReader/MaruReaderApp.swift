// MaruReaderApp.swift
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
import MaruAnki
import MaruDictionaryUICommon
import MaruManga
import MaruReaderCore
import os
import SwiftUI

@main
struct MaruReaderApp: App {
    static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshotMode")

    @State private var startupPreparationCoordinator: StartupPreparationCoordinator
    @State private var didContinueFromWelcome = false
    @State private var importBackgroundTaskCoordinator = ImportBackgroundTaskCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if Self.isScreenshotMode {
            TourManager.resetAllTours()
            // Pre-mark all tours as completed so they don't appear.
            for tourID in ["bookReader", "mangaReader", "webViewerToolbar"] {
                UserDefaults.standard.set(Date(), forKey: "tour.\(tourID).completed")
            }
        }

        _startupPreparationCoordinator = State(initialValue: StartupPreparationCoordinator())

        Task { @MainActor in
            let returnURL = URL(string: "marureader://anki/x-success")
            await AnkiMobileURLOpenerStore.shared.configure(
                opener: UIApplicationURLOpener(),
                returnURL: returnURL
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            if shouldShowContentView {
                ContentView()
                    .environment(\.dictionaryFeatureAvailability, startupPreparationCoordinator.dictionaryFeatureAvailability)
            } else {
                WelcomeView(
                    phaseDescription: startupPreparationCoordinator.phaseDescription,
                    errorMessage: startupPreparationCoordinator.errorMessage,
                    canContinue: startupPreparationCoordinator.canContinue,
                    isPreparing: !startupPreparationCoordinator.isPreparationComplete && startupPreparationCoordinator.errorMessage == nil,
                    onRetry: { startupPreparationCoordinator.retry() },
                    onContinue: { didContinueFromWelcome = true }
                )
                .onChange(of: startupPreparationCoordinator.isPreparationComplete) { _, isComplete in
                    if Self.isScreenshotMode, isComplete {
                        didContinueFromWelcome = true
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                savePersistentStoresForBackgrounding()
                importBackgroundTaskCoordinator.handleBackgrounding()
            case .active:
                importBackgroundTaskCoordinator.handleForegroundReturn()
            default:
                break
            }
        }
    }

    private var shouldShowContentView: Bool {
        if !startupPreparationCoordinator.requiresWelcomeScreen {
            return true
        }
        return didContinueFromWelcome && startupPreparationCoordinator.isPreparationComplete
    }

    /// Save all Core Data view contexts to flush pending writes and release SQLite
    /// file locks before suspension. Prevents `0xdead10cc` termination.
    private func savePersistentStoresForBackgrounding() {
        let logger = Logger.maru(category: "AppLifecycle")
        logger.info("App entering background, saving persistent stores")

        let viewContexts = [
            ("BookData", BookDataPersistenceController.shared.container.viewContext),
            ("Dictionary", DictionaryPersistenceController.shared.container.viewContext),
            ("MangaData", MangaDataPersistenceController.shared.container.viewContext),
        ]

        for (name, context) in viewContexts {
            context.performAndWait {
                guard context.hasChanges else { return }
                do {
                    try context.save()
                    logger.info("Saved \(name, privacy: .public) view context on backgrounding")
                } catch {
                    logger.error("Failed to save \(name, privacy: .public) view context: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
