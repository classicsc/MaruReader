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
        dictionary.sequenced = true
        dictionary.isComplete = true
        dictionary.id = UUID()

        let dictionaryURI = dictionary.objectID.uriRepresentation()

        // Create sample tags
        let nounTag = DictionaryTagMeta(context: viewContext)
        nounTag.name = "noun"
        nounTag.category = "partOfSpeech"
        nounTag.order = 1
        nounTag.notes = "Common noun"
        nounTag.score = 0
        nounTag.dictionary = dictionary
        nounTag.id = UUID()

        let verbTag = DictionaryTagMeta(context: viewContext)
        verbTag.name = "v1"
        verbTag.category = "partOfSpeech"
        verbTag.order = 2
        verbTag.notes = "Ichidan verb"
        verbTag.score = 0
        verbTag.dictionary = dictionary
        verbTag.id = UUID()

        let commonTag = DictionaryTagMeta(context: viewContext)
        commonTag.name = "common"
        commonTag.category = "frequency"
        commonTag.order = 3
        commonTag.notes = "Common word"
        commonTag.score = 1
        commonTag.dictionary = dictionary
        commonTag.id = UUID()

        // Create sample terms
        let term1 = Term(context: viewContext)
        term1.expression = "食べる"
        term1.reading = "たべる"
        let termEntry1 = TermEntry(context: viewContext)
        termEntry1.rules = "v1"
        termEntry1.score = 100
        termEntry1.sequence = 1
        termEntry1.setValue([["to eat", "to consume food"]], forKey: "glossary")
        termEntry1.setValue(["common", "v1"], forKey: "termTags")
        termEntry1.dictionary = dictionary
        term1.entries = term1.entries?.adding(termEntry1) as? NSSet
        term1.id = UUID()
        termEntry1.id = UUID()

        let term2 = Term(context: viewContext)
        term2.expression = "飲む"
        term2.reading = "のむ"
        let termEntry2 = TermEntry(context: viewContext)
        termEntry2.rules = "v5m"
        termEntry2.score = 95
        termEntry2.sequence = 2
        termEntry2.setValue([["to drink", "to swallow liquid"]], forKey: "glossary")
        termEntry2.setValue(["common", "v5m"], forKey: "termTags")
        termEntry2.dictionary = dictionary
        term2.entries = term2.entries?.adding(termEntry2) as? NSSet
        term2.id = UUID()
        termEntry2.id = UUID()

        let term3 = Term(context: viewContext)
        term3.expression = "本"
        term3.reading = "ほん"
        let termEntry3 = TermEntry(context: viewContext)
        termEntry3.rules = "noun"
        termEntry3.score = 98
        termEntry3.sequence = 3
        termEntry3.setValue([["book", "volume"], ["main", "head", "this", "our"]], forKey: "glossary")
        termEntry3.setValue(["common", "noun"], forKey: "termTags")
        termEntry3.dictionary = dictionary
        term3.entries = term3.entries?.adding(termEntry3) as? NSSet
        term3.id = UUID()
        termEntry3.id = UUID()

        // Create sample term metadata
        let frequency1 = TermFrequencyEntry(context: viewContext)
        frequency1.value = 5000
        frequency1.displayValue = "5000㋕"
        frequency1.dictionary = dictionary
        frequency1.term = term1
        frequency1.id = UUID()

        let frequency2 = TermFrequencyEntry(context: viewContext)
        frequency2.value = 4500
        frequency2.displayValue = "4500㋕"
        frequency2.dictionary = dictionary
        frequency2.term = term2
        frequency2.id = UUID()

        // Create sample kanji
        let kanji1 = Kanji(context: viewContext)
        kanji1.character = "食"
        let kanjiEntry1 = KanjiEntry(context: viewContext)
        kanjiEntry1.setValue(["ショク", "ジキ"], forKey: "onyomi")
        kanjiEntry1.setValue(["た.べる", "く.う"], forKey: "kunyomi")
        kanjiEntry1.setValue(["eat", "food"], forKey: "meanings")
        kanjiEntry1.setValue(["freq": "100", "grade": "2"], forKey: "stats")
        kanjiEntry1.setValue(["jouyou", "grade2"], forKey: "tags")
        kanjiEntry1.dictionary = dictionary
        kanji1.entries = kanji1.entries?.adding(kanjiEntry1) as? NSSet
        kanji1.id = UUID()
        kanjiEntry1.id = UUID()

        let kanji2 = Kanji(context: viewContext)
        kanji2.character = "飲"
        let kanjiEntry2 = KanjiEntry(context: viewContext)
        kanjiEntry2.setValue(["イン", "オン"], forKey: "onyomi")
        kanjiEntry2.setValue(["の.む", "-の.み"], forKey: "kunyomi")
        kanjiEntry2.setValue(["drink", "smoke", "take"], forKey: "meanings")
        kanjiEntry2.setValue(["freq": "150", "grade": "3"], forKey: "stats")
        kanjiEntry2.setValue(["jouyou", "grade3"], forKey: "tags")
        kanjiEntry2.dictionary = dictionary
        kanji2.entries = kanji2.entries?.adding(kanjiEntry2) as? NSSet
        kanji2.id = UUID()
        kanjiEntry2.id = UUID()

        let kanji3 = Kanji(context: viewContext)
        kanji3.character = "本"
        let kanjiEntry3 = KanjiEntry(context: viewContext)
        kanjiEntry3.setValue(["ホン"], forKey: "onyomi")
        kanjiEntry3.setValue(["もと"], forKey: "kunyomi")
        kanjiEntry3.setValue(["book", "present", "main", "origin", "true", "real"], forKey: "meanings")
        kanjiEntry3.setValue(["freq": "10", "grade": "1"], forKey: "stats")
        kanjiEntry3.setValue(["jouyou", "grade1"], forKey: "tags")
        kanjiEntry3.dictionary = dictionary
        kanji3.entries = kanji3.entries?.adding(kanjiEntry3) as? NSSet
        kanji3.id = UUID()
        kanjiEntry3.id = UUID()

        // Create sample kanji metadata
        let kanjiMeta1 = KanjiFrequencyEntry(context: viewContext)
        kanjiMeta1.frequencyValue = 200
        kanjiMeta1.displayFrequency = "200★"
        kanjiMeta1.dictionary = dictionary
        kanjiMeta1.id = UUID()
        kanji1.frequency = kanji1.frequency?.adding(kanjiMeta1) as? NSSet

        let kanjiMeta2 = KanjiFrequencyEntry(context: viewContext)
        kanjiMeta2.frequencyValue = 250
        kanjiMeta2.displayFrequency = "250★"
        kanjiMeta2.dictionary = dictionary
        kanjiMeta2.id = UUID()
        kanji2.frequency = kanji2.frequency?.adding(kanjiMeta2) as? NSSet

        let kanjiMeta3 = KanjiFrequencyEntry(context: viewContext)
        kanjiMeta3.frequencyValue = 10
        kanjiMeta3.displayFrequency = "10★"
        kanjiMeta3.dictionary = dictionary
        kanjiMeta3.id = UUID()
        kanji3.frequency = kanji3.frequency?.adding(kanjiMeta3) as? NSSet

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
