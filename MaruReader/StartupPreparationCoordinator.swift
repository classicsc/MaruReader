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
import MaruAnki
import MaruDictionaryManagement
import MaruDictionaryUICommon
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
        let startDefaultGrammarDictionaryImportIfNeeded: () async -> Void
        let importSampleContentIfAvailable: () async throws -> Void
        let resumePendingDictionaryUpdates: () async -> Void
        let configureScreenshotStateIfNeeded: () async throws -> Void

        static func `default`(
            processArguments: [String] = ProcessInfo.processInfo.arguments
        ) -> Operations {
            let usesScreenshotOnlyStartupOperations = StartupPreparationCoordinator
                .usesScreenshotOnlyStartupOperations(processArguments: processArguments)
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
                    await ImportManager.shared.cleanupInterruptedImports()
                    await MangaImportManager.shared.cleanupInterruptedImports()
                    await BookImportManager.shared.cleanupPendingDeletions()
                    await ImportManager.shared.cleanupPendingDeletions()
                    await MangaImportManager.shared.cleanupPendingDeletions()
                },
                startDefaultGrammarDictionaryImportIfNeeded: {
                    DefaultGrammarDictionaryInstaller.startIfNeeded()
                },
                importSampleContentIfAvailable: {
                    #if DEBUG
                        guard usesScreenshotOnlyStartupOperations else { return }
                        try await SampleContentSeeder().seedIfAvailable()
                    #endif
                },
                resumePendingDictionaryUpdates: {
                    await DictionaryUpdateManager.shared.resumePendingUpdates()
                },
                configureScreenshotStateIfNeeded: {
                    #if DEBUG
                        guard usesScreenshotOnlyStartupOperations else { return }
                        try await ScreenshotModeSetupSeeder().seedAnkiLapisConfiguration()
                    #endif
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

    var requiresWelcomeScreen: Bool {
        sampleContentAvailable
    }

    var phaseDescription: String {
        phase.description
    }

    private let operations: Operations
    private var task: Task<Void, Never>?
    private nonisolated static let screenshotModeLaunchArgument = "--screenshotMode"

    init(
        needsDictionarySeeding: Bool? = nil,
        sampleContentAvailable: Bool? = nil,
        processArguments: [String] = ProcessInfo.processInfo.arguments,
        operations: Operations? = nil,
        autoStart: Bool = true
    ) {
        let baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
        let resolvedNeedsDictionarySeeding = needsDictionarySeeding
            ?? DictionaryPersistenceController.isBundledDatabaseSeedingNeeded(at: baseDirectory)
        let resolvedSampleContentAvailable = sampleContentAvailable
            ?? Self.defaultSampleContentAvailability(processArguments: processArguments)

        self.needsDictionarySeeding = resolvedNeedsDictionarySeeding
        self.sampleContentAvailable = resolvedSampleContentAvailable
        phase = resolvedNeedsDictionarySeeding ? .preparingDictionary : .cleaningUp
        isPreparationComplete = false
        self.operations = operations ?? .default(processArguments: processArguments)

        if autoStart {
            start()
        }
    }

    nonisolated static func usesScreenshotOnlyStartupOperations(processArguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
            processArguments.contains(screenshotModeLaunchArgument)
        #else
            false
        #endif
    }

    nonisolated static func defaultSampleContentAvailability(
        processArguments: [String] = ProcessInfo.processInfo.arguments,
        hasBundledSampleContent: () -> Bool = { SampleContentSeeder.hasBundledSampleContent() }
    ) -> Bool {
        guard usesScreenshotOnlyStartupOperations(processArguments: processArguments) else {
            return false
        }
        return hasBundledSampleContent()
    }

    var dictionaryFeatureAvailability: DictionaryFeatureAvailability {
        if needsDictionarySeeding, phase == .preparingDictionary {
            return .preparing(description: phase.description)
        }
        return .ready
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
        await operations.startDefaultGrammarDictionaryImportIfNeeded()

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
        do {
            try await operations.configureScreenshotStateIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        phase = .ready
        isPreparationComplete = true
    }
}
