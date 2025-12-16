//
//  TextLookupResponseTemplateResolver.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/15/25.
//

import Foundation
import MaruReaderCore

/// Resolves template values from a `TextLookupResponse` and a selected term group.
///
/// This implementation extracts values from dictionary search results and the original
/// lookup request context to populate Anki note fields.
public struct TextLookupResponseTemplateResolver: TemplateValueResolver {
    private let response: TextLookupResponse
    private let selectedGroup: GroupedSearchResults
    private let selectedDictionaryID: UUID?

    /// Creates a resolver for the given response and selected term.
    ///
    /// - Parameters:
    ///   - response: The search response containing all results and context.
    ///   - selectedGroup: The specific term group to extract values from.
    ///   - selectedDictionaryID: Optional dictionary ID to prefer for dictionary-specific values.
    public init(
        response: TextLookupResponse,
        selectedGroup: GroupedSearchResults,
        selectedDictionaryID: UUID? = nil
    ) {
        self.response = response
        self.selectedGroup = selectedGroup
        self.selectedDictionaryID = selectedDictionaryID
    }

    public func resolve(_ templateValue: TemplateValue) async -> TemplateResolvedValue {
        switch templateValue {
        // MARK: - Simple values from search results

        case .expression:
            return .text(selectedGroup.expression)

        case .reading:
            return .text(selectedGroup.reading)

        case .character:
            // First character of expression (typically kanji)
            return .text(selectedGroup.expression.first.map(String.init))

        // MARK: - Context values from request

        case .sentence:
            return .text(response.context)

        case .documentTitle:
            return .text(response.request.contextValues?.documentTitle)

        case .documentURL:
            return .text(response.request.contextValues?.documentURL?.absoluteString)

        case .documentCoverImage:
            if let url = response.request.contextValues?.documentCoverImageURL {
                let fileID = "cover_\(UUID().uuidString)"
                return TemplateResolvedValue(mediaFiles: [fileID: url])
            }
            return .empty

        case .screenshot:
            if let url = response.request.contextValues?.screenshotURL {
                let fileID = "screenshot_\(UUID().uuidString)"
                return TemplateResolvedValue(mediaFiles: [fileID: url])
            }
            return .empty

        // MARK: - Cloze deletion values

        case .clozePrefix:
            return resolveClozePrefix()

        case .clozeBody:
            return .text(response.primaryResult)

        case .clozeSuffix:
            return resolveClozeSuffix()

        // MARK: - Conjugation/deinflection

        case .conjugation:
            return .text(selectedGroup.deinflectionInfo)

        // MARK: - Furigana

        case .furigana:
            return resolveFurigana()

        case .sentenceFurigana:
            // For now, return plain context - full furigana support requires sentence parsing
            return .text(response.context)

        // MARK: - Tags and part of speech

        case .partOfSpeech:
            return resolvePartOfSpeech()

        case .tags:
            return resolveTags()

        // MARK: - Dictionary glossary values

        case let .singleDictionaryGlossary(dictionaryID):
            return resolveGlossary(forDictionary: dictionaryID)

        case .multiDictionaryGlossary:
            return resolveMultiDictionaryGlossary()

        case .glossaryNoDictionary:
            return resolveGlossaryNoDictionary()

        case .dictionaryTitle:
            return resolveDictionaryTitle()

        // MARK: - Audio

        case .pronunciationAudio:
            return resolvePronunciationAudio()

        // MARK: - Pitch accent

        case .singlePitchAccent:
            return resolveSinglePitchAccent()

        case let .singlePitchAccentDictionary(dictionaryID):
            return resolvePitchAccent(forDictionary: dictionaryID)

        case .pitchAccentList:
            return resolvePitchAccentList()

        case .pitchAccentDisambiguation:
            return resolvePitchAccentDisambiguation()

        // MARK: - Frequency

        case .frequencyList:
            return resolveFrequencyList()

        case .singleFrequency:
            return resolveSingleFrequency()

        case let .singleFrequencyDictionary(dictionaryID):
            return resolveFrequency(forDictionary: dictionaryID)

        case let .frequencySortField(dictionaryID):
            return resolveFrequencySortField(forDictionary: dictionaryID)

        // MARK: - Kanji-specific (not implemented for term lookups)

        case .kunyomi, .onyomi, .onyomiAsHiragana, .strokeCount:
            // These are kanji-specific and not applicable to term lookups
            return .empty

        // MARK: - Custom value passthrough

        case let .customHTMLValue(value):
            return .text(value)

        @unknown default:
            return .empty
        }
    }

    // MARK: - Private Resolution Helpers

    private func resolveClozePrefix() -> TemplateResolvedValue {
        let context = response.context
        let range = response.primaryResultSourceRange
        guard range.lowerBound >= context.startIndex else {
            return .text("")
        }
        let prefix = String(context[context.startIndex ..< range.lowerBound])
        return .text(prefix)
    }

    private func resolveClozeSuffix() -> TemplateResolvedValue {
        let context = response.context
        let range = response.primaryResultSourceRange
        guard range.upperBound <= context.endIndex else {
            return .text("")
        }
        let suffix = String(context[range.upperBound ..< context.endIndex])
        return .text(suffix)
    }

    private func resolveFurigana() -> TemplateResolvedValue {
        guard let reading = selectedGroup.reading, !reading.isEmpty else {
            return .text(selectedGroup.expression)
        }
        // Simple bracket format: expression[reading]
        return .text("\(selectedGroup.expression)[\(reading)]")
    }

    private func resolvePartOfSpeech() -> TemplateResolvedValue {
        let posTags = selectedGroup.termTags.filter { $0.category == "partOfSpeech" }
        let posString = posTags.map(\.name).joined(separator: ", ")
        return .text(posString.isEmpty ? nil : posString)
    }

    private func resolveTags() -> TemplateResolvedValue {
        let tagNames = selectedGroup.termTags.map(\.name)
        return .text(tagNames.isEmpty ? nil : tagNames.joined(separator: " "))
    }

    private func resolveGlossary(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        guard let dictResult = selectedGroup.dictionariesResults.first(where: { $0.dictionaryUUID == dictionaryID }) else {
            return .empty
        }
        return .text(dictResult.combinedHTML)
    }

    private func resolveMultiDictionaryGlossary() -> TemplateResolvedValue {
        let html = selectedGroup.dictionariesResults.map { dictResult in
            """
            <div class="dictionary-entry">
                <h3>\(dictResult.dictionaryTitle.escapingHTML())</h3>
                \(dictResult.combinedHTML)
            </div>
            """
        }.joined(separator: "\n")
        return .text(html)
    }

    private func resolveGlossaryNoDictionary() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first else {
            return .empty
        }
        return .text(firstDict.combinedHTML)
    }

    private func resolveDictionaryTitle() -> TemplateResolvedValue {
        if let dictionaryID = selectedDictionaryID,
           let dictResult = selectedGroup.dictionariesResults.first(where: { $0.dictionaryUUID == dictionaryID })
        {
            return .text(dictResult.dictionaryTitle)
        }
        return .text(selectedGroup.dictionariesResults.first?.dictionaryTitle)
    }

    private func resolvePronunciationAudio() -> TemplateResolvedValue {
        guard let audioResults = selectedGroup.audioResults,
              let primaryURL = audioResults.primaryAudioURL
        else {
            return .empty
        }
        let fileID = "audio_\(UUID().uuidString)"
        return TemplateResolvedValue(mediaFiles: [fileID: primaryURL])
    }

    private func resolveSinglePitchAccent() -> TemplateResolvedValue {
        guard let firstPitch = selectedGroup.pitchAccentResults.first,
              let pitch = firstPitch.pitches.first
        else {
            return .empty
        }
        return .text(formatPitchAccent(pitch))
    }

    private func resolvePitchAccent(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        guard let pitchResult = selectedGroup.pitchAccentResults.first(where: { $0.dictionaryID == dictionaryID }),
              let pitch = pitchResult.pitches.first
        else {
            return .empty
        }
        return .text(formatPitchAccent(pitch))
    }

    private func resolvePitchAccentList() -> TemplateResolvedValue {
        let pitchStrings = selectedGroup.pitchAccentResults.flatMap { result in
            result.pitches.map { formatPitchAccent($0) }
        }
        return .text(pitchStrings.isEmpty ? nil : pitchStrings.joined(separator: ", "))
    }

    private func resolvePitchAccentDisambiguation() -> TemplateResolvedValue {
        let pitchInfo = selectedGroup.pitchAccentResults.map { result in
            let pitches = result.pitches.map { formatPitchAccent($0) }.joined(separator: "/")
            return "\(result.dictionaryTitle): \(pitches)"
        }
        return .text(pitchInfo.isEmpty ? nil : pitchInfo.joined(separator: "; "))
    }

    private func formatPitchAccent(_ pitch: PitchAccent) -> String {
        switch pitch.position {
        case let .mora(position):
            return String(position)
        case let .pattern(pattern):
            return pattern
        @unknown default:
            return ""
        }
    }

    private func resolveFrequencyList() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            return .empty
        }
        let freqStrings = firstResult.frequencies.map { freq in
            "\(freq.dictionaryTitle): \(Int(freq.value))"
        }
        return .text(freqStrings.isEmpty ? nil : freqStrings.joined(separator: ", "))
    }

    private func resolveSingleFrequency() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first,
              let frequency = firstResult.frequency
        else {
            return .empty
        }
        return .text(String(Int(frequency)))
    }

    private func resolveFrequency(forDictionary _: UUID) -> TemplateResolvedValue {
        // Note: FrequencyInfo doesn't currently have dictionary ID, so we use the first frequency
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first,
              let freq = firstResult.frequencies.first
        else {
            return .empty
        }
        return .text(String(Int(freq.value)))
    }

    private func resolveFrequencySortField(forDictionary _: UUID) -> TemplateResolvedValue {
        // Return raw numeric value for sorting
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first,
              let frequency = firstResult.frequency
        else {
            return .text("0")
        }
        return .text(String(Int(frequency)))
    }
}

// MARK: - String Extension for HTML Escaping

private extension String {
    func escapingHTML() -> String {
        var result = replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
}
