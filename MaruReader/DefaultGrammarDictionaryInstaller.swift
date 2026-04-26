// DefaultGrammarDictionaryInstaller.swift
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

import BackgroundAssets
import CoreData
import Foundation
import MaruDictionaryManagement
import MaruReaderCore
import os
import System

enum DefaultGrammarDictionaryInstaller {
    private static let logger = Logger.maru(category: "DefaultGrammarDictionaryInstaller")
    private static let assetPackID = "YokubiGrammarDictionary"
    private static let archivePath = System.FilePath("build/GrammarDictionary/yokubi-grammar-dictionary.zip")
    private static let dictionaryTitle = "Yokubi Grammar Guide"
    private static let dictionaryRevision = "1"

    static func startIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DictionaryPersistenceController.defaultGrammarDictionaryImportCompletionKey) else {
            return
        }

        Task(priority: .utility) {
            await importIfNeeded()
        }
    }

    private static func importIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: DictionaryPersistenceController.defaultGrammarDictionaryImportCompletionKey) else {
            return
        }

        let assetPackManager = AssetPackManager.shared
        var shouldRemoveAssetPack = false

        do {
            if try await defaultGrammarDictionaryAlreadyImported() {
                DictionaryPersistenceController.markDefaultGrammarDictionaryImportComplete()
                return
            }

            let assetPack = try await assetPackManager.assetPack(withID: assetPackID)
            try await assetPackManager.ensureLocalAvailability(of: assetPack)
            shouldRemoveAssetPack = true

            let archiveURL = try assetPackManager.url(for: archivePath)
            let jobID = try await ImportManager.shared.enqueueGrammarDictionaryImport(from: archiveURL)
            await ImportManager.shared.waitForCompletion(jobID: jobID)

            if await grammarDictionaryImportCompleted(jobID: jobID) {
                DictionaryPersistenceController.markDefaultGrammarDictionaryImportComplete()
            } else {
                logger.warning("Default grammar dictionary import did not complete.")
            }
        } catch {
            logger.warning("Failed to import default grammar dictionary: \(error.localizedDescription, privacy: .public)")
        }

        if shouldRemoveAssetPack {
            do {
                try await assetPackManager.remove(assetPackWithID: assetPackID)
            } catch {
                logger.warning("Failed to clean default grammar dictionary asset: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func grammarDictionaryImportCompleted(jobID: NSManagedObjectID) async -> Bool {
        let context = DictionaryPersistenceController.shared.newBackgroundContext()
        return await context.perform {
            guard let grammarDictionary = try? context.existingObject(with: jobID) as? GrammarDictionary else {
                return false
            }
            return grammarDictionary.isComplete && !grammarDictionary.isFailed && !grammarDictionary.isCancelled
        }
    }

    private static func defaultGrammarDictionaryAlreadyImported() async throws -> Bool {
        let context = DictionaryPersistenceController.shared.newBackgroundContext()
        return try await context.perform {
            let request: NSFetchRequest<GrammarDictionary> = GrammarDictionary.fetchRequest()
            request.predicate = NSPredicate(
                format: "isComplete == YES AND pendingDeletion == NO AND title == %@ AND revision == %@",
                dictionaryTitle,
                dictionaryRevision
            )
            request.fetchLimit = 1
            return try context.count(for: request) > 0
        }
    }
}
