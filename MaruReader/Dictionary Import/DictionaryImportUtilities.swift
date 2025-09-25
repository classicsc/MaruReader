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

    static func prefetchDictionaryTags(dictionary: Dictionary, context: NSManagedObjectContext) throws -> [String: DictionaryTagMeta] {
        let request: NSFetchRequest<DictionaryTagMeta> = DictionaryTagMeta.fetchRequest()
        request.predicate = NSPredicate(format: "dictionary == %@", dictionary)

        let tags = try context.fetch(request)
        var tagCache: [String: DictionaryTagMeta] = [:]

        for tag in tags {
            if let name = tag.name {
                tagCache[name] = tag
            }
        }

        return tagCache
    }

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

    static func findOrCreateTermWithCache(expression: String, reading: String, cache: inout [String: Term], context: NSManagedObjectContext) throws -> Term {
        let key = "\(expression)|\(reading)"

        if let existingTerm = cache[key] {
            return existingTerm
        }

        let term = Term(context: context)
        term.id = UUID()
        term.expression = expression
        term.reading = reading
        context.insert(term)

        cache[key] = term
        return term
    }

    static func findOrCreateKanjiWithCache(character: String, cache: inout [String: Kanji], context: NSManagedObjectContext) throws -> Kanji {
        if let existingKanji = cache[character] {
            return existingKanji
        }

        let kanji = Kanji(context: context)
        kanji.id = UUID()
        kanji.character = character
        context.insert(kanji)

        cache[character] = kanji
        return kanji
    }

    static func linkTagsToTermEntryWithCache(_ termEntry: TermEntry, termTags: [String], definitionTags: [String]?, tagCache: [String: DictionaryTagMeta]) {
        for tagName in termTags {
            if let tagMeta = tagCache[tagName] {
                termEntry.addToRichTermTags(tagMeta)
            }
        }

        if let definitionTags {
            for tagName in definitionTags {
                if let tagMeta = tagCache[tagName] {
                    termEntry.addToRichDefinitionTags(tagMeta)
                }
            }
        }
    }

    static func linkTagsToKanjiEntryWithCache(_ kanjiEntry: KanjiEntry, tags: [String], tagCache: [String: DictionaryTagMeta]) {
        for tagName in tags {
            if let tagMeta = tagCache[tagName] {
                kanjiEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToPitchEntryWithCache(_ pitchEntry: PitchAccentEntry, tags: [String], tagCache: [String: DictionaryTagMeta]) {
        for tagName in tags {
            if let tagMeta = tagCache[tagName] {
                pitchEntry.addToRichTags(tagMeta)
            }
        }
    }

    static func linkTagsToIPAEntryWithCache(_ ipaEntry: IPAEntry, tags: [String], tagCache: [String: DictionaryTagMeta]) {
        for tagName in tags {
            if let tagMeta = tagCache[tagName] {
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
