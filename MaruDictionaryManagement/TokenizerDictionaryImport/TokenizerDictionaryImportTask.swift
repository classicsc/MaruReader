// TokenizerDictionaryImportTask.swift
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

internal import ReadiumZIPFoundation
import CoreData
import Foundation
import MaruReaderCore

struct TokenizerDictionaryImportResult {
    let tokenizerDictionaryID: UUID
    let replacedTokenizerObjectIDs: [NSManagedObjectID]
}

struct TokenizerDictionaryImportTask {
    private struct ArchiveLayout {
        let indexEntry: Entry
        let resourcePrefix: String
    }

    let jobID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    let baseDirectory: URL?

    init(
        jobID: NSManagedObjectID,
        container: NSPersistentContainer = DictionaryPersistenceController.shared.container,
        baseDirectory: URL?
    ) {
        self.jobID = jobID
        persistentContainer = container
        self.baseDirectory = baseDirectory
    }

    func start() async throws -> TokenizerDictionaryImportResult {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (jobURL, tokenizerID) = try await context.perform {
            guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                throw TokenizerDictionaryImportError.importNotFound
            }
            guard let jobURL = tokenizerDictionary.file else {
                throw TokenizerDictionaryImportError.missingFile
            }
            if tokenizerDictionary.id == nil {
                tokenizerDictionary.id = UUID()
            }
            guard let tokenizerID = tokenizerDictionary.id else {
                throw TokenizerDictionaryImportError.tokenizerDictionaryCreationFailed
            }

            tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Processing tokenizer dictionary...")
            try context.save()
            return (jobURL, tokenizerID)
        }

        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw TokenizerDictionaryImportError.missingFile
        }

        let didStartAccess = jobURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                jobURL.stopAccessingSecurityScopedResource()
            }
        }

        let archive: Archive
        do {
            archive = try await Archive(url: jobURL, accessMode: .read)
        } catch {
            throw TokenizerDictionaryImportError.unzipFailed(underlyingError: error)
        }

        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw TokenizerDictionaryImportError.unzipFailed(underlyingError: error)
        }

        let layout = try findArchiveLayout(in: entries)

        let indexData: Data
        do {
            indexData = try await archive.extractData(layout.indexEntry, skipCRC32: true)
        } catch {
            throw TokenizerDictionaryImportError.unzipFailed(underlyingError: error)
        }

        let index = try JSONDecoder().decode(TokenizerDictionaryIndex.self, from: indexData)

        let scratchSpace = ImportScratchSpace(kind: .tokenizer, jobUUID: tokenizerID)
        scratchSpace.cleanupBestEffort()
        try scratchSpace.ensureExists()

        let stagedDirectory = scratchSpace.rootURL.appendingPathComponent("installed", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)

        do {
            let manifestURL = stagedDirectory.appendingPathComponent(TokenizerDictionaryStorage.manifestFileName)
            try indexData.write(to: manifestURL, options: .atomic)

            for requiredFile in TokenizerDictionaryStorage.requiredResourceFiles {
                guard let entry = entries.first(where: { $0.path == layout.resourcePrefix + requiredFile }) else {
                    throw TokenizerDictionaryImportError.missingFile
                }
                let destinationURL = stagedDirectory.appendingPathComponent(requiredFile)
                _ = try await archive.extract(entry, to: destinationURL, skipCRC32: false)
            }
        } catch let error as TokenizerDictionaryImportError {
            throw error
        } catch {
            throw TokenizerDictionaryImportError.unzipFailed(underlyingError: error)
        }

        guard let installDirectory = TokenizerDictionaryStorage.installedDirectoryURL(in: baseDirectory) else {
            throw TokenizerDictionaryImportError.installationFailed
        }

        let backupDirectory = scratchSpace.rootURL.appendingPathComponent("backup", isDirectory: true)
        let fileManager = FileManager.default
        var movedExistingDirectory = false
        var installedNewDirectory = false

        do {
            if fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.removeItem(at: backupDirectory)
            }

            if fileManager.fileExists(atPath: installDirectory.path) {
                try fileManager.moveItem(at: installDirectory, to: backupDirectory)
                movedExistingDirectory = true
            }

            let installParentDirectory = installDirectory.deletingLastPathComponent()
            try fileManager.createDirectory(at: installParentDirectory, withIntermediateDirectories: true)
            try fileManager.moveItem(at: stagedDirectory, to: installDirectory)
            installedNewDirectory = true
            if fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.removeItem(at: backupDirectory)
            }
        } catch {
            if installedNewDirectory, fileManager.fileExists(atPath: installDirectory.path) {
                try? fileManager.removeItem(at: installDirectory)
            }
            if movedExistingDirectory, fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: installDirectory)
            }
            throw TokenizerDictionaryImportError.installationFailed
        }

        let replacedObjectIDs = try await context.perform {
            let request: NSFetchRequest<TokenizerDictionary> = TokenizerDictionary.fetchRequest()
            request.predicate = NSPredicate(
                format: "isComplete == YES AND pendingDeletion == NO AND isCurrent == YES AND self != %@",
                jobID
            )
            let replaced = (try? context.fetch(request)) ?? []

            guard let tokenizerDictionary = try? context.existingObject(with: jobID) as? TokenizerDictionary else {
                throw TokenizerDictionaryImportError.importNotFound
            }

            tokenizerDictionary.name = index.name
            tokenizerDictionary.version = index.version
            tokenizerDictionary.attribution = index.attribution
            tokenizerDictionary.indexURL = index.indexUrl
            tokenizerDictionary.downloadURL = index.downloadUrl
            tokenizerDictionary.isUpdatable = index.isUpdatable
            tokenizerDictionary.isCurrent = true
            tokenizerDictionary.isComplete = true
            tokenizerDictionary.isFailed = false
            tokenizerDictionary.isCancelled = false
            tokenizerDictionary.displayProgressMessage = FrameworkLocalization.string("Import complete.")
            tokenizerDictionary.timeCompleted = Date()
            tokenizerDictionary.updateReady = false

            for existingTokenizerDictionary in replaced {
                existingTokenizerDictionary.isCurrent = false
                existingTokenizerDictionary.pendingDeletion = true
            }

            try context.save()
            return replaced.map(\.objectID)
        }

        return TokenizerDictionaryImportResult(
            tokenizerDictionaryID: tokenizerID,
            replacedTokenizerObjectIDs: replacedObjectIDs
        )
    }

    private func findArchiveLayout(in entries: [Entry]) throws -> ArchiveLayout {
        let fileEntries = entries.filter { $0.type == .file }
        let rootEntries = fileEntries.filter { !$0.path.contains("/") }

        if let indexEntry = rootEntries.first(where: { $0.path == TokenizerDictionaryStorage.manifestFileName }) {
            let hasAllRootResources = TokenizerDictionaryStorage.requiredResourceFiles.allSatisfy { requiredFile in
                fileEntries.contains(where: { $0.path == requiredFile })
            }
            if hasAllRootResources {
                return ArchiveLayout(indexEntry: indexEntry, resourcePrefix: "")
            }
        }

        if let indexEntry = fileEntries.first(where: {
            $0.path.hasSuffix("/" + TokenizerDictionaryStorage.manifestFileName) && $0.path.split(separator: "/").count == 2
        }) {
            let prefix = String(indexEntry.path.dropLast(TokenizerDictionaryStorage.manifestFileName.count))
            let hasAllNestedResources = TokenizerDictionaryStorage.requiredResourceFiles.allSatisfy { requiredFile in
                fileEntries.contains(where: { $0.path == prefix + requiredFile })
            }
            if hasAllNestedResources {
                return ArchiveLayout(indexEntry: indexEntry, resourcePrefix: prefix)
            }
        }

        throw TokenizerDictionaryImportError.notATokenizerDictionary
    }
}
