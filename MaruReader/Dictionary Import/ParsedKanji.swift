import Foundation

///  Unified intermediate representation for Kanji entries (v1 & v3) prior to
///  Core Data batch insertion.
struct ParsedKanji {
    let character: String
    let onyomi: NSObject
    let kunyomi: NSObject
    let tags: NSObject
    let meanings: NSObject
    let stats: NSObject? // v3 only

    init(from entry: KanjiBankV1Entry) {
        self.character = entry.character
        let arrayTransformer = StringArrayTransformer()
        self.onyomi = (entry.onyomi.isEmpty ? nil : (arrayTransformer.transformedValue(entry.onyomi) as? NSObject)) ?? Data() as NSObject
        self.kunyomi = (entry.kunyomi.isEmpty ? nil : (arrayTransformer.transformedValue(entry.kunyomi) as? NSObject)) ?? Data() as NSObject
        self.tags = (entry.tags.isEmpty ? nil : (arrayTransformer.transformedValue(entry.tags) as? NSObject)) ?? Data() as NSObject
        self.meanings = (entry.meanings.isEmpty ? nil : (arrayTransformer.transformedValue(entry.meanings) as? NSObject)) ?? Data() as NSObject
        self.stats = nil // Not present in v1 schema
    }

    init(from entry: KanjiBankV3Entry) {
        self.character = entry.character
        let arrayTransformer = StringArrayTransformer()
        self.onyomi = (entry.onyomi.isEmpty ? nil : (arrayTransformer.transformedValue(entry.onyomi) as? NSObject)) ?? Data() as NSObject
        self.kunyomi = (entry.kunyomi.isEmpty ? nil : (arrayTransformer.transformedValue(entry.kunyomi) as? NSObject)) ?? Data() as NSObject
        self.tags = (entry.tags.isEmpty ? nil : (arrayTransformer.transformedValue(entry.tags) as? NSObject)) ?? Data() as NSObject
        self.meanings = (entry.meanings.isEmpty ? nil : (arrayTransformer.transformedValue(entry.meanings) as? NSObject)) ?? Data() as NSObject
        // stats always exists in v3 entry (may be empty dictionary)
        let dictTransformer = StringDictionaryTransformer()
        self.stats = entry.stats.isEmpty ? nil : (dictTransformer.transformedValue(entry.stats) as? NSObject)
    }
}
