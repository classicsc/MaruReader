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

@Generable(description: "Manga metadata extracted from a filename.")
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
    Extract the title and author from the filename. If volume or chapter numbers are present, include in the title field. \
    Filenames may also include publishing organization, language tags, or technical metadata. \
    Ignore those extras and return only title and author.

    <example>
    <prompt>Filename: golden_fist_man_chapter_1</prompt>
    <assistant>
    Reasoning: I see that this filename contains the title and a chapter number. \
    I will place the title and chapter number in the Title field and leave the Author field empty. \
    Since the filename is in English, I will use English.
    Title: Golden Fist Man Chapter 1
    Author:
    </assistant>
    </example>

    <example>
    <prompt>Filename: [Umikan] (博之なこ) 赤い魚 第１巻 [600p]</prompt>
    <assistant>
    Reasoning: I see that this filename contains a title, volume number, author, and extra metadata. \
    I will place the title and volume number in the Title field, the author in the Author field, \
    and ignore the extra metadata. Since the filename is in Japanese, I will use Japanese.
    Title: 赤い魚 第１巻
    Author: 博之なこ
    </assistant>
    </example>

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
        You extract manga metadata from filenames. Output EXACTLY in the requested format \
        with no further information or comment. If the filename contains multiple scripts, prioritize \
        Japanese. You MUST NOT guess missing information. If the author is not given or not clear, \
        leave the author blank.
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

        guard !fallbackTitle.isEmpty else {
            return fallback
        }

        guard !Task.isCancelled else {
            return fallback
        }

        guard isModelAvailable else {
            return fallback
        }

        do {
            let options = GenerationOptions(temperature: 0.2)
            let response = try await session.respond(
                to: Prompt(promptPrefix + fallbackTitle),
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

        guard lines.count == 2 else {
            return nil
        }

        guard let rawTitleValue = value(from: lines[0], prefix: "Title:"),
              let rawAuthorValue = value(from: lines[1], prefix: "Author:")
        else {
            return nil
        }

        let titleValue = rawTitleValue.trimmed
        let authorValue = rawAuthorValue.trimmed
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

    private func value(from line: String, prefix: String) -> String? {
        guard line.lowercased().hasPrefix(prefix.lowercased()) else {
            return nil
        }
        let startIndex = line.index(line.startIndex, offsetBy: prefix.count)
        return String(line[startIndex...]).trimmed
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNonEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
