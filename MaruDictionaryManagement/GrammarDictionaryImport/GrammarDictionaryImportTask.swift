// GrammarDictionaryImportTask.swift
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

struct GrammarDictionaryImportTask {
    private struct ArchiveLayout {
        let indexEntry: Entry
        let prefix: String
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

    func start() async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let (jobURL, grammarDictionaryID) = try await context.perform {
            guard let grammarDictionary = try? context.existingObject(with: jobID) as? GrammarDictionary else {
                throw ImportError.importNotFound
            }
            guard let jobURL = grammarDictionary.file else {
                throw ImportError.missingFile
            }
            if grammarDictionary.id == nil {
                grammarDictionary.id = UUID()
            }
            guard let grammarDictionaryID = grammarDictionary.id else {
                throw ImportError.entityCreationFailed
            }

            grammarDictionary.displayProgressMessage = FrameworkLocalization.string("Processing grammar dictionary...")
            try context.save()
            return (jobURL, grammarDictionaryID)
        }

        guard FileManager.default.fileExists(atPath: jobURL.path) else {
            throw ImportError.missingFile
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
            throw ImportError.unzipFailed(underlyingError: error)
        }

        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        let layout = try findArchiveLayout(in: entries)
        let indexData: Data
        do {
            indexData = try await archive.extractData(layout.indexEntry, skipCRC32: true)
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        let index = try JSONDecoder().decode(GrammarDictionaryIndex.self, from: indexData)
        try validate(index: index)

        let entryByPath = Swift.Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
        for entry in index.entries {
            guard entryByPath[layout.prefix + entry.path]?.type == .file else {
                throw ImportError.missingFile
            }
        }

        guard let installDirectory = GrammarDictionaryStorage.installedDirectoryURL(
            grammarDictionaryID: grammarDictionaryID,
            in: baseDirectory
        ) else {
            throw ImportError.mediaDirectoryCreationFailed
        }

        let scratchSpace = ImportScratchSpace(kind: .grammar, jobUUID: grammarDictionaryID)
        scratchSpace.cleanupBestEffort()
        try scratchSpace.ensureExists()
        let stagedDirectory = scratchSpace.rootURL.appendingPathComponent("installed", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)

        do {
            try indexData.write(to: stagedDirectory.appendingPathComponent(GrammarDictionaryStorage.manifestFileName), options: .atomic)

            for entry in index.entries {
                guard let archiveEntry = entryByPath[layout.prefix + entry.path] else {
                    throw ImportError.missingFile
                }
                let destinationURL = stagedDirectory.appendingPathComponent(entry.path)
                guard destinationURL.isContained(in: stagedDirectory) else {
                    throw ImportError.invalidData
                }
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                _ = try await archive.extract(archiveEntry, to: destinationURL, skipCRC32: false)
            }

            for archiveEntry in entries where archiveEntry.type == .file && archiveEntry.path.hasPrefix(layout.prefix + GrammarDictionaryStorage.mediaDirectoryName + "/") {
                let relativePath = String(archiveEntry.path.dropFirst(layout.prefix.count))
                let destinationURL = stagedDirectory.appendingPathComponent(relativePath)
                guard destinationURL.isContained(in: stagedDirectory) else {
                    throw ImportError.invalidData
                }
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                _ = try await archive.extract(archiveEntry, to: destinationURL, skipCRC32: false)
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        if FileManager.default.fileExists(atPath: installDirectory.path) {
            try FileManager.default.removeItem(at: installDirectory)
        }
        try FileManager.default.createDirectory(at: installDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: stagedDirectory, to: installDirectory)

        try await context.perform {
            guard let grammarDictionary = try? context.existingObject(with: jobID) as? GrammarDictionary else {
                throw ImportError.importNotFound
            }
            grammarDictionary.title = index.title
            grammarDictionary.revision = index.revision
            grammarDictionary.author = index.author
            grammarDictionary.attribution = index.attribution
            grammarDictionary.displayDescription = index.description
            grammarDictionary.license = index.license
            grammarDictionary.indexURL = index.indexUrl
            grammarDictionary.downloadURL = index.downloadUrl
            grammarDictionary.isUpdatable = index.isUpdatable ?? false
            grammarDictionary.format = Int64(index.format)
            grammarDictionary.entryCount = Int64(index.entries.count)
            grammarDictionary.formTagCount = Int64(index.formTags.count)
            for entry in index.entries {
                let storedEntry = GrammarDictionaryEntry(context: context)
                storedEntry.id = UUID()
                storedEntry.dictionaryID = grammarDictionaryID
                storedEntry.entryID = entry.id
                storedEntry.title = entry.title
                storedEntry.path = entry.path
                storedEntry.formTags = index.formTags
                    .filter { $0.value.contains(entry.id) }
                    .map(\.key)
                    .sorted()
                    .joined(separator: "\n")
            }
            grammarDictionary.isComplete = true
            grammarDictionary.isFailed = false
            grammarDictionary.isCancelled = false
            grammarDictionary.displayProgressMessage = FrameworkLocalization.string("Import complete.")
            grammarDictionary.timeCompleted = Date()
            try context.save()
        }

        return grammarDictionaryID
    }

    private func findArchiveLayout(in entries: [Entry]) throws -> ArchiveLayout {
        let fileEntries = entries.filter { $0.type == .file }
        let rootEntries = fileEntries.filter { !$0.path.contains("/") }

        if let indexEntry = rootEntries.first(where: { $0.path == GrammarDictionaryStorage.manifestFileName }) {
            return ArchiveLayout(indexEntry: indexEntry, prefix: "")
        }

        if let nestedIndex = fileEntries.first(where: { entry in
            entry.path.hasSuffix("/\(GrammarDictionaryStorage.manifestFileName)") && entry.path.split(separator: "/").count == 2
        }) {
            let prefix = nestedIndex.path.replacingOccurrences(of: GrammarDictionaryStorage.manifestFileName, with: "")
            return ArchiveLayout(indexEntry: nestedIndex, prefix: prefix)
        }

        throw ImportError.unrecognizedArchive
    }

    private func validate(index: GrammarDictionaryIndex) throws {
        guard index.type == GrammarDictionaryIndex.packageType,
              index.format == GrammarDictionaryIndex.supportedFormat,
              !index.title.isEmpty,
              !index.entries.isEmpty
        else {
            throw ImportError.invalidData
        }

        let entryIDs = Set(index.entries.map(\.id))
        guard entryIDs.count == index.entries.count else {
            throw ImportError.invalidData
        }

        for entry in index.entries {
            guard !entry.id.isEmpty,
                  !entry.title.isEmpty,
                  entry.path.hasSuffix(".md"),
                  !entry.path.hasPrefix("/"),
                  !entry.path.contains("..")
            else {
                throw ImportError.invalidData
            }
        }

        for (_, relatedEntryIDs) in index.formTags {
            guard !relatedEntryIDs.isEmpty,
                  relatedEntryIDs.allSatisfy({ entryIDs.contains($0) })
            else {
                throw ImportError.invalidData
            }
        }
    }
}
