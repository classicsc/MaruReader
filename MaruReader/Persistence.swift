//
//  Persistence.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample dictionary
        let dictionary = Dictionary(context: viewContext)
        dictionary.title = "Sample Japanese Dictionary"
        dictionary.revision = "1.0"
        dictionary.format = 3
        dictionary.author = "Preview Author"
        dictionary.displayDescription = "A sample dictionary for SwiftUI previews"
        dictionary.sourceLanguage = "ja"
        dictionary.targetLanguage = "en"
        dictionary.isComplete = true
        dictionary.isTermDictionary = true
        dictionary.isFreqDictionary = true
        dictionary.isKanjiFreqDictionary = true
        dictionary.isKanjiDictionary = true
        dictionary.hasTags = true
        dictionary.sequenced = true
        dictionary.id = UUID()

        let dictionaryURI = dictionary.objectID.uriRepresentation()

        // Create sample tags
        let nounTag = Tag(context: viewContext)
        nounTag.name = "noun"
        nounTag.category = "partOfSpeech"
        nounTag.order = 1
        nounTag.notes = "Common noun"
        nounTag.score = 0
        nounTag.dictionary = dictionaryURI

        let verbTag = Tag(context: viewContext)
        verbTag.name = "v1"
        verbTag.category = "partOfSpeech"
        verbTag.order = 2
        verbTag.notes = "Ichidan verb"
        verbTag.score = 0
        verbTag.dictionary = dictionaryURI

        let commonTag = Tag(context: viewContext)
        commonTag.name = "common"
        commonTag.category = "frequency"
        commonTag.order = 3
        commonTag.notes = "Common word"
        commonTag.score = 1
        commonTag.dictionary = dictionaryURI

        // Create sample terms
        let term1 = Term(context: viewContext)
        term1.expression = "食べる"
        term1.reading = "たべる"
        term1.rules = "v1"
        term1.score = 100
        term1.sequence = 1
        term1.setValue([["to eat", "to consume food"]], forKey: "glossary")
        term1.setValue(["common", "v1"], forKey: "termTags")
        term1.dictionary = dictionaryURI

        let term2 = Term(context: viewContext)
        term2.expression = "飲む"
        term2.reading = "のむ"
        term2.rules = "v5m"
        term2.score = 95
        term2.sequence = 2
        term2.setValue([["to drink", "to swallow liquid"]], forKey: "glossary")
        term2.setValue(["common", "v5m"], forKey: "termTags")
        term2.dictionary = dictionaryURI

        let term3 = Term(context: viewContext)
        term3.expression = "本"
        term3.reading = "ほん"
        term3.rules = "noun"
        term3.score = 98
        term3.sequence = 3
        term3.setValue([["book", "volume"], ["main", "head", "this", "our"]], forKey: "glossary")
        term3.setValue(["common", "noun"], forKey: "termTags")
        term3.dictionary = dictionaryURI

        // Create sample term metadata
        let termMeta1 = TermMeta(context: viewContext)
        termMeta1.expression = "食べる"
        termMeta1.type = "freq"
        termMeta1.frequencyValue = 5000
        termMeta1.displayFrequency = "5000㋕"
        termMeta1.setValue(["value": 5000, "displayValue": "5000㋕"], forKey: "data")
        termMeta1.dictionary = dictionaryURI

        let termMeta2 = TermMeta(context: viewContext)
        termMeta2.expression = "飲む"
        termMeta2.type = "freq"
        termMeta2.frequencyValue = 4500
        termMeta2.displayFrequency = "4500㋕"
        termMeta2.setValue(["value": 4500, "displayValue": "4500㋕"], forKey: "data")
        termMeta2.dictionary = dictionaryURI

        // Create sample kanji
        let kanji1 = Kanji(context: viewContext)
        kanji1.character = "食"
        kanji1.setValue(["ショク", "ジキ"], forKey: "onyomi")
        kanji1.setValue(["た.べる", "く.う"], forKey: "kunyomi")
        kanji1.setValue(["eat", "food"], forKey: "meanings")
        kanji1.setValue(["freq": "100", "grade": "2"], forKey: "stats")
        kanji1.setValue(["jouyou", "grade2"], forKey: "tags")
        kanji1.dictionary = dictionaryURI

        let kanji2 = Kanji(context: viewContext)
        kanji2.character = "飲"
        kanji2.setValue(["イン", "オン"], forKey: "onyomi")
        kanji2.setValue(["の.む", "-の.み"], forKey: "kunyomi")
        kanji2.setValue(["drink", "smoke", "take"], forKey: "meanings")
        kanji2.setValue(["freq": "150", "grade": "3"], forKey: "stats")
        kanji2.setValue(["jouyou", "grade3"], forKey: "tags")
        kanji2.dictionary = dictionaryURI

        let kanji3 = Kanji(context: viewContext)
        kanji3.character = "本"
        kanji3.setValue(["ホン"], forKey: "onyomi")
        kanji3.setValue(["もと"], forKey: "kunyomi")
        kanji3.setValue(["book", "present", "main", "origin", "true", "real"], forKey: "meanings")
        kanji3.setValue(["freq": "10", "grade": "1"], forKey: "stats")
        kanji3.setValue(["jouyou", "grade1"], forKey: "tags")
        kanji3.dictionary = dictionaryURI

        // Create sample kanji metadata
        let kanjiMeta1 = KanjiMeta(context: viewContext)
        kanjiMeta1.character = "食"
        kanjiMeta1.type = "freq"
        kanjiMeta1.frequencyValue = 200
        kanjiMeta1.displayFrequency = "200★"
        kanjiMeta1.dictionary = dictionaryURI

        let kanjiMeta2 = KanjiMeta(context: viewContext)
        kanjiMeta2.character = "飲"
        kanjiMeta2.type = "freq"
        kanjiMeta2.frequencyValue = 250
        kanjiMeta2.displayFrequency = "250★"
        kanjiMeta2.dictionary = dictionaryURI

        let kanjiMeta3 = KanjiMeta(context: viewContext)
        kanjiMeta3.character = "本"
        kanjiMeta3.type = "freq"
        kanjiMeta3.frequencyValue = 10
        kanjiMeta3.displayFrequency = "10★"
        kanjiMeta3.dictionary = dictionaryURI

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Register custom value transformers used by Transformable attributes before loading stores
        CoreDataTransformers.register()
        container = NSPersistentContainer(name: "MaruReader")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func newTaskContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
}
