// TextLookupResponseTemplateResolver.swift
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

internal import MaruTextAnalysis
import Foundation
import MaruReaderCore

/// Resolves template values from a `TextLookupResponse` and a selected term group.
///
/// This implementation extracts values from dictionary search results and the original
/// lookup request context to populate Anki note fields.
public struct TextLookupResponseTemplateResolver: TemplateValueResolver {
    private let response: TextLookupResponse
    private let selectedGroup: GroupedSearchResults
    private let contextImageConfiguration: ContextImageConfiguration
    private let primaryAudioURL: URL?

    /// Creates a resolver for the given response and selected term.
    ///
    /// - Parameters:
    ///   - response: The search response containing all results and context.
    ///   - selectedGroup: The specific term group to extract values from.
    ///   - selectedDictionaryID: Retained for source compatibility. Currently unused.
    ///   - contextImageConfiguration: Configuration for resolving the contextImage template value.
    public init(
        response: TextLookupResponse,
        selectedGroup: GroupedSearchResults,
        selectedDictionaryID _: UUID? = nil,
        contextImageConfiguration: ContextImageConfiguration = .default,
        primaryAudioURL: URL? = nil
    ) {
        self.response = response
        self.selectedGroup = selectedGroup
        self.contextImageConfiguration = contextImageConfiguration
        self.primaryAudioURL = primaryAudioURL
    }

    public func resolve(_ templateValue: TemplateValue) async -> TemplateResolvedValue {
        switch templateValue {
        // MARK: - Simple values from search results

        case .expression:
            return .text(selectedGroup.expression)

        case .reading:
            return .text(selectedGroup.reading)

        // MARK: - Context values from request

        case .sentence:
            return .text(response.effectiveContext)

        case .contextInfo:
            return resolveContextInfo()

        case .contextImage:
            return resolveContextImage()

        // MARK: - Cloze deletion values

        case .clozePrefix:
            return resolveClozePrefix()

        case .clozeBody:
            return .text(response.primaryResult)

        case .clozeSuffix:
            return resolveClozeSuffix()

        case .clozeFuriganaPrefix:
            return resolveClozeFuriganaPrefix()

        case .clozeFuriganaBody:
            return resolveClozeFuriganaBody()

        case .clozeFuriganaSuffix:
            return resolveClozeFuriganaSuffix()

        // MARK: - Conjugation/deinflection

        case .conjugation:
            return .text(selectedGroup.deinflectionInfo)

        // MARK: - Furigana

        case .furigana:
            return resolveFurigana()

        case .sentenceFurigana:
            return .text(generateSentenceFurigana(response.effectiveContext))

        // MARK: - Tags and part of speech

        case .partOfSpeech:
            return resolvePartOfSpeech()

        case .tags:
            return resolveTags()

        // MARK: - Dictionary glossary values

        case let .singleDictionaryGlossary(dictionaryID):
            return resolveGlossary(forDictionary: dictionaryID)

        case .singleGlossary:
            return resolveSingleGlossary()

        case .multiDictionaryGlossary:
            return resolveMultiDictionaryGlossary()

        case .glossaryNoDictionary:
            return resolveGlossaryNoDictionary()

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

        case .pitchAccentCategories:
            return resolvePitchAccentCategories()

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

        // MARK: - Custom value passthrough

        case let .customHTMLValue(value):
            return .text(value)

        @unknown default:
            return .empty
        }
    }

    // MARK: - Private Resolution Helpers

    private func resolveClozePrefix() -> TemplateResolvedValue {
        let context = response.effectiveContext
        guard let range = response.effectivePrimaryResultSourceRange,
              range.lowerBound >= context.startIndex,
              range.lowerBound <= context.endIndex
        else {
            return .text("")
        }
        let prefix = String(context[context.startIndex ..< range.lowerBound])
        return .text(prefix)
    }

    private func resolveClozeSuffix() -> TemplateResolvedValue {
        let context = response.effectiveContext
        guard let range = response.effectivePrimaryResultSourceRange,
              range.upperBound >= context.startIndex,
              range.upperBound <= context.endIndex
        else {
            return .text("")
        }
        let suffix = String(context[range.upperBound ..< context.endIndex])
        return .text(suffix)
    }

    private func resolveClozeFuriganaPrefix() -> TemplateResolvedValue {
        let segments = resolveClozeFuriganaSegments()
        return .text(segments.prefix)
    }

    private func resolveClozeFuriganaBody() -> TemplateResolvedValue {
        let segments = resolveClozeFuriganaSegments()
        return .text(segments.body)
    }

    private func resolveClozeFuriganaSuffix() -> TemplateResolvedValue {
        let segments = resolveClozeFuriganaSegments()
        return .text(segments.suffix)
    }

    private func resolveClozeFuriganaSegments() -> (prefix: String?, body: String?, suffix: String?) {
        let context = response.effectiveContext
        guard let range = response.effectivePrimaryResultSourceRange else {
            // No valid range - entire context as prefix
            let segments = FuriganaGenerator.generateSegments(from: context)
            return (FuriganaGenerator.formatAnkiStyle(segments), nil, nil)
        }
        let furiganaSegments = FuriganaGenerator.generateSegments(from: context)
        let cloze = FuriganaGenerator.formatCloze(furiganaSegments, selectionRange: range, in: context)
        return (
            cloze.prefix.isEmpty ? nil : cloze.prefix,
            cloze.body.isEmpty ? nil : cloze.body,
            cloze.suffix.isEmpty ? nil : cloze.suffix
        )
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

    private func resolveContextInfo() -> TemplateResolvedValue {
        if let contextInfo = normalizedContextInfo(response.request.contextValues?.contextInfo) {
            return .text(contextInfo)
        }

        let sourceType = response.request.contextValues?.sourceType ?? .dictionary
        guard sourceType == .dictionary else {
            return .empty
        }
        return .text(makeDictionaryContextInfo())
    }

    private func makeDictionaryContextInfo() -> String {
        let query = normalizedContextInfo(response.request.context) ?? "Unknown"
        let headword = normalizedContextInfo(selectedGroup.expression)
            ?? normalizedContextInfo(response.primaryResult)
            ?? "Unknown"
        let dictionaryTitle = normalizedContextInfo(selectedGroup.dictionariesResults.first?.dictionaryTitle) ?? "Unknown Dictionary"
        return "Query: \(query) | Headword: \(headword) | Dictionary: \(dictionaryTitle)"
    }

    private func normalizedContextInfo(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func resolveSingleGlossary() -> TemplateResolvedValue {
        guard let firstDictionaryID = selectedGroup.dictionariesResults.first?.dictionaryUUID else {
            return .empty
        }
        return resolveGlossary(forDictionary: firstDictionaryID)
    }

    private func resolveGlossary(forDictionary dictionaryID: UUID) -> TemplateResolvedValue {
        // Try to find the specified dictionary, fallback to highest priority (first) if not found
        let dictResult = selectedGroup.dictionariesResults.first(where: { $0.dictionaryUUID == dictionaryID })
            ?? selectedGroup.dictionariesResults.first

        guard let dictResult else {
            return .empty
        }

        // Use Anki-compatible HTML with CSS classes
        let ankiHTML = dictResult.results.generateCombinedAnkiHTML(dictionaryUUID: dictResult.dictionaryUUID)

        // Extract and resolve image paths
        let imagePaths = dictResult.results.extractImagePaths()
        let mediaFiles = resolveMediaFiles(imagePaths: imagePaths, dictionaryUUID: dictResult.dictionaryUUID)

        // Generate style tag with base styles and dictionary-specific styles
        let styleTag = AnkiStyleProvider.generateStyleTag(
            dictionaryResults: [(uuid: dictResult.dictionaryUUID, title: dictResult.dictionaryTitle)]
        )

        // Wrap in yomitan-glossary div with data-dictionary for Yomitan/Lapis compatibility
        let wrappedHTML = """
        <div style="text-align: left;" class="yomitan-glossary"><ol><li data-dictionary="\(dictResult.dictionaryTitle.escapingHTML())">\(ankiHTML)</li></ol>\(styleTag)</div>
        """

        return TemplateResolvedValue(text: wrappedHTML, mediaFiles: mediaFiles)
    }

    private func resolveMultiDictionaryGlossary() -> TemplateResolvedValue {
        var allMediaFiles: [String: URL] = [:]

        // Build list items with data-dictionary attributes for Yomitan/Lapis compatibility
        let listItems = selectedGroup.dictionariesResults.map { dictResult in
            // Use Anki-compatible HTML with CSS classes
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

        // Generate style tag with base styles and all dictionary-specific styles
        let dictionaryInfo = selectedGroup.dictionariesResults.map { (uuid: $0.dictionaryUUID, title: $0.dictionaryTitle) }
        let styleTag = AnkiStyleProvider.generateStyleTag(dictionaryResults: dictionaryInfo)

        // Wrap in yomitan-glossary div for Yomitan/Lapis compatibility
        let html = """
        <div style="text-align: left;" class="yomitan-glossary"><ol>\(listItems)</ol>\(styleTag)</div>
        """

        return TemplateResolvedValue(text: html, mediaFiles: allMediaFiles)
    }

    private func resolveGlossaryNoDictionary() -> TemplateResolvedValue {
        guard let firstDict = selectedGroup.dictionariesResults.first else {
            return .empty
        }
        // Use Anki-compatible HTML with CSS classes
        let ankiHTML = firstDict.results.generateCombinedAnkiHTML(dictionaryUUID: firstDict.dictionaryUUID)

        // Extract and resolve image paths
        let imagePaths = firstDict.results.extractImagePaths()
        let mediaFiles = resolveMediaFiles(imagePaths: imagePaths, dictionaryUUID: firstDict.dictionaryUUID)

        // Generate style tag with base styles and dictionary-specific styles
        let styleTag = AnkiStyleProvider.generateStyleTag(
            dictionaryResults: [(uuid: firstDict.dictionaryUUID, title: firstDict.dictionaryTitle)]
        )

        // Wrap in yomitan-glossary div for styling (even without dictionary label)
        let wrappedHTML = """
        <div style="text-align: left;" class="yomitan-glossary">\(ankiHTML)\(styleTag)</div>
        """

        return TemplateResolvedValue(text: wrappedHTML, mediaFiles: mediaFiles)
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

    private func resolveContextImage() -> TemplateResolvedValue {
        guard let contextValues = response.request.contextValues else {
            return .empty
        }

        let sourceType = contextValues.sourceType
        guard let preference = contextImageConfiguration.preferredImage(for: sourceType) else {
            // No images available for this source type (e.g., dictionary)
            return .empty
        }

        let coverURL = contextValues.documentCoverImageURL
        let screenshotURL = contextValues.screenshotURL

        // Determine which URL to use based on preference, with fallback
        let selectedURL: URL? = switch preference {
        case .cover:
            coverURL ?? screenshotURL
        case .screenshot:
            screenshotURL ?? coverURL
        }

        guard let url = selectedURL else {
            return .empty
        }

        let shortID = UUID().uuidString.prefix(8)
        let fileID = "maru_context_\(shortID)"
        return TemplateResolvedValue(mediaFiles: [fileID: url])
    }

    private func resolvePronunciationAudio() -> TemplateResolvedValue {
        guard let primaryAudioURL else {
            return .empty
        }
        let fileID = "audio_\(UUID().uuidString)"
        return TemplateResolvedValue(mediaFiles: [fileID: primaryAudioURL])
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

    private func resolvePitchAccentCategories() -> TemplateResolvedValue {
        let categories = PitchAccentCategoryCalculator.categories(for: selectedGroup)
        let text = categories.map(\.rawValue).joined(separator: ",")
        return .text(text.isEmpty ? nil : text)
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
        let segments = FuriganaGenerator.generateSegments(from: sentence)
        return FuriganaGenerator.formatAnkiStyle(segments)
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
