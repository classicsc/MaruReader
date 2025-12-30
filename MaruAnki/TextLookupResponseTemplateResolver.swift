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
                // Use a shorter, simpler filename to avoid potential issues
                let shortID = UUID().uuidString.prefix(8)
                let fileID = "maru_cover_\(shortID)"
                return TemplateResolvedValue(mediaFiles: [fileID: url])
            }
            return .empty

        case .screenshot:
            if let url = response.request.contextValues?.screenshotURL {
                let shortID = UUID().uuidString.prefix(8)
                let fileID = "maru_screenshot_\(shortID)"
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
            return .text(generateSentenceFurigana(response.context))

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

        case let .frequencyRankSortField(dictionaryID):
            return resolveFrequencyRankSortField(forDictionary: dictionaryID)

        case let .frequencyOccurrenceSortField(dictionaryID):
            return resolveFrequencyOccurrenceSortField(forDictionary: dictionaryID)

        case .frequencyRankHarmonicMeanSortField:
            return resolveFrequencyRankHarmonicMeanSortField()

        case .frequencyOccurrenceHarmonicMeanSortField:
            return resolveFrequencyOccurrenceHarmonicMeanSortField()

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
        // Try to find the specified dictionary, fallback to highest priority (first) if not found
        let dictResult = selectedGroup.dictionariesResults.first(where: { $0.dictionaryUUID == dictionaryID })
            ?? selectedGroup.dictionariesResults.first

        guard let dictResult else {
            return .empty
        }

        // Use Anki-compatible HTML with inline styles
        let ankiHTML = dictResult.results.generateCombinedAnkiHTML(dictionaryUUID: dictResult.dictionaryUUID)

        // Extract and resolve image paths
        let imagePaths = dictResult.results.extractImagePaths()
        let mediaFiles = resolveMediaFiles(imagePaths: imagePaths, dictionaryUUID: dictResult.dictionaryUUID)

        // Wrap in yomitan-glossary div with data-dictionary for Lapis compatibility
        let wrappedHTML = """
        <div style="text-align: left;" class="yomitan-glossary"><ol><li data-dictionary="\(dictResult.dictionaryTitle.escapingHTML())">\(ankiHTML)</li></ol></div>
        """

        return TemplateResolvedValue(text: wrappedHTML, mediaFiles: mediaFiles)
    }

    private func resolveMultiDictionaryGlossary() -> TemplateResolvedValue {
        var allMediaFiles: [String: URL] = [:]

        // Build list items with data-dictionary attributes for Lapis compatibility
        let listItems = selectedGroup.dictionariesResults.map { dictResult in
            // Use Anki-compatible HTML with inline styles
            let ankiHTML = dictResult.results.generateCombinedAnkiHTML(dictionaryUUID: dictResult.dictionaryUUID)

            // Extract and resolve image paths for this dictionary
            let imagePaths = dictResult.results.extractImagePaths()
            let mediaFiles = resolveMediaFiles(imagePaths: imagePaths, dictionaryUUID: dictResult.dictionaryUUID)
            allMediaFiles.merge(mediaFiles) { _, new in new }

            // Yomitan format: <li data-dictionary="..."><i>(dict name)</i> content</li>
            return """
            <li data-dictionary="\(dictResult.dictionaryTitle.escapingHTML())"><i>(\(dictResult.dictionaryTitle.escapingHTML()))</i> \(ankiHTML)</li>
            """
        }.joined()

        // Wrap in yomitan-glossary div for Lapis compatibility
        let html = """
        <div style="text-align: left;" class="yomitan-glossary"><ol>\(listItems)</ol></div>
        """

        return TemplateResolvedValue(text: html, mediaFiles: allMediaFiles)
    }

    private func resolveGlossaryNoDictionary() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first else {
            return .empty
        }
        // Use Anki-compatible HTML with inline styles
        let ankiHTML = firstDict.results.generateCombinedAnkiHTML(dictionaryUUID: firstDict.dictionaryUUID)

        // Extract and resolve image paths
        let imagePaths = firstDict.results.extractImagePaths()
        let mediaFiles = resolveMediaFiles(imagePaths: imagePaths, dictionaryUUID: firstDict.dictionaryUUID)

        return TemplateResolvedValue(text: ankiHTML, mediaFiles: mediaFiles)
    }

    /// Resolves image paths to actual file URLs in the Media directory.
    private func resolveMediaFiles(imagePaths: [String], dictionaryUUID: UUID) -> [String: URL] {
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return [:]
        }

        let mediaBaseDir = appGroupDir
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(dictionaryUUID.uuidString, isDirectory: true)

        var mediaFiles: [String: URL] = [:]

        for imagePath in imagePaths {
            // Build the full file URL
            let fileURL = imagePath.split(separator: "/").reduce(mediaBaseDir) {
                $0.appendingPathComponent(String($1), isDirectory: false)
            }

            // Use just the filename as the key (Anki stores media flat)
            let filename = (imagePath as NSString).lastPathComponent
            mediaFiles[filename] = fileURL
        }

        return mediaFiles
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
            "\(freq.dictionaryTitle): \(freq.displayString)"
        }
        return .text(freqStrings.isEmpty ? nil : freqStrings.joined(separator: ", "))
    }

    private func resolveSingleFrequency() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first,
              let firstFreq = firstResult.frequencies.first
        else {
            return .empty
        }
        return .text(firstFreq.displayString)
    }

    private func resolveFrequency(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            return .empty
        }
        // Try to find the specified dictionary, fallback to first frequency if not found
        let freq = firstResult.frequencies.first(where: { $0.dictionaryID == dictionaryID })
            ?? firstResult.frequencies.first
        guard let freq else {
            return .empty
        }
        return .text(freq.displayString)
    }

    private func resolveFrequencyRankSortField(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            // No frequency data: use high default for rank (rare word)
            return .text("9999999")
        }
        // Try to find the specified dictionary, fallback to first rank-based frequency if not found
        let freq = firstResult.frequencies.first(where: { $0.dictionaryID == dictionaryID })
            ?? firstResult.frequencies.first(where: { $0.mode == "rank-based" })
        guard let freq else {
            return .text("9999999")
        }
        return .text(String(Int(freq.value)))
    }

    private func resolveFrequencyOccurrenceSortField(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            // No frequency data: use 0 for occurrence (no occurrences)
            return .text("0")
        }
        // Try to find the specified dictionary, fallback to first occurrence-based frequency if not found
        let freq = firstResult.frequencies.first(where: { $0.dictionaryID == dictionaryID })
            ?? firstResult.frequencies.first(where: { $0.mode == nil || $0.mode == "occurrence-based" })
        guard let freq else {
            return .text("0")
        }
        return .text(String(Int(freq.value)))
    }

    private func resolveFrequencyRankHarmonicMeanSortField() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            return .text("9999999")
        }
        let rankFrequencies = firstResult.frequencies.filter { $0.mode == "rank-based" }
        guard !rankFrequencies.isEmpty else {
            return .text("9999999")
        }
        let harmonicMean = calculateHarmonicMean(rankFrequencies.map(\.value))
        return .text(String(Int(harmonicMean)))
    }

    private func resolveFrequencyOccurrenceHarmonicMeanSortField() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first
        else {
            return .text("0")
        }
        let occurrenceFrequencies = firstResult.frequencies.filter { $0.mode == nil || $0.mode == "occurrence-based" }
        guard !occurrenceFrequencies.isEmpty else {
            return .text("0")
        }
        let harmonicMean = calculateHarmonicMean(occurrenceFrequencies.map(\.value))
        return .text(String(Int(harmonicMean)))
    }

    private func calculateHarmonicMean(_ values: [Double]) -> Double {
        let positiveValues = values.filter { $0 > 0 }
        guard !positiveValues.isEmpty else { return 0 }
        let reciprocalSum = positiveValues.reduce(0.0) { $0 + 1.0 / $1 }
        return Double(positiveValues.count) / reciprocalSum
    }

    // MARK: - Sentence Furigana

    private func generateSentenceFurigana(_ sentence: String?) -> String? {
        guard let sentence, !sentence.isEmpty else { return nil }
        return SentenceFuriganaGenerator.generate(from: sentence)
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
