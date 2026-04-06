// StreamingBankTokenDecoding.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

internal import JsonStream
import Foundation
import MaruReaderCore

protocol StreamingBankTokenDecodable: DictionaryDataBankEntry {
    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> Self
}

private struct EntryTokenArrayReader {
    private let stream: JsonInputStream
    private var reachedEnd = false

    init(stream: JsonInputStream, firstToken: JsonToken) throws {
        guard case .startArray = firstToken else {
            throw DictionaryImportError.invalidData
        }

        self.stream = stream
    }

    mutating func readRequiredString() throws -> String {
        guard case let .string(_, value) = try requireToken() else {
            throw DictionaryImportError.invalidData
        }

        return value
    }

    mutating func readOptionalString() throws -> String? {
        let token = try requireToken()

        switch token {
        case let .string(_, value):
            return value
        case .null:
            return nil
        default:
            throw DictionaryImportError.invalidData
        }
    }

    mutating func readRequiredDouble() throws -> Double {
        guard case let .number(_, value) = try requireToken() else {
            throw DictionaryImportError.invalidData
        }

        return value.doubleValue
    }

    mutating func readRequiredInt() throws -> Int {
        guard case let .number(_, value) = try requireToken(), let intValue = value.intValue else {
            throw DictionaryImportError.invalidData
        }

        return intValue
    }

    mutating func readStringArray() throws -> [String] {
        let value = try readJSONValue()
        guard let strings = value.stringArray else {
            throw DictionaryImportError.invalidData
        }

        return strings
    }

    mutating func readStringDictionary() throws -> [String: String] {
        let value = try readJSONValue()
        guard let dictionary = value.stringDictionary else {
            throw DictionaryImportError.invalidData
        }

        return dictionary
    }

    mutating func readJSONValue() throws -> StreamingJSONValue {
        try StreamingJSONValue.read(from: stream, firstToken: requireToken())
    }

    mutating func readStreamingGlossaryJSON() throws -> (jsonData: Data, definitionCount: Int) {
        var jsonData = Data()
        guard let kind = try stream.appendRawValue(to: &jsonData), kind == .array else {
            throw DictionaryImportError.invalidData
        }

        let definitionCount = try RawGlossaryArrayInspector.inspect(
            jsonData,
            allowedKinds: Set<JsonRawValueKind>([.string, .array, .object])
        )
        return (jsonData, definitionCount)
    }

    mutating func readRemainingStringGlossaryJSON() throws -> (jsonData: Data, definitionCount: Int) {
        var jsonData = Data("[".utf8)
        var definitionCount = 0

        while true {
            let commaStart = jsonData.count
            if definitionCount > 0 {
                jsonData.append(Data(",".utf8))
            }

            guard let kind = try stream.appendRawValue(to: &jsonData) else {
                if definitionCount > 0 {
                    jsonData.removeSubrange(commaStart ..< jsonData.count)
                }
                break
            }

            guard kind == .string else {
                throw DictionaryImportError.invalidData
            }

            definitionCount += 1
        }

        jsonData.append(Data("]".utf8))
        return (jsonData, definitionCount)
    }

    mutating func nextValueToken() throws -> JsonToken? {
        guard !reachedEnd else {
            return nil
        }

        guard let token = try stream.read() else {
            throw DictionaryImportError.invalidData
        }

        if case .endArray = token {
            reachedEnd = true
            return nil
        }

        return token
    }

    mutating func finish() throws {
        guard try nextValueToken() == nil else {
            throw DictionaryImportError.invalidData
        }
    }

    private mutating func requireToken() throws -> JsonToken {
        guard let token = try nextValueToken() else {
            throw DictionaryImportError.invalidData
        }

        return token
    }
}

private enum StreamingJSONValue {
    case object([String: StreamingJSONValue])
    case array([StreamingJSONValue])
    case string(String)
    case number(JsonNumber)
    case bool(Bool)
    case null

    static func read(from stream: JsonInputStream, firstToken: JsonToken) throws -> StreamingJSONValue {
        switch firstToken {
        case .startObject:
            return try .object(readObject(from: stream))
        case .startArray:
            return try .array(readArray(from: stream))
        case let .string(_, value):
            return .string(value)
        case let .number(_, value):
            return .number(value)
        case let .bool(_, value):
            return .bool(value)
        case .null:
            return .null
        case .endArray, .endObject:
            throw DictionaryImportError.invalidData
        }
    }

    private static func readObject(from stream: JsonInputStream) throws -> [String: StreamingJSONValue] {
        var object: [String: StreamingJSONValue] = [:]

        while let token = try stream.read() {
            switch token {
            case .endObject:
                return object
            case let .startObject(key):
                try object[key.requirePropertyName()] = try .read(from: stream, firstToken: .startObject(key))
            case let .startArray(key):
                try object[key.requirePropertyName()] = try .read(from: stream, firstToken: .startArray(key))
            case let .string(key, value):
                try object[key.requirePropertyName()] = .string(value)
            case let .number(key, value):
                try object[key.requirePropertyName()] = .number(value)
            case let .bool(key, value):
                try object[key.requirePropertyName()] = .bool(value)
            case let .null(key):
                try object[key.requirePropertyName()] = .null
            case .endArray:
                throw DictionaryImportError.invalidData
            }
        }

        throw DictionaryImportError.invalidData
    }

    private static func readArray(from stream: JsonInputStream) throws -> [StreamingJSONValue] {
        var array: [StreamingJSONValue] = []

        while let token = try stream.read() {
            switch token {
            case .endArray:
                return array
            default:
                try array.append(.read(from: stream, firstToken: token))
            }
        }

        throw DictionaryImportError.invalidData
    }

    private static func jsonNumber(from number: NSNumber) -> JsonNumber {
        if CFNumberIsFloatType(number) {
            return .double(number.doubleValue)
        }

        return .int(number.int64Value)
    }
}

private extension JsonKey? {
    func requirePropertyName() throws -> String {
        guard let self else {
            throw DictionaryImportError.invalidData
        }

        guard case let .name(name) = self else {
            throw DictionaryImportError.invalidData
        }

        return name
    }
}

private extension JsonNumber {
    var doubleValue: Double {
        switch self {
        case let .int(value):
            Double(value)
        case let .double(value):
            value
        case let .decimal(value):
            NSDecimalNumber(decimal: value).doubleValue
        }
    }

    var intValue: Int? {
        switch self {
        case let .int(value):
            return Int(exactly: value)
        case let .double(value):
            guard value.isFinite, value >= Double(Int64.min), value <= Double(Int64.max) else {
                return nil
            }

            let intValue = Int64(value)
            guard Double(intValue) == value else {
                return nil
            }

            return Int(exactly: intValue)
        case let .decimal(value):
            let decimalNumber = NSDecimalNumber(decimal: value)
            let intValue = decimalNumber.int64Value
            guard NSDecimalNumber(value: intValue).compare(decimalNumber) == .orderedSame else {
                return nil
            }

            return Int(exactly: intValue)
        }
    }
}

private extension StreamingJSONValue {
    var objectValue: [String: StreamingJSONValue]? {
        guard case let .object(value) = self else {
            return nil
        }

        return value
    }

    var arrayValue: [StreamingJSONValue]? {
        guard case let .array(value) = self else {
            return nil
        }

        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }

        return value
    }

    var doubleValue: Double? {
        guard case let .number(value) = self else {
            return nil
        }

        return value.doubleValue
    }

    var intValue: Int? {
        guard case let .number(value) = self else {
            return nil
        }

        return value.intValue
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else {
            return nil
        }

        return value
    }

    var stringArray: [String]? {
        guard let arrayValue else {
            return nil
        }

        var strings: [String] = []
        strings.reserveCapacity(arrayValue.count)

        for value in arrayValue {
            guard let string = value.stringValue else {
                return nil
            }
            strings.append(string)
        }

        return strings
    }

    var intArray: [Int]? {
        guard let arrayValue else {
            return nil
        }

        var ints: [Int] = []
        ints.reserveCapacity(arrayValue.count)

        for value in arrayValue {
            guard let intValue = value.intValue else {
                return nil
            }
            ints.append(intValue)
        }

        return ints
    }

    var stringDictionary: [String: String]? {
        guard let objectValue else {
            return nil
        }

        var dictionary: [String: String] = [:]
        dictionary.reserveCapacity(objectValue.count)

        for (key, value) in objectValue {
            guard let string = value.stringValue else {
                return nil
            }
            dictionary[key] = string
        }

        return dictionary
    }

    func jsonData() throws -> Data {
        try JSONSerialization.data(withJSONObject: foundationObject, options: .fragmentsAllowed)
    }

    private var foundationObject: Any {
        switch self {
        case let .object(value):
            value.mapValues(\.foundationObject)
        case let .array(value):
            value.map(\.foundationObject)
        case let .string(value):
            value
        case let .number(value):
            switch value {
            case let .int(number):
                number
            case let .double(number):
                number
            case let .decimal(number):
                NSDecimalNumber(decimal: number)
            }
        case let .bool(value):
            value
        case .null:
            NSNull()
        }
    }
}

private extension Definition {
    static func decodeStreaming(from value: StreamingJSONValue) throws -> Definition {
        switch value {
        case let .string(text):
            return .text(text)
        case let .array(array):
            guard
                array.count >= 2,
                let uninflected = array[0].stringValue,
                let rules = array[1].stringArray
            else {
                throw DictionaryImportError.invalidData
            }

            return .deinflection(uninflected: uninflected, rules: rules)
        case .object:
            return try JSONDecoder().decode(Definition.self, from: value.jsonData())
        case .number, .bool, .null:
            throw DictionaryImportError.invalidData
        }
    }
}

private extension KanjiFrequency {
    static func decodeStreaming(from value: StreamingJSONValue) throws -> KanjiFrequency {
        if let number = value.doubleValue {
            return .number(number)
        }

        if let string = value.stringValue {
            return .string(string)
        }

        guard let object = value.objectValue else {
            throw DictionaryImportError.invalidData
        }

        guard let numericValue = object["value"]?.doubleValue else {
            throw DictionaryImportError.invalidData
        }

        let displayValue = object["displayValue"]?.stringValue
        return .object(value: numericValue, displayValue: displayValue)
    }
}

private extension FrequencyData {
    init(value: Double, displayValue: String?) {
        self.value = value
        self.displayValue = displayValue
    }

    static func decodeStreaming(from value: StreamingJSONValue) throws -> FrequencyData {
        if let number = value.doubleValue {
            return FrequencyData(value: number, displayValue: nil)
        }

        if let string = value.stringValue {
            return FrequencyData(value: Double(string) ?? 0.0, displayValue: string)
        }

        guard let object = value.objectValue else {
            throw DictionaryImportError.invalidData
        }

        guard let numericValue = object["value"]?.doubleValue else {
            throw DictionaryImportError.invalidData
        }

        return FrequencyData(value: numericValue, displayValue: object["displayValue"]?.stringValue)
    }
}

private extension PitchAccent {
    static func decodeStreaming(from value: StreamingJSONValue) throws -> PitchAccent {
        guard let object = value.objectValue else {
            throw DictionaryImportError.invalidData
        }

        let position: PitchPosition
        if let mora = object["position"]?.intValue {
            position = .mora(mora)
        } else if let pattern = object["position"]?.stringValue {
            position = .pattern(pattern)
        } else {
            throw DictionaryImportError.invalidData
        }

        let nasal = try decodeOptionalIntArray(object["nasal"])
        let devoice = try decodeOptionalIntArray(object["devoice"])
        let tags = try decodeOptionalStringArray(object["tags"])

        return PitchAccent(position: position, nasal: nasal, devoice: devoice, tags: tags)
    }

    private static func decodeOptionalIntArray(_ value: StreamingJSONValue?) throws -> [Int]? {
        guard let value else {
            return nil
        }

        if let intValue = value.intValue {
            return [intValue]
        }

        guard let ints = value.intArray else {
            throw DictionaryImportError.invalidData
        }

        return ints
    }

    private static func decodeOptionalStringArray(_ value: StreamingJSONValue?) throws -> [String]? {
        guard let value else {
            return nil
        }

        guard let strings = value.stringArray else {
            throw DictionaryImportError.invalidData
        }

        return strings
    }
}

private extension IPATranscription {
    static func decodeStreaming(from value: StreamingJSONValue) throws -> IPATranscription {
        guard let object = value.objectValue, let ipa = object["ipa"]?.stringValue else {
            throw DictionaryImportError.invalidData
        }

        if let tagsValue = object["tags"] {
            guard let tags = tagsValue.stringArray else {
                throw DictionaryImportError.invalidData
            }

            return IPATranscription(ipa: ipa, tags: tags)
        }

        return IPATranscription(ipa: ipa)
    }
}

private extension TermMetaBankV3Entry {
    init(term: String, kind: Kind, data: TermMetaEntryData) {
        self.term = term
        self.kind = kind
        self.data = data
    }

    static func decodeFrequencyEntry(from value: StreamingJSONValue) throws -> TermMetaEntryData {
        if let object = value.objectValue, object["value"] == nil {
            guard
                let reading = object["reading"]?.stringValue,
                let frequencyValue = object["frequency"]
            else {
                throw DictionaryImportError.invalidData
            }

            return try .frequencyWithReading(ReadingFrequencyData(
                reading: reading,
                frequency: FrequencyData.decodeStreaming(from: frequencyValue)
            ))
        }

        return try .frequency(FrequencyData.decodeStreaming(from: value))
    }

    static func decodePitchEntry(from value: StreamingJSONValue) throws -> TermMetaEntryData {
        guard
            let object = value.objectValue,
            let reading = object["reading"]?.stringValue,
            let pitchesValue = object["pitches"]?.arrayValue
        else {
            throw DictionaryImportError.invalidData
        }

        return try .pitch(PitchData(
            reading: reading,
            pitches: pitchesValue.map { try PitchAccent.decodeStreaming(from: $0) }
        ))
    }

    static func decodeIPAEntry(from value: StreamingJSONValue) throws -> TermMetaEntryData {
        guard
            let object = value.objectValue,
            let reading = object["reading"]?.stringValue,
            let transcriptionValues = object["transcriptions"]?.arrayValue
        else {
            throw DictionaryImportError.invalidData
        }

        return try .ipa(IPAData(
            reading: reading,
            transcriptions: transcriptionValues.map { try IPATranscription.decodeStreaming(from: $0) }
        ))
    }
}

extension TermBankV1Entry: StreamingBankTokenDecodable {
    init(expression: String, reading: String, definitionTags: [String], rules: [String], score: Double, glossary: [Definition]) {
        self.expression = expression
        self.reading = reading
        self.definitionTags = definitionTags
        self.rules = rules
        self.score = score
        self.glossaryStorage = TermGlossaryStorage(definitions: glossary)
    }

    init(
        expression: String,
        reading: String,
        definitionTags: [String],
        rules: [String],
        score: Double,
        glossaryJSON: Data,
        definitionCount: Int
    ) {
        self.expression = expression
        self.reading = reading
        self.definitionTags = definitionTags
        self.rules = rules
        self.score = score
        self.glossaryStorage = TermGlossaryStorage(glossaryJSON: glossaryJSON, definitionCount: definitionCount)
    }

    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> TermBankV1Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let expression = try reader.readRequiredString()
        let reading = try reader.readRequiredString()
        let definitionTagsRaw = try reader.readRequiredString()
        let rulesRaw = try reader.readRequiredString()
        let score = try reader.readRequiredDouble()

        let glossary = try reader.readRemainingStringGlossaryJSON()

        return TermBankV1Entry(
            expression: expression,
            reading: reading,
            definitionTags: splitSpaceSeparated(definitionTagsRaw),
            rules: splitSpaceSeparated(rulesRaw),
            score: score,
            glossaryJSON: glossary.jsonData,
            definitionCount: glossary.definitionCount
        )
    }
}

extension TermBankV3Entry: StreamingBankTokenDecodable {
    init(expression: String, reading: String, definitionTags: [String]?, rules: [String], score: Double, glossary: [Definition], sequence: Int, termTags: [String]) {
        self.expression = expression
        self.reading = reading
        self.definitionTags = definitionTags
        self.rules = rules
        self.score = score
        self.glossaryStorage = TermGlossaryStorage(definitions: glossary)
        self.sequence = sequence
        self.termTags = termTags
    }

    init(
        expression: String,
        reading: String,
        definitionTags: [String]?,
        rules: [String],
        score: Double,
        glossaryJSON: Data,
        definitionCount: Int,
        sequence: Int,
        termTags: [String]
    ) {
        self.expression = expression
        self.reading = reading
        self.definitionTags = definitionTags
        self.rules = rules
        self.score = score
        self.glossaryStorage = TermGlossaryStorage(glossaryJSON: glossaryJSON, definitionCount: definitionCount)
        self.sequence = sequence
        self.termTags = termTags
    }

    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> TermBankV3Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let expression = try reader.readRequiredString()
        let reading = try reader.readRequiredString()
        let definitionTagsRaw = try reader.readOptionalString()
        let rulesRaw = try reader.readRequiredString()
        let score = try reader.readRequiredDouble()

        let glossary = try reader.readStreamingGlossaryJSON()
        let sequence = try reader.readRequiredInt()
        let termTagsRaw = try reader.readRequiredString()
        try reader.finish()

        let definitionTags = definitionTagsRaw.map { $0.isEmpty ? [] : splitWhitespace($0) }

        return TermBankV3Entry(
            expression: expression,
            reading: reading,
            definitionTags: definitionTags,
            rules: rulesRaw.isEmpty ? [] : splitWhitespace(rulesRaw),
            score: score,
            glossaryJSON: glossary.jsonData,
            definitionCount: glossary.definitionCount,
            sequence: sequence,
            termTags: termTagsRaw.isEmpty ? [] : splitWhitespace(termTagsRaw)
        )
    }
}

extension KanjiBankV1Entry: StreamingBankTokenDecodable {
    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> KanjiBankV1Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let character = try reader.readRequiredString()
        let onyomiRaw = try reader.readRequiredString()
        let kunyomiRaw = try reader.readRequiredString()
        let tagsRaw = try reader.readRequiredString()

        var meanings: [String] = []
        while let token = try reader.nextValueToken() {
            guard case let .string(_, meaning) = token else {
                throw DictionaryImportError.invalidData
            }

            meanings.append(meaning)
        }

        return KanjiBankV1Entry(
            character: character,
            onyomi: splitWhitespace(onyomiRaw),
            kunyomi: splitWhitespace(kunyomiRaw),
            tags: splitWhitespace(tagsRaw),
            meanings: meanings
        )
    }
}

extension KanjiBankV3Entry: StreamingBankTokenDecodable {
    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> KanjiBankV3Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let character = try reader.readRequiredString()
        let onyomiRaw = try reader.readRequiredString()
        let kunyomiRaw = try reader.readRequiredString()
        let tagsRaw = try reader.readRequiredString()
        let meanings = try reader.readStringArray()
        let stats = try reader.readStringDictionary()
        try reader.finish()

        return KanjiBankV3Entry(
            character: character,
            onyomi: splitWhitespace(onyomiRaw),
            kunyomi: splitWhitespace(kunyomiRaw),
            tags: splitWhitespace(tagsRaw),
            meanings: meanings,
            stats: stats
        )
    }
}

extension TagBankV3Entry: StreamingBankTokenDecodable {
    init(name: String, category: String, order: Double, notes: String, score: Double) {
        self.name = name
        self.category = category
        self.order = order
        self.notes = notes
        self.score = score
    }

    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> TagBankV3Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let name = try reader.readRequiredString()
        let category = try reader.readRequiredString()
        let order = try reader.readRequiredDouble()
        let notes = try reader.readRequiredString()
        let score = try reader.readRequiredDouble()
        try reader.finish()

        return TagBankV3Entry(name: name, category: category, order: order, notes: notes, score: score)
    }
}

extension KanjiMetaBankV3Entry: StreamingBankTokenDecodable {
    init(kanji: String, type: String, frequency: KanjiFrequency) {
        self.kanji = kanji
        self.type = type
        self.frequency = frequency
    }

    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> KanjiMetaBankV3Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let kanji = try reader.readRequiredString()
        let type = try reader.readRequiredString()
        let frequency = try KanjiFrequency.decodeStreaming(from: reader.readJSONValue())
        try reader.finish()

        guard type == "freq" else {
            throw DictionaryImportError.invalidData
        }

        return KanjiMetaBankV3Entry(kanji: kanji, type: type, frequency: frequency)
    }
}

extension TermMetaBankV3Entry: StreamingBankTokenDecodable {
    static func decodeStreaming(from stream: JsonInputStream, firstToken: JsonToken) throws -> TermMetaBankV3Entry {
        var reader = try EntryTokenArrayReader(stream: stream, firstToken: firstToken)

        let term = try reader.readRequiredString()
        let kindRawValue = try reader.readRequiredString()
        let dataValue = try reader.readJSONValue()
        try reader.finish()

        guard let kind = Kind(rawValue: kindRawValue) else {
            throw DictionaryImportError.invalidData
        }

        let data: TermMetaEntryData = switch kind {
        case .freq:
            try decodeFrequencyEntry(from: dataValue)
        case .pitch:
            try decodePitchEntry(from: dataValue)
        case .ipa:
            try decodeIPAEntry(from: dataValue)
        }

        return TermMetaBankV3Entry(term: term, kind: kind, data: data)
    }
}

private func splitWhitespace(_ string: String) -> [String] {
    string.split { $0 == " " || $0 == "\t" || $0 == "\n" }.map(String.init)
}

private func splitSpaceSeparated(_ string: String) -> [String] {
    splitWhitespace(string)
}
