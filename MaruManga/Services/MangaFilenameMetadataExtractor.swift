// MangaFilenameMetadataExtractor.swift
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

import Foundation
import FoundationModels
import MaruReaderCore
import os

struct ExtractedMangaMetadata {
    var title: String
    var author: String
    var titleWasExtracted: Bool
    var authorWasExtracted: Bool
}

struct MangaFilenameMetadataExtractor {
    private let logger = Logger.maru(category: "MangaMetadata")
    private let model: SystemLanguageModel
    private let session: LanguageModelSession
    private let promptPrefix = """
    Extract manga metadata from the provided filename.
    NEVER translate, transliterate, or romanize title or author text.
    Put volume or chapter markers in Title.
    If a leading bracketed or parenthesized name is the author, move it to Author and remove it from Title.
    Ignore unrelated leading or trailing labels for metadata other than title, author, and chapter or volume numbers. NEVER inlude extras in Title or Author.
    If the author is missing or unclear, leave Author blank.

    Output format:
    Title: [extracted title]
    Author: [extracted author or blank if not found]

    Example filename: 【石黒正数】それでも町は廻っている 第01巻
    Example output:
    Title: それでも町は廻っている 第01巻
    Author: 石黒正数

    Example Filename: [赤い魚] 第１巻
    Example output:
    Title: 赤い魚 第１巻
    Author: 

    Now extract metadata from this:

    Filename: 
    """

    static var isModelAvailable: Bool {
        isModelAvailable(model: makeModel())
    }

    var isModelAvailable: Bool {
        Self.isModelAvailable(model: model)
    }

    init() {
        model = Self.makeModel()
        let instructions = """
        Extract manga title and author from filenames.
        NEVER translate, transliterate, or romanize any extracted text.
        Move author names out of leading brackets or parentheses and out of the title.
        Output ONLY the requested Title and Author lines.
        """
        session = LanguageModelSession(model: model) {
            Instructions(instructions)
        }
    }

    func prewarm() {
        guard isModelAvailable else {
            return
        }
        session.prewarm(promptPrefix: Prompt(promptPrefix))
    }

    func extractMetadata(from filename: String, useSmartExtraction: Bool) async -> ExtractedMangaMetadata {
        guard useSmartExtraction else {
            return fallbackMetadata(for: filename)
        }
        return await extract(from: filename)
    }

    func extract(from filename: String) async -> ExtractedMangaMetadata {
        let fallback = fallbackMetadata(for: filename)
        let fallbackTitle = fallback.title
        let promptInput = normalizedPromptInput(for: filename)
        let heuristic = heuristicMetadata(for: filename, fallbackTitle: fallbackTitle)

        guard !fallbackTitle.isEmpty, !promptInput.isEmpty else {
            return fallback
        }

        guard !Task.isCancelled else {
            return heuristic ?? fallback
        }

        guard isModelAvailable else {
            return heuristic ?? fallback
        }

        do {
            var options = GenerationOptions()
            options.sampling = .greedy
            let response = try await session.respond(
                to: Prompt(promptPrefix + promptInput),
                options: options
            )
            let output = response.content
            if let parsed = parseOutput(output, fallbackTitle: fallbackTitle) {
                let preferred = preferredMetadata(primary: parsed, secondary: heuristic)
                logger.debug("Successfully extracted manga metadata from filename: \(filename)")
                logger.debug("Extracted Title: \(preferred.title), Author: \(preferred.author)")
                logger.debug("Model output: \(response.content)")
                return preferred
            }
            logger.debug("Manga metadata extraction output did not match expected format.")
            logger.debug("Model output: \(response.content)")
            return heuristic ?? fallback
        } catch {
            logger.debug("Manga metadata extraction failed: \(error.localizedDescription)")
            return heuristic ?? fallback
        }
    }

    private func fallbackMetadata(for filename: String) -> ExtractedMangaMetadata {
        let baseName = (filename as NSString).deletingPathExtension
        let fallbackTitle = baseName.isEmpty ? filename : baseName
        return ExtractedMangaMetadata(
            title: fallbackTitle,
            author: "",
            titleWasExtracted: false,
            authorWasExtracted: false
        )
    }

    func normalizedPromptInput(for filename: String) -> String {
        let trimmedFilename = filename.trimmed
        let baseName = (trimmedFilename as NSString).deletingPathExtension
        let promptInput = baseName.isEmpty ? trimmedFilename : baseName
        return promptInput.collapsingWhitespace().trimmed
    }

    func heuristicMetadata(for filename: String, fallbackTitle: String) -> ExtractedMangaMetadata? {
        var working = normalizedPromptInput(for: filename)
        guard !working.isEmpty else {
            return nil
        }

        working = stripLeadingNonAuthorTags(from: working)
        working = stripTrailingNonAuthorTags(from: working)

        if let extracted = extractLeadingBracketedAuthor(from: working) {
            return makeExtractedMetadata(title: extracted.title, author: extracted.author, fallbackTitle: fallbackTitle)
        }

        if let extracted = extractDashedAuthor(from: working) {
            return makeExtractedMetadata(title: extracted.title, author: extracted.author, fallbackTitle: fallbackTitle)
        }

        if let extracted = extractTrailingAuthor(from: working) {
            return makeExtractedMetadata(title: extracted.title, author: extracted.author, fallbackTitle: fallbackTitle)
        }

        return nil
    }

    private static func makeModel() -> SystemLanguageModel {
        SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )
    }

    private static func isModelAvailable(model: SystemLanguageModel) -> Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    func parseOutput(_ output: String, fallbackTitle: String) -> ExtractedMangaMetadata? {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }

        var parsedTitleValue: String?
        var parsedAuthorValue: String?

        for line in lines {
            guard let (label, value) = labeledValue(from: line) else {
                return nil
            }

            switch label {
            case "title":
                guard parsedTitleValue == nil else {
                    return nil
                }
                parsedTitleValue = value
            case "author":
                guard parsedAuthorValue == nil else {
                    return nil
                }
                parsedAuthorValue = value
            default:
                return nil
            }
        }

        guard let parsedTitleValue, let parsedAuthorValue else {
            return nil
        }

        let titleValue = parsedTitleValue.trimmed
        let authorValue = parsedAuthorValue.trimmed
        let titleWasExtracted = !titleValue.isEmpty
        let authorWasExtracted = !authorValue.isEmpty
        let title = titleWasExtracted ? titleValue : fallbackTitle
        return ExtractedMangaMetadata(
            title: title,
            author: authorValue,
            titleWasExtracted: titleWasExtracted,
            authorWasExtracted: authorWasExtracted
        )
    }

    private func preferredMetadata(
        primary: ExtractedMangaMetadata,
        secondary: ExtractedMangaMetadata?
    ) -> ExtractedMangaMetadata {
        guard let secondary else {
            return primary
        }

        let primaryScore = metadataScore(primary)
        let secondaryScore = metadataScore(secondary)

        if secondaryScore > primaryScore {
            return secondary
        }

        if secondaryScore == primaryScore, secondaryScore > 0 {
            let primaryTitleContainsAuthor = title(primary.title, containsAuthor: primary.author)
            let secondaryTitleContainsAuthor = title(secondary.title, containsAuthor: secondary.author)

            if primaryTitleContainsAuthor != secondaryTitleContainsAuthor {
                return secondaryTitleContainsAuthor ? primary : secondary
            }

            if secondary.title.count < primary.title.count {
                return secondary
            }
        }

        return primary
    }

    private func metadataScore(_ metadata: ExtractedMangaMetadata) -> Int {
        var score = 0
        if metadata.titleWasExtracted {
            score += 1
        }
        if metadata.authorWasExtracted {
            score += 1
        }
        return score
    }

    private func title(_ title: String, containsAuthor author: String) -> Bool {
        let normalizedAuthor = author.trimmed
        guard !normalizedAuthor.isEmpty else {
            return false
        }

        return title.localizedCaseInsensitiveContains(normalizedAuthor)
    }

    private func makeExtractedMetadata(
        title: String,
        author: String,
        fallbackTitle: String
    ) -> ExtractedMangaMetadata? {
        let cleanedTitle = title.normalizedSeparatorWhitespace().trimmed
        let cleanedAuthor = author.normalizedSeparatorWhitespace().trimmed
        let titleWasExtracted = !cleanedTitle.isEmpty && cleanedTitle != fallbackTitle
        let authorWasExtracted = !cleanedAuthor.isEmpty

        guard titleWasExtracted || authorWasExtracted else {
            return nil
        }

        return ExtractedMangaMetadata(
            title: titleWasExtracted ? cleanedTitle : fallbackTitle,
            author: cleanedAuthor,
            titleWasExtracted: titleWasExtracted,
            authorWasExtracted: authorWasExtracted
        )
    }

    private func stripLeadingNonAuthorTags(from value: String) -> String {
        var result = value.trimmed

        while let segment = leadingBracketedSegment(in: result), !looksLikeAuthor(segment.content) {
            result = segment.remainder.trimmed
        }

        return result
    }

    private func stripTrailingNonAuthorTags(from value: String) -> String {
        var result = value.trimmed

        while let segment = trailingBracketedSegment(in: result), !looksLikeAuthor(segment.content) {
            result = segment.remainder.trimmed
        }

        return result
    }

    private func extractLeadingBracketedAuthor(from value: String) -> (title: String, author: String)? {
        guard let segment = leadingBracketedSegment(in: value), looksLikeAuthor(segment.content) else {
            return nil
        }

        let title = stripTrailingNonAuthorTags(from: segment.remainder)
        guard !title.isEmpty else {
            return nil
        }

        return (title, segment.content)
    }

    private func extractDashedAuthor(from value: String) -> (title: String, author: String)? {
        let separators = [" - ", " – ", " — "]

        for separator in separators {
            guard let range = value.range(of: separator, options: .backwards) else {
                continue
            }

            let title = String(value[..<range.lowerBound]).trimmed
            let author = String(value[range.upperBound...]).trimmed
            guard !title.isEmpty, looksLikeAuthor(author) else {
                continue
            }

            return (title, author)
        }

        return nil
    }

    private func extractTrailingAuthor(from value: String) -> (title: String, author: String)? {
        guard let separatorIndex = value.lastIndex(where: { $0 == " " || $0 == "_" }) else {
            return nil
        }

        let title = String(value[..<separatorIndex]).trimmed
        let authorStart = value.index(after: separatorIndex)
        let author = String(value[authorStart...]).trimmed
        guard !title.isEmpty, !author.isEmpty else {
            return nil
        }
        guard containsVolumeOrChapterMarker(title), looksLikeAuthor(author) else {
            return nil
        }

        return (title, author)
    }

    private func leadingBracketedSegment(in value: String) -> (content: String, remainder: String)? {
        let pairs: [(open: Character, close: Character)] = [("[", "]"), ("(", ")"), ("（", "）"), ("【", "】")]

        guard let firstCharacter = value.first else {
            return nil
        }

        for pair in pairs where firstCharacter == pair.open {
            guard let closingIndex = value.firstIndex(of: pair.close) else {
                return nil
            }

            let contentStart = value.index(after: value.startIndex)
            let content = String(value[contentStart ..< closingIndex]).trimmed
            let remainderStart = value.index(after: closingIndex)
            let remainder = String(value[remainderStart...]).trimmed
            return (content, remainder)
        }

        return nil
    }

    private func trailingBracketedSegment(in value: String) -> (content: String, remainder: String)? {
        let pairs: [(open: Character, close: Character)] = [("[", "]"), ("(", ")"), ("（", "）"), ("【", "】")]

        guard let lastCharacter = value.last else {
            return nil
        }

        for pair in pairs where lastCharacter == pair.close {
            guard let openingIndex = value.lastIndex(of: pair.open) else {
                return nil
            }

            let contentStart = value.index(after: openingIndex)
            let content = String(value[contentStart ..< value.index(before: value.endIndex)]).trimmed
            let remainder = String(value[..<openingIndex]).trimmed
            return (content, remainder)
        }

        return nil
    }

    private func looksLikeAuthor(_ value: String) -> Bool {
        let candidate = value.trimmed
        guard !candidate.isEmpty else {
            return false
        }

        if looksLikeMetadataTag(candidate) {
            return false
        }

        let lowercaseCandidate = candidate.lowercased()
        let disallowedKeywords = [
            "english", "eng", "japanese", "jpn", "ja", "volume", "vol",
            "chapter", "ch", "complete", "edition", "archive", "bonus",
            "sample", "preview", "extra", "extras", "collection", "deluxe",
        ]
        if disallowedKeywords.contains(where: { lowercaseCandidate.contains($0) }) {
            return false
        }

        if candidate.rangeOfCharacter(from: .decimalDigits) != nil {
            return false
        }

        let hasJapanese = candidate.containsJapaneseCharacters
        let hasLatinLetters = candidate.containsLatinLetters

        if hasJapanese {
            return candidate.count <= 12
        }

        if hasLatinLetters {
            let words = candidate.split(separator: " ").filter { !$0.isEmpty }
            return words.count >= 2 && words.count <= 4
        }

        return false
    }

    private func looksLikeMetadataTag(_ value: String) -> Bool {
        let candidate = value.trimmed
        guard !candidate.isEmpty else {
            return false
        }

        let lowercaseCandidate = candidate.lowercased()
        let keywordMatches = [
            "english", "eng", "japanese", "jpn", "ja", "volume", "vol",
            "chapter", "ch", "complete", "edition", "archive", "bonus",
            "sample", "preview", "extra", "extras", "collection", "deluxe", "ver",
        ]
        if keywordMatches.contains(where: { lowercaseCandidate.contains($0) }) {
            return true
        }

        if candidate.range(of: #"\b\d+\s*p\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    private func containsVolumeOrChapterMarker(_ value: String) -> Bool {
        let lowercaseValue = value.lowercased()
        if lowercaseValue.contains("volume") || lowercaseValue.contains("chapter") {
            return true
        }
        if lowercaseValue.contains("vol") || lowercaseValue.contains("ch") {
            return true
        }
        return value.contains("巻") || value.contains("話") || value.contains("第")
    }

    private func labeledValue(from line: String) -> (String, String)? {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return nil
        }

        let label = String(line[..<colonIndex]).trimmed.lowercased()
        guard label == "title" || label == "author" else {
            return nil
        }

        let valueStart = line.index(after: colonIndex)
        let value = String(line[valueStart...]).trimmed
        return (label, value)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func collapsingWhitespace() -> String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func normalizedSeparatorWhitespace() -> String {
        replacingOccurrences(of: "_", with: " ").collapsingWhitespace()
    }

    var containsJapaneseCharacters: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040 ... 0x30FF, 0x4E00 ... 0x9FFF, 0x3400 ... 0x4DBF, 0xF900 ... 0xFAFF:
                true
            default:
                false
            }
        }
    }

    var containsLatinLetters: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0041 ... 0x005A, 0x0061 ... 0x007A,
                 0x00C0 ... 0x00D6, 0x00D8 ... 0x00F6, 0x00F8 ... 0x024F:
                true
            default:
                false
            }
        }
    }
}
