//
//  File.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//
import CoreData
import Foundation

extension DictionaryImportManager {
    private func processKanjiBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Get the dictionary entity
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        // Get the dictionary format
        let format = dictionary.format

        // Process kanji banks
        guard let kanjiBankURLs = job.kanjiBanks as? [URL] else {
            throw DictionaryImportError.databaseError
        }

        if !kanjiBankURLs.isEmpty {
            job.displayProgressMessage = "Processing kanji..."
            try context.save()

            if format == 3 {
                let kanjiIterator = StreamingBankIterator<KanjiBankV3Entry>(
                    bankURLs: kanjiBankURLs,
                    dataFormat: Int(format)
                )

                for try await entry in kanjiIterator {
                    try Task.checkCancellation()

                    // Find or create Kanji entity
                    let kanji = try findOrCreateKanji(character: entry.character, context: context)

                    // Create KanjiEntry
                    let kanjiEntry = KanjiEntry(context: context)
                    kanjiEntry.id = UUID()
                    kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                    kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                    kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                    kanjiEntry.setValue(entry.stats, forKey: "stats")
                    kanjiEntry.setValue(entry.tags, forKey: "tags")

                    context.insert(kanjiEntry)

                    // Link relationships
                    kanjiEntry.kanji = kanji
                    kanjiEntry.dictionary = dictionary

                    // Link tags
                    try linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                }
            } else if format == 1 {
                let kanjiIterator = StreamingBankIterator<KanjiBankV1Entry>(
                    bankURLs: kanjiBankURLs,
                    dataFormat: Int(format)
                )

                for try await entry in kanjiIterator {
                    try Task.checkCancellation()

                    // Find or create Kanji entity
                    let kanji = try findOrCreateKanji(character: entry.character, context: context)

                    // Create KanjiEntry
                    let kanjiEntry = KanjiEntry(context: context)
                    kanjiEntry.id = UUID()
                    kanjiEntry.setValue(entry.onyomi, forKey: "onyomi")
                    kanjiEntry.setValue(entry.kunyomi, forKey: "kunyomi")
                    kanjiEntry.setValue(entry.meanings, forKey: "meanings")
                    kanjiEntry.setValue([:], forKey: "stats") // V1 doesn't have stats
                    kanjiEntry.setValue(entry.tags, forKey: "tags")

                    context.insert(kanjiEntry)

                    // Link relationships
                    kanjiEntry.kanji = kanji
                    kanjiEntry.dictionary = dictionary

                    // Link tags
                    try linkTagsToKanjiEntry(kanjiEntry, tags: entry.tags, dictionary: dictionary, context: context)
                }
            }

            job.setValue(kanjiBankURLs, forKey: "processedKanjiBanks")
            job.displayProgressMessage = "Processed kanji."
            try context.save()
        }

        try Task.checkCancellation()
    }

    private func processKanjiMetaBanks(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Get the dictionary entity
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        // Get the dictionary format
        let format = dictionary.format

        guard let kanjiMetaBankURLs = job.kanjiMetaBanks as? [URL] else {
            throw DictionaryImportError.databaseError
        }

        if !kanjiMetaBankURLs.isEmpty {
            // Process kanji meta banks only for format 3
            guard format == 3 else {
                throw DictionaryImportError.invalidData
            }

            job.displayProgressMessage = "Processing kanji metadata..."
            try context.save()

            let kanjiMetaIterator = StreamingBankIterator<KanjiMetaBankV3Entry>(
                bankURLs: kanjiMetaBankURLs,
                dataFormat: Int(format)
            )

            for try await entry in kanjiMetaIterator {
                try Task.checkCancellation()

                // Find or create Kanji entity
                let kanji = try findOrCreateKanji(character: entry.kanji, context: context)

                // Create KanjiFrequencyEntry
                let frequencyEntry = KanjiFrequencyEntry(context: context)
                frequencyEntry.id = UUID()

                // Handle different frequency formats
                switch entry.frequency {
                case let .number(value):
                    frequencyEntry.frequencyValue = value
                    frequencyEntry.displayFrequency = String(value)
                case let .string(displayValue):
                    // Try to parse as number, default to 0 if can't parse
                    frequencyEntry.frequencyValue = Double(displayValue) ?? 0.0
                    frequencyEntry.displayFrequency = displayValue
                case let .object(value, displayValue):
                    frequencyEntry.frequencyValue = value
                    frequencyEntry.displayFrequency = displayValue ?? String(value)
                }

                context.insert(frequencyEntry)

                // Link relationships
                frequencyEntry.kanji = kanji
                frequencyEntry.dictionary = dictionary
            }

            job.setValue(kanjiMetaBankURLs, forKey: "processedKanjiMetaBanks")
            job.displayProgressMessage = "Processed kanji metadata."
            try context.save()
        }

        try Task.checkCancellation()
    }

    private func findOrCreateTerm(expression: String, reading: String, context: NSManagedObjectContext) throws -> Term {
        let request: NSFetchRequest<Term> = Term.fetchRequest()
        request.predicate = NSPredicate(format: "expression == %@ AND reading == %@", expression, reading)
        request.fetchLimit = 1

        if let existingTerm = try context.fetch(request).first {
            return existingTerm
        }

        // Create new Term
        let term = Term(context: context)
        term.id = UUID()
        term.expression = expression
        term.reading = reading

        context.insert(term)

        return term
    }

    private func linkTagsToTermEntry(_ termEntry: TermEntry, termTags: [String], definitionTags: [String]?, dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link term tags
        for tagName in termTags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                termEntry.addToRichTermTags(tagMeta)
            }
        }

        // Link definition tags
        if let definitionTags {
            for tagName in definitionTags {
                if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                    termEntry.addToRichDefinitionTags(tagMeta)
                }
            }
        }
    }

    private func findTagMeta(name: String, dictionary: Dictionary, context: NSManagedObjectContext) throws -> DictionaryTagMeta? {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND dictionary == %@", name, dictionary)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }

    private func findOrCreateKanji(character: String, context: NSManagedObjectContext) throws -> Kanji {
        let request: NSFetchRequest<Kanji> = Kanji.fetchRequest()
        request.predicate = NSPredicate(format: "character == %@", character)
        request.fetchLimit = 1

        if let existingKanji = try context.fetch(request).first {
            return existingKanji
        }

        // Create new Kanji
        let kanji = Kanji(context: context)
        kanji.id = UUID()
        kanji.character = character

        context.insert(kanji)

        return kanji
    }

    private func linkTagsToKanjiEntry(_ kanjiEntry: KanjiEntry, tags: [String], dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link kanji tags
        for tagName in tags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                kanjiEntry.addToRichTags(tagMeta)
            }
        }
    }

    private func copyMedia(_ job: DictionaryZIPFileImport, context: NSManagedObjectContext) async throws {
        // Walk workingDirectory, copy non-json files preserving structure
        // Destination: Application Support/Media/<dictionary-id>/
        // Create directory if needed
        // Update job.mediaImported

        let fileManager = FileManager.default
        guard let jobDirectory = job.workingDirectory else {
            throw DictionaryImportError.noWorkingDirectory
        }
        guard let dictionary = job.dictionary else {
            throw DictionaryImportError.databaseError
        }

        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        guard let dictionaryID = dictionary.id else {
            throw DictionaryImportError.databaseError
        }
        let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

        // Create media directory if it doesn't exist
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Recursively copy files
        let enumerator = fileManager.enumerator(at: jobDirectory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()
            // Skip JSON files
            if fileURL.pathExtension.lowercased() == "json" {
                continue
            }

            // Determine relative path
            let relativePath = fileURL.path.replacingOccurrences(of: jobDirectory.path, with: "")
            let destinationURL = mediaDir.appendingPathComponent(relativePath)
            let destinationDir = destinationURL.deletingLastPathComponent()

            // Create destination directory if needed
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
            }

            // Copy file
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: fileURL, to: destinationURL)
        }

        job.mediaImported = true
        job.displayProgressMessage = "Copied media files."
        try Task.checkCancellation()
        try context.save()
    }

    func cleanMediaDirectory(job: DictionaryZIPFileImport) {
        let fileManager = FileManager.default
        guard let dictionary = job.dictionary, let dictionaryID = dictionary.id else {
            return
        }

        do {
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let mediaDir = appSupportDir.appendingPathComponent("Media").appendingPathComponent(dictionaryID.uuidString)

            if fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.removeItem(at: mediaDir)
            }
        } catch {}
    }

    func cleanup(job: DictionaryZIPFileImport) {
        // Delete working directory if complete/failed/cancelled
        let fileManager = FileManager.default
        if let workingDir = job.workingDirectory, fileManager.fileExists(atPath: workingDir.path) {
            do {
                try fileManager.removeItem(at: workingDir)
            } catch {}
        }
    }

    // MARK: - Test Helper Methods

    /// Set test cancellation hook for controlled testing
    func setTestCancellationHook(_ hook: (() async throws -> Void)?) {
        testCancellationHook = hook
    }

    /// Set test error injection for controlled testing
    func setTestErrorInjection(_ injection: (() throws -> Void)?) {
        testErrorInjection = injection
    }
}
