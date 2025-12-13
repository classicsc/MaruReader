//
//  GroupedSearchResults.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/26/25.
//

public struct GroupedSearchResults: Identifiable, Sendable {
    let termKey: String
    let expression: String
    let reading: String?
    let dictionariesResults: [DictionaryResults]
    let pitchAccentResults: [PitchAccentResults]
    let termTags: [Tag]
    let deinflectionInfo: String?
    let audioResults: TermAudioResults?

    public var id: String { termKey }

    public var displayTerm: String {
        if let reading, !reading.isEmpty {
            return "\(expression) [\(reading)]"
        }
        return expression
    }

    init(
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
