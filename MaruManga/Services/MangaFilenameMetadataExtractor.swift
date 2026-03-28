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

actor MangaFilenameMetadataExtractor {
    private let logger = Logger.maru(category: "MangaMetadata")
    private let model: SystemLanguageModel
    private var prewarmedSession: LanguageModelSession?
    private let instructions = """
    Extract manga title and author from filenames.
    NEVER translate, transliterate, or romanize any extracted text.
    Move author names out of leading brackets or parentheses and out of the title.
    Output ONLY the requested Title and Author lines.
    """
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
    }

    func prewarm() {
        guard isModelAvailable else {
            return
        }
        let session = makeSession()
        session.prewarm(promptPrefix: Prompt(promptPrefix))
        prewarmedSession = session
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

        guard !fallbackTitle.isEmpty, !promptInput.isEmpty else {
            return fallback
        }

        guard !Task.isCancelled else {
            return fallback
        }

        guard isModelAvailable else {
            return fallback
        }

        do {
            var options = GenerationOptions()
            options.sampling = .greedy
            options.maximumResponseTokens = maximumResponseTokens(for: promptInput)
            let response = try await takeSession().respond(
                to: Prompt(promptPrefix + promptInput),
                options: options
            )
            let output = response.content
            if let parsed = parseOutput(output, fallbackTitle: fallbackTitle) {
                logger.debug("Successfully extracted manga metadata from filename: \(filename)")
                logger.debug("Extracted Title: \(parsed.title), Author: \(parsed.author)")
                logger.debug("Model output: \(response.content)")
                return parsed
            }
            logger.debug("Manga metadata extraction output did not match expected format.")
            logger.debug("Model output: \(response.content)")
            return fallback
        } catch {
            logger.debug("Manga metadata extraction failed: \(error.localizedDescription)")
            return fallback
        }
    }

    private nonisolated func fallbackMetadata(for filename: String) -> ExtractedMangaMetadata {
        let baseName = (filename as NSString).deletingPathExtension
        let fallbackTitle = baseName.isEmpty ? filename : baseName
        return ExtractedMangaMetadata(
            title: fallbackTitle,
            author: "",
            titleWasExtracted: false,
            authorWasExtracted: false
        )
    }

    nonisolated func normalizedPromptInput(for filename: String) -> String {
        let trimmedFilename = filename.trimmed
        let baseName = (trimmedFilename as NSString).deletingPathExtension
        let promptInput = baseName.isEmpty ? trimmedFilename : baseName
        return promptInput.collapsingWhitespace().trimmed
    }

    nonisolated func maximumResponseTokens(for promptInput: String) -> Int {
        let inputLength = promptInput.count
        // The extractor only needs two short labeled lines, plus some headroom
        return min(128, max(32, (inputLength * 2) + 16))
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

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(model: model) {
            Instructions(instructions)
        }
    }

    private func takeSession() -> LanguageModelSession {
        if let prewarmedSession {
            self.prewarmedSession = nil
            return prewarmedSession
        }
        return makeSession()
    }

    nonisolated func parseOutput(_ output: String, fallbackTitle: String) -> ExtractedMangaMetadata? {
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

    private nonisolated func labeledValue(from line: String) -> (String, String)? {
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
}
