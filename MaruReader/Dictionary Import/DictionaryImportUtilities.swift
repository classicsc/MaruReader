//
//  DictionaryImportUtilities.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/21/25.
//

import CoreData
import Foundation

enum DictionaryImportUtilities {
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
}
