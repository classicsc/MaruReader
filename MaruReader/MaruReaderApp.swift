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
import MaruManga
import MaruReaderCore
import SwiftUI

@main
struct MaruReaderApp: App {
    @StateObject private var dictionarySeedingState: DictionarySeedingState
    @State private var didContinueFromWelcome = false

    init() {
        let dictionarySeedingState = DictionarySeedingState()
        _dictionarySeedingState = StateObject(wrappedValue: dictionarySeedingState)

        Task { @MainActor in
            let returnURL = URL(string: "marureader://anki/x-success")
            await AnkiMobileURLOpenerStore.shared.configure(
                opener: UIApplicationURLOpener(),
                returnURL: returnURL
            )
        }

        Task {
            await dictionarySeedingState.waitUntilSeedingComplete()
            await DictionaryUpdateManager.shared.setAnkiPreferencesUpdater(DictionaryUpdateAnkiPreferencesUpdater())
        }

        Task {
            await dictionarySeedingState.waitUntilSeedingComplete()
            await BookImportManager.shared.cleanupInterruptedImports()
            await DictionaryImportManager.shared.cleanupInterruptedImports()
            await AudioSourceImportManager.shared.cleanupInterruptedImports()
            await MangaImportManager.shared.cleanupInterruptedImports()
            await BookImportManager.shared.cleanupPendingDeletions()
            await DictionaryImportManager.shared.cleanupPendingDeletions()
            await AudioSourceImportManager.shared.cleanupPendingDeletions()
            await MangaImportManager.shared.cleanupPendingDeletions()
            await DictionaryUpdateManager.shared.resumePendingUpdates()
        }
    }

    var body: some Scene {
        WindowGroup {
            if shouldShowContentView {
                ContentView()
            } else {
                WelcomeView(
                    isSeedingComplete: dictionarySeedingState.isSeedingComplete,
                    onContinue: { didContinueFromWelcome = true }
                )
            }
        }
    }

    private var shouldShowContentView: Bool {
        if !dictionarySeedingState.needsSeeding {
            return true
        }
        return didContinueFromWelcome && dictionarySeedingState.isSeedingComplete
    }
}

@MainActor
private final class DictionarySeedingState: ObservableObject {
    @Published private(set) var needsSeeding: Bool
    @Published private(set) var isSeedingComplete: Bool

    private let baseDirectory: URL?
    private let seedingTask: Task<Void, Never>?

    init() {
        baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )

        let needsSeeding = DictionaryPersistenceController.isBundledDatabaseSeedingNeeded(at: baseDirectory)
        self.needsSeeding = needsSeeding
        isSeedingComplete = !needsSeeding

        if needsSeeding {
            seedingTask = Task { [baseDirectory] in
                await DictionaryPersistenceController.seedBundledDatabaseIfNeeded(to: baseDirectory)
            }
        } else {
            seedingTask = nil
        }

        if let seedingTask {
            Task { @MainActor in
                await seedingTask.value
                isSeedingComplete = true
            }
        }
    }

    func waitUntilSeedingComplete() async {
        await seedingTask?.value
    }
}
