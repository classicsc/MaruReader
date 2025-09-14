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
        Task {
            do {
                try unzipDictionary(at: url, to: destinationURL)
                let indexURL = try locateIndexFile(in: destinationURL)
                let banks = try collectBankAndMediaURLs(in: destinationURL)
                let coordinator = makeCoordinator(
                    displayName: baseName,
                    indexURL: indexURL,
                    banks: banks,
                    id: importID
                )
                registerAndStartCoordinator(coordinator, id: importID)
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
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        func filtered(_ prefix: String) -> [URL]? {
            let matches = contents.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            return matches.isEmpty ? nil : matches
        }
        let media = contents.filter { !$0.pathExtension.isEmpty && !$0.lastPathComponent.hasSuffix(".json") }
        return BankURLsBundle(
            termBankURLs: filtered("term_bank_"),
            kanjiBankURLs: filtered("kanji_bank_"),
            termMetaBankURLs: filtered("term_meta_bank_"),
            kanjiMetaBankURLs: filtered("kanji_meta_bank_"),
            tagBankURLs: filtered("tag_bank_"),
            mediaURLs: media.isEmpty ? nil : media
        )
    }

    private func makeCoordinator(displayName: String, indexURL: URL, banks: BankURLsBundle, id: UUID) -> DictionaryImportCoordinator {
        DictionaryImportCoordinator(
            displayName: displayName,
            indexURL: indexURL,
            termBankURLs: banks.termBankURLs,
            kanjiBankURLs: banks.kanjiBankURLs,
            termMetaBankURLs: banks.termMetaBankURLs,
            kanjiMetaBankURLs: banks.kanjiMetaBankURLs,
            tagBankURLs: banks.tagBankURLs,
            mediaURLs: banks.mediaURLs,
            container: container,
            id: id
        )
    }

    private func registerAndStartCoordinator(_ coordinator: DictionaryImportCoordinator, id: UUID) {
        importCoordinators.append(coordinator)
        let task = Task { [weak self] in
            do {
                try await coordinator.runImport()
            } catch {
                self?.markImportFailed(id: id, error: error)
            }
        }
        importTasks[id] = task
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
