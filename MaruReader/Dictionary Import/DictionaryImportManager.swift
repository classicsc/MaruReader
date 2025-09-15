//
//  DictionaryImportManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import Foundation
import Zip

/// Provides import management and observable progress tracking for dictionary imports.
@MainActor
class DictionaryImportManager: ObservableObject {
    /// Singleton instance of the import manager.
    static let shared = DictionaryImportManager()

    private var importCoordinators: [DictionaryImportCoordinator] = []
    private var importTasks: [UUID: Task<Void, Never>] = [:]
    @Published var activeImports: [DictionaryImportInfo] = []
    let container: NSPersistentContainer

    init(container: NSPersistentContainer = PersistenceController.shared.container) {
        self.container = container
    }

    /// Adds a new dictionary import operation from a zip file URL.
    func runImport(fromZipFile url: URL) -> UUID {
        let importID = UUID()
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(importID.uuidString)
        let baseName = url.deletingPathExtension().lastPathComponent
        let importInfo = DictionaryImportInfo(displayName: baseName, id: importID, zipFileURL: url)
        activeImports.append(importInfo)
        importTasks[importID] = Task {
            do {
                try unzipDictionary(at: url, to: destinationURL)
                let indexURL = try locateIndexFile(in: destinationURL)
                let banks = try collectBankAndMediaURLs(in: destinationURL)
                let coordinator = makeCoordinator(
                    displayName: baseName,
                    indexURL: indexURL,
                    banks: banks,
                    id: importID,
                    rootDirectory: destinationURL
                )
                await registerAndStartCoordinator(coordinator, id: importID)
            } catch {
                markImportFailed(id: importID, error: error)
            }
        }

        return importID
    }

    // MARK: - Helper Steps

    private func unzipDictionary(at source: URL, to destination: URL) throws {
        try Zip.unzipFile(source, destination: destination, overwrite: true, password: nil)
    }

    private func locateIndexFile(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if let index = contents.first(where: { $0.lastPathComponent == "index.json" }) {
            return index
        }
        throw DictionaryImportError.notADictionary
    }

    private struct BankURLsBundle {
        let termBankURLs: [URL]?
        let kanjiBankURLs: [URL]?
        let termMetaBankURLs: [URL]?
        let kanjiMetaBankURLs: [URL]?
        let tagBankURLs: [URL]?
        let mediaURLs: [URL]?
    }

    private func collectBankAndMediaURLs(in directory: URL) throws -> BankURLsBundle {
        // Collect only top-level JSON bank/index files (banks are expected at root)
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        func filtered(_ prefix: String) -> [URL]? {
            let matches = contents.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            return matches.isEmpty ? nil : matches
        }

        // Recursively gather media (non-JSON) files from the root directory and any subdirectories.
        // Banks and index files are JSON and intentionally excluded. Directories themselves are skipped.
        var mediaFiles: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension
                if ext.lowercased() == "json" { continue } // exclude JSON (banks, index)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                    mediaFiles.append(fileURL)
                }
            }
        }
        // Provide deterministic ordering (helps with tests / debugging)
        mediaFiles.sort { $0.path < $1.path }

        return BankURLsBundle(
            termBankURLs: filtered("term_bank_"),
            kanjiBankURLs: filtered("kanji_bank_"),
            termMetaBankURLs: filtered("term_meta_bank_"),
            kanjiMetaBankURLs: filtered("kanji_meta_bank_"),
            tagBankURLs: filtered("tag_bank_"),
            mediaURLs: mediaFiles.isEmpty ? nil : mediaFiles
        )
    }

    private func makeCoordinator(displayName: String, indexURL: URL, banks: BankURLsBundle, id: UUID, rootDirectory: URL) -> DictionaryImportCoordinator {
        DictionaryImportCoordinator(
            displayName: displayName,
            indexURL: indexURL,
            termBankURLs: banks.termBankURLs,
            kanjiBankURLs: banks.kanjiBankURLs,
            termMetaBankURLs: banks.termMetaBankURLs,
            kanjiMetaBankURLs: banks.kanjiMetaBankURLs,
            tagBankURLs: banks.tagBankURLs,
            mediaURLs: banks.mediaURLs,
            mediaRootDirectory: rootDirectory,
            container: container,
            importManager: self,
            id: id
        )
    }

    private func registerAndStartCoordinator(_ coordinator: DictionaryImportCoordinator, id: UUID) async {
        importCoordinators.append(coordinator)
        do {
            try await coordinator.runImport()
        } catch {
            markImportFailed(id: id, error: error)
        }
    }

    func waitForImport(id: UUID) async throws {
        guard let task = importTasks[id] else {
            throw DictionaryImportError.importNotFound
        }
        await task.value
    }

    func markImportComplete(id: UUID) {
        if let index = activeImports.firstIndex(where: { $0.id == id }) {
            activeImports[index].completionTime = Date()
        }
    }

    func markImportFailed(id: UUID, error: Error) {
        if let index = activeImports.firstIndex(where: { $0.id == id }) {
            activeImports[index].error = error
            activeImports[index].failureTime = Date()
        }
    }
}
