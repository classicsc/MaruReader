//
//  GroupedSearchResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

public struct GroupedSearchResults: Identifiable, Sendable {
    public let termKey: String
    public let expression: String
    public let reading: String?
    public let dictionariesResults: [DictionaryResults]
    public let pitchAccentResults: [PitchAccentResults]
    public let termTags: [Tag]
    public let deinflectionInfo: String?
    public let audioResults: TermAudioResults?

    public var id: String { termKey }

    public var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }

    public init(
        termKey: String,
        expression: String,
        reading: String?,
        dictionariesResults: [DictionaryResults],
        pitchAccentResults: [PitchAccentResults],
        termTags: [Tag],
        deinflectionInfo: String?,
        audioResults: TermAudioResults? = nil
    ) {
        self.termKey = termKey
        self.expression = expression
        self.reading = reading
        self.dictionariesResults = dictionariesResults
        self.pitchAccentResults = pitchAccentResults
        self.termTags = termTags
        self.deinflectionInfo = deinflectionInfo
        self.audioResults = audioResults
    }
}
