//
//  DictionaryImportUtilities.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation

enum DictionaryImportUtilities {
    static func prefetchExistingTerms(batch: [(expression: String, reading: String)], context: NSManagedObjectContext) throws -> [String: Term] {
        guard !batch.isEmpty else { return [:] }

        let predicates = batch.map { entry in
            NSPredicate(format: "expression == %@ AND reading == %@", entry.expression, entry.reading)
        }
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        let request: NSFetchRequest<Term> = Term.fetchRequest()
        request.predicate = compoundPredicate

        let existingTerms = try context.fetch(request)
        var termCache: [String: Term] = [:]

        for term in existingTerms {
            let key = "\(term.expression ?? "")|\(term.reading ?? "")"
            termCache[key] = term
        }

        return termCache
    }

    static func prefetchExistingKanji(characters: [String], context: NSManagedObjectContext) throws -> [String: Kanji] {
        guard !characters.isEmpty else { return [:] }

        let request: NSFetchRequest<Kanji> = Kanji.fetchRequest()
        request.predicate = NSPredicate(format: "character IN %@", characters)

        let existingKanji = try context.fetch(request)
        var kanjiCache: [String: Kanji] = [:]

        for kanji in existingKanji {
            if let character = kanji.character {
                kanjiCache[character] = kanji
            }
        }

        return kanjiCache
    }

    static func prefetchDictionaryTags(dictionary: Dictionary, context: NSManagedObjectContext) throws -> [String: NSManagedObjectID] {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        request.predicate = NSPredicate(format: "dictionary == %@", dictionary)

        let tags = try context.fetch(request)
        var tagCache: [String: NSManagedObjectID] = [:]

        for tag in tags {
            if let name = tag.name {
                tagCache[name] = tag.objectID
            }
        }

        return tagCache
    }

    // MARK: - Initial Prefetch Methods (Fetch All Existing Items Once)

    static func prefetchAllExistingTerms(context: NSManagedObjectContext) throws -> [String: NSManagedObjectID] {
        let request: NSFetchRequest<Term> = Term.fetchRequest()
        let terms = try context.fetch(request)
        var cache: [String: NSManagedObjectID] = [:]

        for term in terms {
            if let expression = term.expression, let reading = term.reading {
                let key = "\(expression)|\(reading)"
                cache[key] = term.objectID
            }
        }

        return cache
    }

    static func prefetchAllExistingKanji(context: NSManagedObjectContext) throws -> [String: NSManagedObjectID] {
        let request: NSFetchRequest<Kanji> = Kanji.fetchRequest()
        let kanji = try context.fetch(request)
        var cache: [String: NSManagedObjectID] = [:]

        for kanjiEntity in kanji {
            if let character = kanjiEntity.character {
                cache[character] = kanjiEntity.objectID
            }
        }

        return cache
    }

    // MARK: - Cache Update Methods (After Save, Before Reset)

    static func updateTermCacheWithNewObjects(cache: inout [String: NSManagedObjectID], context: NSManagedObjectContext) {
        // Get all inserted Term objects from this context
        let insertedObjects = context.insertedObjects
        for object in insertedObjects {
            if let term = object as? Term,
               let expression = term.expression,
               let reading = term.reading
            {
                let key = "\(expression)|\(reading)"
                cache[key] = term.objectID
            }
        }
    }

    static func updateKanjiCacheWithNewObjects(cache: inout [String: NSManagedObjectID], context: NSManagedObjectContext) {
        // Get all inserted Kanji objects from this context
        let insertedObjects = context.insertedObjects
        for object in insertedObjects {
            if let kanji = object as? Kanji,
               let character = kanji.character
            {
                cache[character] = kanji.objectID
            }
        }
    }

    // MARK: - Find or Create Methods

    static func findOrCreateTerm(expression: String, reading: String, context: NSManagedObjectContext) throws -> Term {
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

    static func findOrCreateTermWithCache(expression: String, reading: String, cache: inout [String: NSManagedObjectID], context: NSManagedObjectContext) throws -> Term {
        let key = "\(expression)|\(reading)"

        // Check if term exists in cache (by objectID)
        if let objectID = cache[key],
           let term = try? context.existingObject(with: objectID) as? Term
        {
            return term
        }

        // Create new term
        let term = Term(context: context)
        term.id = UUID()
        term.expression = expression
        term.reading = reading
        context.insert(term)

        // Add to cache (will be permanent after save)
        cache[key] = term.objectID
        return term
    }

    static func findOrCreateKanjiWithCache(character: String, cache: inout [String: NSManagedObjectID], context: NSManagedObjectContext) throws -> Kanji {
        // Check if kanji exists in cache (by objectID)
        if let objectID = cache[character],
           let kanji = try? context.existingObject(with: objectID) as? Kanji
        {
            return kanji
        }

        // Create new kanji
        let kanji = Kanji(context: context)
        kanji.id = UUID()
        kanji.character = character
        context.insert(kanji)

        // Add to cache (will be permanent after save)
        cache[character] = kanji.objectID
        return kanji
    }

    static func linkTagsToTermEntryWithCache(_ termEntry: TermEntry, termTags: [String], definitionTags: [String]?, tagCache: [String: NSManagedObjectID], context: NSManagedObjectContext) {
        for tagName in termTags {
            if let tagObjectID = tagCache[tagName],
               let tagMeta = try? context.existingObject(with: tagObjectID) as? DictionaryTagMeta
            {
                termEntry.addToRichTermTags(tagMeta)
            }
        }

        if let definitionTags {
            for tagName in definitionTags {
                if let tagObjectID = tagCache[tagName],
                   let tagMeta = try? context.existingObject(with: tagObjectID) as? DictionaryTagMeta
                {
                    termEntry.addToRichDefinitionTags(tagMeta)
                }
            }
        }
    }

    static func linkTagsToKanjiEntryWithCache(_ kanjiEntry: KanjiEntry, tags: [String], tagCache: [String: NSManagedObjectID], context: NSManagedObjectContext) {
        for tagName in tags {
            if let tagObjectID = tagCache[tagName],
               let tagMeta = try? context.existingObject(with: tagObjectID) as? DictionaryTagMeta
            {
                kanjiEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToPitchEntryWithCache(_ pitchEntry: PitchAccentEntry, tags: [String], tagCache: [String: NSManagedObjectID], context: NSManagedObjectContext) {
        for tagName in tags {
            if let tagObjectID = tagCache[tagName],
               let tagMeta = try? context.existingObject(with: tagObjectID) as? DictionaryTagMeta
            {
                pitchEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToIPAEntryWithCache(_ ipaEntry: IPAEntry, tags: [String], tagCache: [String: NSManagedObjectID], context: NSManagedObjectContext) {
        for tagName in tags {
            if let tagObjectID = tagCache[tagName],
               let tagMeta = try? context.existingObject(with: tagObjectID) as? DictionaryTagMeta
            {
                ipaEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToTermEntry(_ termEntry: TermEntry, termTags: [String], definitionTags: [String]?, dictionary: Dictionary, context: NSManagedObjectContext) throws {
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

    static func findTagMeta(name: String, dictionary: Dictionary, context: NSManagedObjectContext) throws -> DictionaryTagMeta? {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND dictionary == %@", name, dictionary)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }

    static func linkTagsToPitchEntry(_ pitchEntry: PitchAccentEntry, tags: [String], dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link pitch accent tags
        for tagName in tags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                pitchEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToIPAEntry(_ ipaEntry: IPAEntry, tags: [String], dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link IPA tags
        for tagName in tags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                ipaEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func findOrCreateKanji(character: String, context: NSManagedObjectContext) throws -> Kanji {
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

    static func linkTagsToKanjiEntry(_ kanjiEntry: KanjiEntry, tags: [String], dictionary: Dictionary, context: NSManagedObjectContext) throws {
        // Link kanji tags
        for tagName in tags {
            if let tagMeta = try findTagMeta(name: tagName, dictionary: dictionary, context: context) {
                kanjiEntry.addToRichTags(tagMeta)
            }
        }
    }
}
