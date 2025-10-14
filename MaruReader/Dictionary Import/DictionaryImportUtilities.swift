//
//  DictionaryImportUtilities.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation

enum DictionaryImportUtilities {
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
}
