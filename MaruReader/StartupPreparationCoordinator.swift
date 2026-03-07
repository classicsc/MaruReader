// StartupPreparationCoordinator.swift
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
import MaruManga
import MaruReaderCore
import Observation

@MainActor
@Observable
final class StartupPreparationCoordinator {
    struct Operations {
        let seedDictionaryIfNeeded: () async -> Void
        let setAnkiPreferencesUpdater: () async -> Void
        let cleanupInterruptedImportsAndPendingDeletions: () async -> Void
        let importSampleContentIfAvailable: () async throws -> Void
        let resumePendingDictionaryUpdates: () async -> Void

        static func `default`() -> Operations {
            let sampleContentSeeder = SampleContentSeeder()
            return Operations(
                seedDictionaryIfNeeded: {
                    let baseDirectory = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
                    )
                    await DictionaryPersistenceController.seedBundledDatabaseIfNeeded(to: baseDirectory)
                },
                setAnkiPreferencesUpdater: {
                    await DictionaryUpdateManager.shared.setAnkiPreferencesUpdater(DictionaryUpdateAnkiPreferencesUpdater())
                },
                cleanupInterruptedImportsAndPendingDeletions: {
                    await BookImportManager.shared.cleanupInterruptedImports()
                    await DictionaryImportManager.shared.cleanupInterruptedImports()
                    await AudioSourceImportManager.shared.cleanupInterruptedImports()
                    await MangaImportManager.shared.cleanupInterruptedImports()
                    await BookImportManager.shared.cleanupPendingDeletions()
                    await DictionaryImportManager.shared.cleanupPendingDeletions()
                    await AudioSourceImportManager.shared.cleanupPendingDeletions()
                    await MangaImportManager.shared.cleanupPendingDeletions()
                },
                importSampleContentIfAvailable: {
                    try await sampleContentSeeder.seedIfAvailable()
                },
                resumePendingDictionaryUpdates: {
                    await DictionaryUpdateManager.shared.resumePendingUpdates()
                }
            )
        }
    }

    enum Phase {
        case preparingDictionary
        case cleaningUp
        case importingSampleContent
        case finalizing
        case ready

        var description: String {
            switch self {
            case .preparingDictionary:
                String(localized: "Preparing dictionary...")
            case .cleaningUp:
                String(localized: "Finishing startup tasks...")
            case .importingSampleContent:
                String(localized: "Importing sample content...")
            case .finalizing:
                String(localized: "Finalizing startup...")
            case .ready:
                String(localized: "Ready to continue")
            }
        }
    }

    private(set) var phase: Phase
    private(set) var isPreparationComplete: Bool
    private(set) var errorMessage: String?

    let needsDictionarySeeding: Bool
    let sampleContentAvailable: Bool
    let requiresWelcomeScreen: Bool

    var phaseDescription: String {
        phase.description
    }

    private let operations: Operations
    private var task: Task<Void, Never>?

    init(
        needsDictionarySeeding: Bool? = nil,
        sampleContentAvailable: Bool? = nil,
        operations: Operations = .default(),
        autoStart: Bool = true
    ) {
        let baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
        let resolvedNeedsDictionarySeeding = needsDictionarySeeding
            ?? DictionaryPersistenceController.isBundledDatabaseSeedingNeeded(at: baseDirectory)
        let resolvedSampleContentAvailable = sampleContentAvailable ?? SampleContentSeeder.hasBundledSampleContent()

        self.needsDictionarySeeding = resolvedNeedsDictionarySeeding
        self.sampleContentAvailable = resolvedSampleContentAvailable
        requiresWelcomeScreen = resolvedNeedsDictionarySeeding || resolvedSampleContentAvailable
        phase = resolvedNeedsDictionarySeeding ? .preparingDictionary : .cleaningUp
        isPreparationComplete = false
        self.operations = operations

        if autoStart {
            start()
        }
    }

    var canContinue: Bool {
        isPreparationComplete && errorMessage == nil
    }

    func retry() {
        guard task == nil else { return }
        errorMessage = nil
        isPreparationComplete = false
        phase = needsDictionarySeeding ? .preparingDictionary : .cleaningUp
        start()
    }

    func waitUntilComplete() async {
        await task?.value
    }

    private func start() {
        task = Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        defer {
            task = nil
        }

        if needsDictionarySeeding {
            phase = .preparingDictionary
            await operations.seedDictionaryIfNeeded()
        }

        await operations.setAnkiPreferencesUpdater()

        phase = .cleaningUp
        await operations.cleanupInterruptedImportsAndPendingDeletions()

        if sampleContentAvailable {
            phase = .importingSampleContent
            do {
                try await operations.importSampleContentIfAvailable()
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        phase = .finalizing
        await operations.resumePendingDictionaryUpdates()

        phase = .ready
        isPreparationComplete = true
    }
}
