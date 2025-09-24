//
//  IndexProcessingTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation
import os.log

actor IndexProcessingTask {
    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryImport")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer = PersistenceController.shared.container) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() {
        let container = self.persistentContainer
        let jobID = self.jobID
        task = Task {
            // Load index.json
            // Create Dictionary entity
            // Populate job.termBanks, job.kanjiBanks, etc.
            // Index can contain tag metadata that needs to be processed

            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            let (indexURL, workingDir) = try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.importNotFound
                }
                guard let baseWorkingDir = job.workingDirectory else {
                    throw DictionaryImportError.noWorkingDirectory
                }
                IndexProcessingTask.logger.debug("Base working directory: \(baseWorkingDir.path, privacy: .public)")

                // Check if index.json is directly in the working directory
                var indexURL = baseWorkingDir.appendingPathComponent("index.json")
                var actualWorkingDir = baseWorkingDir

                if !FileManager.default.fileExists(atPath: indexURL.path) {
                    // Check if there's a subdirectory containing the dictionary files
                    let contents = try FileManager.default.contentsOfDirectory(at: baseWorkingDir, includingPropertiesForKeys: [.isDirectoryKey])
                    for item in contents {
                        let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory == true {
                            let possibleIndexURL = item.appendingPathComponent("index.json")
                            if FileManager.default.fileExists(atPath: possibleIndexURL.path) {
                                indexURL = possibleIndexURL
                                actualWorkingDir = item
                                IndexProcessingTask.logger.debug("Found index.json in subdirectory: \(item.lastPathComponent, privacy: .public)")
                                break
                            }
                        }
                    }
                }

                IndexProcessingTask.logger.debug("Looking for index.json at: \(indexURL.path, privacy: .public)")
                guard FileManager.default.fileExists(atPath: indexURL.path) else {
                    IndexProcessingTask.logger.error("index.json not found at: \(indexURL.path, privacy: .public)")
                    throw DictionaryImportError.notADictionary
                }
                return (indexURL, actualWorkingDir)
            }

            // Decode index.json to type DictionaryIndex
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            let index = try decoder.decode(DictionaryIndex.self, from: data)

            // Ensure format is supported
            guard let format = index.format, DictionaryImportManager.supportedFormats.contains(format) else {
                throw DictionaryImportError.unsupportedFormat
            }

            // Find the bank files in working directory
            let contents = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: nil)
            IndexProcessingTask.logger.debug("Working directory contents: \(contents.map(\.lastPathComponent).joined(separator: ", "), privacy: .public)")

            let termBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_bank_") && $0.pathExtension == "json" }
            let kanjiBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_bank_") && $0.pathExtension == "json" }
            let termMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("term_meta_bank_") && $0.pathExtension == "json" }
            let kanjiMetaBanks = contents.filter { $0.lastPathComponent.hasPrefix("kanji_meta_bank_") && $0.pathExtension == "json" }
            let tagBanks = contents.filter { $0.lastPathComponent.hasPrefix("tag_bank_") && $0.pathExtension == "json" }

            IndexProcessingTask.logger.debug("Found banks - terms: \(termBanks.count), kanji: \(kanjiBanks.count), termMeta: \(termMetaBanks.count), kanjiMeta: \(kanjiMetaBanks.count)")

            // Dictionary must have at least one of termBanks, kanjiBanks, termMetaBanks, kanjiMetaBanks
            if termBanks.isEmpty, kanjiBanks.isEmpty, termMetaBanks.isEmpty, kanjiMetaBanks.isEmpty {
                throw DictionaryImportError.notADictionary
            }

            try Task.checkCancellation()

            try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? DictionaryZIPFileImport else {
                    throw DictionaryImportError.importNotFound
                }
                // Create the Dictionary entity and link to job
                let dictionary = Dictionary(context: context)
                dictionary.id = UUID()
                dictionary.title = index.title
                dictionary.attribution = index.attribution
                dictionary.downloadURL = index.downloadUrl
                dictionary.displayDescription = index.description
                dictionary.frequencyMode = index.frequencyMode?.rawValue
                dictionary.sequenced = index.sequenced ?? false
                dictionary.author = index.author
                dictionary.indexURL = index.indexUrl
                dictionary.isUpdatable = index.isUpdatable ?? false
                dictionary.minimumYomitanVersion = index.minimumYomitanVersion
                dictionary.sourceLanguage = index.sourceLanguage
                dictionary.targetLanguage = index.targetLanguage
                dictionary.revision = index.revision
                dictionary.format = Int64(format)

                context.insert(dictionary)

                // If the index has embedded tags, create DictionaryTagMeta entities
                if let embeddedTags = index.tagMeta {
                    for (name, entry) in embeddedTags {
                        let tag = DictionaryTagMeta(context: context)
                        tag.id = UUID()
                        tag.name = name
                        tag.category = entry.category
                        tag.order = Double(entry.order ?? 0)
                        tag.notes = entry.notes
                        tag.score = Double(entry.score ?? 0)

                        context.insert(tag)

                        tag.dictionary = dictionary
                    }
                }

                job.dictionary = dictionary
                job.setValue(termBanks, forKey: "termBanks")
                job.setValue(kanjiBanks, forKey: "kanjiBanks")
                job.setValue(termMetaBanks, forKey: "termMetaBanks")
                job.setValue(kanjiMetaBanks, forKey: "kanjiMetaBanks")
                job.setValue(tagBanks, forKey: "tagBanks")

                job.indexProcessed = true
                job.displayProgressMessage = "Processed dictionary index."

                try context.save()
            }
        }
    }
}
