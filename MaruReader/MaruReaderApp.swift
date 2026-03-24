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

import Foundation
import MaruAnki
import MaruDictionaryUICommon
import MaruManga
import MaruReaderCore
import SwiftUI

@main
struct MaruReaderApp: App {
    static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshotMode")

    @State private var startupPreparationCoordinator: StartupPreparationCoordinator
    @State private var didContinueFromWelcome = false

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
    }

    private var shouldShowContentView: Bool {
        if !startupPreparationCoordinator.requiresWelcomeScreen {
            return true
        }
        return didContinueFromWelcome && startupPreparationCoordinator.isPreparationComplete
    }
}
