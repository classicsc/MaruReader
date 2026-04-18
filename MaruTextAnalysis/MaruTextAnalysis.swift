// MaruTextAnalysis.swift
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

private enum InstalledTokenizerDictionaryError: LocalizedError {
    case missingBaseDirectory
    case missingDirectory
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseDirectory:
            "Tokenizer dictionary base directory was not found."
        case .missingDirectory:
            "Installed tokenizer dictionary directory was not found."
        case let .missingFile(fileName):
            "Installed tokenizer dictionary is missing \(fileName)."
        }
    }
}

private struct InstalledTokenizerDictionaryIndex: Decodable {
    let version: String
}

private final class SharedSudachiAnalyzerState: @unchecked Sendable {
    let lock = NSLock()
    var overrideDirectoryURL: URL?
    var cachedResourcePath: String?
    var cachedVersion: String?
    var cachedAnalyzer: SudachiAnalyzer?
}

enum InstalledTokenizerDictionary {
    private static let appGroupIdentifier = "group.net.undefinedstar.MaruReader"
    private static let directoryName = "TokenizerDictionary"
    private static let manifestFileName = "index.json"
    private static let requiredFiles = [
        "char.def",
        "rewrite.def",
        "sudachi.json",
        "system_full.dic",
        "unk.def",
    ]

    private static let state = SharedSudachiAnalyzerState()

    static var overrideDirectoryURL: URL? {
        get {
            state.lock.lock()
            defer { state.lock.unlock() }
            return state.overrideDirectoryURL
        }
        set {
            state.lock.lock()
            state.overrideDirectoryURL = newValue
            state.lock.unlock()
        }
    }

    static func directoryURL(fileManager: FileManager = .default) throws -> URL {
        if let overrideDirectoryURL {
            try validateDirectory(at: overrideDirectoryURL, fileManager: fileManager)
            return overrideDirectoryURL
        }

        guard let baseDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw InstalledTokenizerDictionaryError.missingBaseDirectory
        }

        let directoryURL = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try validateDirectory(at: directoryURL, fileManager: fileManager)
        return directoryURL
    }

    static func version(fileManager: FileManager = .default) -> String? {
        guard let directoryURL = try? directoryURL(fileManager: fileManager) else {
            return nil
        }

        let manifestURL = directoryURL.appendingPathComponent(manifestFileName)
        guard let data = try? Data(contentsOf: manifestURL),
              let index = try? JSONDecoder().decode(InstalledTokenizerDictionaryIndex.self, from: data)
        else {
            return nil
        }
        return index.version
    }

    private static func validateDirectory(at directoryURL: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw InstalledTokenizerDictionaryError.missingDirectory
        }

        for requiredFile in requiredFiles {
            let fileURL = directoryURL.appendingPathComponent(requiredFile)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw InstalledTokenizerDictionaryError.missingFile(requiredFile)
            }
        }
    }
}

enum SharedSudachiAnalyzer {
    private static let state = SharedSudachiAnalyzerState()

    static var result: Result<SudachiAnalyzer, Error> {
        state.lock.lock()
        defer { state.lock.unlock() }

        do {
            let resourceDirectoryURL = try InstalledTokenizerDictionary.directoryURL()
            let currentVersion = InstalledTokenizerDictionary.version()

            if let cachedAnalyzer = state.cachedAnalyzer,
               state.cachedResourcePath == resourceDirectoryURL.path,
               state.cachedVersion == currentVersion
            {
                return .success(cachedAnalyzer)
            }

            let analyzer = try SudachiAnalyzer(resourceDir: resourceDirectoryURL.path)
            try analyzer.warmUp()
            state.cachedResourcePath = resourceDirectoryURL.path
            state.cachedVersion = currentVersion
            state.cachedAnalyzer = analyzer
            return .success(analyzer)
        } catch {
            state.cachedAnalyzer = nil
            state.cachedResourcePath = nil
            state.cachedVersion = nil
            return .failure(error)
        }
    }
}

/// A segment of text with optional furigana reading for UI display.
public struct FuriganaSegment: Sendable {
    /// The displayed text (kanji, kana, or other characters).
    public let base: String

    /// Furigana reading in hiragana. Nil if base is already kana or non-Japanese.
    public let reading: String?

    /// The range of this segment in the original string.
    public let baseRange: Range<String.Index>

    public init(base: String, reading: String?, baseRange: Range<String.Index>) {
        self.base = base
        self.reading = reading
        self.baseRange = baseRange
    }
}

/// Generates furigana segments for UI display and Anki export.
public enum FuriganaGenerator {
    /// Generates furigana segments from Japanese text for display with ruby annotations.
    ///
    /// Segments containing kanji will have their okurigana (trailing kana) stripped,
    /// producing separate segments for kanji and kana portions. For example,
    /// `食べる` produces two segments: `食[た]` and `べる` (without reading).
    ///
    /// - Parameter text: The Japanese text to process.
    /// - Returns: An array of segments, each with base text and optional reading.
    public static func generateSegments(from text: String) -> [FuriganaSegment] {
        guard !text.isEmpty else { return [] }

        guard case let .success(analyzer) = SharedSudachiAnalyzer.result,
              let segments = try? analyzer.generateSegments(text: text),
              let convertedSegments = swiftSegments(from: segments, in: text)
        else {
            return fallbackSegments(for: text)
        }

        return convertedSegments
    }

    /// Formats furigana segments as an Anki-style string with bracket notation.
    ///
    /// Segments with readings are formatted as ` kanji[reading]` (with leading space).
    /// Segments without readings are included as plain text.
    ///
    /// - Parameter segments: The furigana segments to format.
    /// - Returns: A string with Anki-style furigana notation.
    public static func formatAnkiStyle(_ segments: [FuriganaSegment]) -> String {
        var result = ""
        for segment in segments {
            if let reading = segment.reading {
                result += " \(segment.base)[\(reading)]"
            } else {
                result += segment.base
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Formats furigana segments as cloze deletion components.
    ///
    /// Splits the formatted text into prefix, body, and suffix based on a selection range.
    /// Each component is formatted with Anki-style furigana notation.
    ///
    /// - Parameters:
    ///   - segments: The furigana segments to format.
    ///   - selectionRange: The range in the original text that defines the cloze body.
    ///   - text: The original text used to generate the segments.
    /// - Returns: A tuple with prefix, body, and suffix strings.
    public static func formatCloze(
        _ segments: [FuriganaSegment],
        selectionRange: Range<String.Index>,
        in text: String
    ) -> (prefix: String, body: String, suffix: String) {
        var prefix = ""
        var body = ""
        var suffix = ""

        for segment in segments {
            let formatted: String = if let reading = segment.reading {
                " \(segment.base)[\(reading)]"
            } else {
                segment.base
            }

            if segment.baseRange.upperBound <= selectionRange.lowerBound {
                prefix += formatted
            } else if segment.baseRange.lowerBound >= selectionRange.upperBound {
                suffix += formatted
            } else if segment.baseRange.lowerBound >= selectionRange.lowerBound,
                      segment.baseRange.upperBound <= selectionRange.upperBound
            {
                body += formatted
            } else if segment.reading != nil {
                body += formatted
            } else {
                if segment.baseRange.lowerBound < selectionRange.lowerBound {
                    prefix += String(text[segment.baseRange.lowerBound ..< selectionRange.lowerBound])
                }

                let bodyStart = max(segment.baseRange.lowerBound, selectionRange.lowerBound)
                let bodyEnd = min(segment.baseRange.upperBound, selectionRange.upperBound)
                if bodyStart < bodyEnd {
                    body += String(text[bodyStart ..< bodyEnd])
                }

                if selectionRange.upperBound < segment.baseRange.upperBound {
                    suffix += String(text[selectionRange.upperBound ..< segment.baseRange.upperBound])
                }
            }
        }

        return trimSegments(prefix: prefix, body: body, suffix: suffix)
    }

    private static func swiftSegments(from spans: [FuriganaSpan], in text: String) -> [FuriganaSegment]? {
        var result: [FuriganaSegment] = []
        var expectedLowerBound = text.startIndex

        for span in spans {
            guard let baseRange = range(for: span, in: text),
                  baseRange.lowerBound == expectedLowerBound,
                  String(text[baseRange]) == span.base
            else {
                return nil
            }

            result.append(FuriganaSegment(
                base: span.base,
                reading: span.reading,
                baseRange: baseRange
            ))
            expectedLowerBound = baseRange.upperBound
        }

        guard expectedLowerBound == text.endIndex else {
            return nil
        }

        return result
    }

    private static func range(for span: FuriganaSpan, in text: String) -> Range<String.Index>? {
        guard let startOffset = Int(exactly: span.startByte),
              let endOffset = Int(exactly: span.endByte),
              startOffset <= endOffset
        else {
            return nil
        }

        let utf8 = text.utf8
        guard let startUTF8 = utf8.index(utf8.startIndex, offsetBy: startOffset, limitedBy: utf8.endIndex),
              let endUTF8 = utf8.index(utf8.startIndex, offsetBy: endOffset, limitedBy: utf8.endIndex),
              let startIndex = startUTF8.samePosition(in: text),
              let endIndex = endUTF8.samePosition(in: text),
              startIndex <= endIndex
        else {
            return nil
        }

        return startIndex ..< endIndex
    }

    private static func fallbackSegments(for text: String) -> [FuriganaSegment] {
        [FuriganaSegment(base: text, reading: nil, baseRange: text.startIndex ..< text.endIndex)]
    }

    private static func trimSegments(
        prefix: String,
        body: String,
        suffix: String
    ) -> (prefix: String, body: String, suffix: String) {
        var segments = [prefix, body, suffix]

        for index in segments.indices {
            segments[index] = String(segments[index].drop(while: isTrimWhitespace))
            if !segments[index].isEmpty {
                break
            }
        }

        for index in segments.indices.reversed() {
            segments[index] = String(segments[index].reversed().drop(while: isTrimWhitespace).reversed())
            if !segments[index].isEmpty {
                break
            }
        }

        return (segments[0], segments[1], segments[2])
    }

    private static func isTrimWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }
}
