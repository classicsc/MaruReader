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
actor DictionaryImportManager {
    private var importCoordinators: [DictionaryImportCoordinator] = []
    private var importTasks: [UUID: Task<Void, Error>] = [:]
    @Published var activeImports: [DictionaryImportInfo] = []
    let container: NSPersistentContainer

    init(container: NSPersistentContainer = PersistenceController.shared.container) {
        self.container = container
    }

    /// Adds a new dictionary import operation from a zip file URL.
    func runImport(fromZipFile url: URL) throws -> UUID {
        let importID = UUID()
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(importID.uuidString)
        try Zip.unzipFile(url, destination: destinationURL, overwrite: true, password: nil)
        guard let indexURL = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).first(where: { $0.lastPathComponent == "index.json" }) else {
            throw DictionaryImportError.notADictionary
        }
        let tagBankURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("tag_bank_") && $0.pathExtension == "json" }
        let termBankURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("term_bank_") && $0.pathExtension == "json" }
        let kanjiBankURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("kanji_bank_") && $0.pathExtension == "json" }
        let termMetaBankURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("term_meta_bank_") && $0.pathExtension == "json" }
        let kanjiMetaBankURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("kanji_meta_bank_") && $0.pathExtension == "json" }
        let mediaURLs = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).filter { !$0.pathExtension.isEmpty && !$0.lastPathComponent.hasSuffix(".json") }
        let coordinator = DictionaryImportCoordinator(
            displayName: url.deletingPathExtension().lastPathComponent,
            indexURL: indexURL,
            termBankURLs: termBankURLs.isEmpty ? nil : termBankURLs,
            kanjiBankURLs: kanjiBankURLs.isEmpty ? nil : kanjiBankURLs,
            termMetaBankURLs: termMetaBankURLs.isEmpty ? nil : termMetaBankURLs,
            kanjiMetaBankURLs: kanjiMetaBankURLs.isEmpty ? nil : kanjiMetaBankURLs,
            tagBankURLs: tagBankURLs.isEmpty ? nil : tagBankURLs,
            mediaURLs: mediaURLs.isEmpty ? nil : mediaURLs,
            container: container,
            id: importID
        )
        importCoordinators.append(coordinator)
        let importInfo = DictionaryImportInfo(displayName: url.deletingPathExtension().lastPathComponent, id: importID, zipFileURL: url)
        activeImports.append(importInfo)
        let task = Task {
            try await coordinator.runImport()
        }
        importTasks[importID] = task
        return importID
    }

    func waitForImport(id: UUID) async throws {
        guard let task = importTasks[id] else {
            throw DictionaryImportError.importNotFound
        }
        try await task.value
    }

    func markImportComplete(id: UUID) {
        if let index = activeImports.firstIndex(where: { $0.id == id }) {
            activeImports[index].completionTime = Date()
        }
    }
}
