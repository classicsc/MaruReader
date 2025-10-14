//  CoreDataTransformers.swift
//  MaruReader
//
//  Created by Sam Smoker on 09/07/25.
//
//  Value transformers for storing dictionary import model components in Core Data
//  as Transformable attributes. Add corresponding transformer names to the
//  data model attributes (Custom Value Transformer Name).

import CoreData
import Foundation
import ReadiumNavigator

// MARK: - Transformer Names

extension NSValueTransformerName {
    static let stringArrayTransformer = NSValueTransformerName("StringArrayTransformer")
    static let stringDictionaryTransformer = NSValueTransformerName("StringDictionaryTransformer")
    static let definitionArrayTransformer = NSValueTransformerName("DefinitionArrayTransformer")
    static let termMetaEntryDataTransformer = NSValueTransformerName("TermMetaEntryDataTransformer")
    static let urlArrayTransformer = NSValueTransformerName("URLArrayTransformer")
    static let pitchAccentArrayTransformer = NSValueTransformerName("PitchAccentArrayTransformer")
    static let ipaTranscriptionArrayTransformer = NSValueTransformerName("IPATranscriptionArrayTransformer")
    static let intArrayTransformer = NSValueTransformerName("IntArrayTransformer")
    static let readiumColorTransformer = NSValueTransformerName("ReadiumColorTransformer")
    static let readingProgressionTransformer = NSValueTransformerName("ReadingProgressionTransformer")
    static let imageFilterTransformer = NSValueTransformerName("ImageFilterTransformer")
}

// MARK: - Registration Helper

enum CoreDataTransformers {
    static func register() {
        // Idempotent registration (setValueTransformer replaces any existing one with same name)
        ValueTransformer.setValueTransformer(StringArrayTransformer(), forName: .stringArrayTransformer)
        ValueTransformer.setValueTransformer(StringDictionaryTransformer(), forName: .stringDictionaryTransformer)
        ValueTransformer.setValueTransformer(DefinitionArrayTransformer(), forName: .definitionArrayTransformer)
        ValueTransformer.setValueTransformer(TermMetaEntryDataTransformer(), forName: .termMetaEntryDataTransformer)
        ValueTransformer.setValueTransformer(URLArrayTransformer(), forName: .urlArrayTransformer)
        ValueTransformer.setValueTransformer(PitchAccentArrayTransformer(), forName: .pitchAccentArrayTransformer)
        ValueTransformer.setValueTransformer(IPATranscriptionArrayTransformer(), forName: .ipaTranscriptionArrayTransformer)
        ValueTransformer.setValueTransformer(IntArrayTransformer(), forName: .intArrayTransformer)
        ValueTransformer.setValueTransformer(ReadiumColorTransformer(), forName: .readiumColorTransformer)
        ValueTransformer.setValueTransformer(ReadingProgressionTransformer(), forName: .readingProgressionTransformer)
        ValueTransformer.setValueTransformer(ImageFilterTransformer(), forName: .imageFilterTransformer)
    }
}

// MARK: - Base JSON Transformer

class JSONValueTransformer<Input>: ValueTransformer where Input: Codable {
    override class func allowsReverseTransformation() -> Bool { true }
    override class func transformedValueClass() -> AnyClass { NSData.self }

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        // Stable key ordering not guaranteed but fine for persistence; pretty printing unnecessary
        return enc
    }()

    private let decoder = JSONDecoder()

    override func transformedValue(_ value: Any?) -> Any? {
        guard let typed = value as? Input else { return nil }
        do { return try encoder.encode(typed) } catch { return nil }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do { return try decoder.decode(Input.self, from: data) } catch { return nil }
    }
}

// MARK: - Concrete Transformers

final class StringArrayTransformer: JSONValueTransformer<[String]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class StringDictionaryTransformer: JSONValueTransformer<[String: String]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class DefinitionArrayTransformer: JSONValueTransformer<[Definition]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class TermMetaEntryDataTransformer: JSONValueTransformer<TermMetaEntryData> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class URLArrayTransformer: JSONValueTransformer<[URL]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class PitchAccentArrayTransformer: JSONValueTransformer<[PitchAccent]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class IPATranscriptionArrayTransformer: JSONValueTransformer<[IPATranscription]> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class IntArrayTransformer: JSONValueTransformer<[Int]> {
    // Nothing extra needed; subclass exists to provide unique name
}

// MARK: - Readium Type Transformers

final class ReadiumColorTransformer: JSONValueTransformer<ReadiumNavigator.Color> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class ReadingProgressionTransformer: JSONValueTransformer<ReadiumNavigator.ReadingProgression> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class ImageFilterTransformer: JSONValueTransformer<ReadiumNavigator.ImageFilter> {
    // Nothing extra needed; subclass exists to provide unique name
}
