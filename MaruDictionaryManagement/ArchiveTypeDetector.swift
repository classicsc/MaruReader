// ArchiveTypeDetector.swift
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

internal import ReadiumZIPFoundation
import Foundation

/// The type of content found in an import archive.
public enum ArchiveContentType: Sendable {
    /// A Yomitan dictionary archive containing term/kanji banks.
    case dictionary
    /// An AJT-format indexed audio source archive.
    case audioSource
    /// A tokenizer dictionary archive containing Sudachi resources and manifest metadata.
    case tokenizerDictionary
    /// A Maru grammar dictionary archive containing Markdown entries and form-tag mappings.
    case grammarDictionary
}

/// Detects whether a ZIP archive contains a Yomitan dictionary, an AJT audio source,
/// or a tokenizer dictionary package
/// by probing the structure of its `index.json`.
///
/// Yomitan dictionaries have root-level `title` and `revision` keys with at least one
/// of `format` or `version`. AJT audio sources have a root-level `meta` object containing
/// a `name` key, plus `headwords` and `files` sections. Tokenizer dictionaries use a
/// root-level `type` of `tokenizer-dictionary` plus `name`, `version`, and `format`.
/// These schemas are fully non-overlapping, so detection is unambiguous.
enum ArchiveTypeDetector {
    /// Detect the content type of a ZIP archive.
    /// - Parameters:
    ///   - zipURL: File URL of the ZIP archive.
    ///   - manageSecurityScope: Whether to start/stop security-scoped resource
    ///     access. Pass `false` when the caller already holds the security scope.
    /// - Returns: The detected archive content type.
    /// - Throws: `ImportError.unzipFailed` if the archive can't be read,
    ///   `ImportError.unrecognizedArchive` if no valid index.json is found or its
    ///   structure doesn't match any known format.
    static func detect(zipURL: URL, manageSecurityScope: Bool = true) async throws -> ArchiveContentType {
        let didStartAccess = manageSecurityScope && zipURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                zipURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw ImportError.missingFile
        }

        let archive: Archive
        do {
            archive = try await Archive(url: zipURL, accessMode: .read)
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        guard let indexEntry = try await findIndexEntry(in: archive) else {
            throw ImportError.unrecognizedArchive
        }

        let indexData: Data
        do {
            indexData = try await archive.extractData(indexEntry, skipCRC32: true)
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        return try classify(indexData: indexData)
    }

    // MARK: - Internal

    /// Find an index.json entry in the archive, checking root level first, then one
    /// level of nesting, then falling back to a lone root-level JSON file.
    private static func findIndexEntry(in archive: Archive) async throws -> Entry? {
        let entries: [Entry]
        do {
            entries = try await archive.entries()
        } catch {
            throw ImportError.unzipFailed(underlyingError: error)
        }

        let fileEntries = entries.filter { $0.type == .file }
        let rootEntries = fileEntries.filter { !$0.path.contains("/") }

        // Exact match at root
        if let entry = rootEntries.first(where: { $0.path == "index.json" }) {
            return entry
        }

        // One level nested (e.g., "dictname/index.json")
        if let entry = fileEntries.first(where: { entry in
            entry.path.hasSuffix("/index.json") && entry.path.split(separator: "/").count == 2
        }) {
            return entry
        }

        // Lone root-level JSON file
        let rootJSONFiles = rootEntries.filter { $0.path.lowercased().hasSuffix(".json") }
        if rootJSONFiles.count == 1 {
            return rootJSONFiles.first
        }

        return nil
    }

    /// Classify index.json data by probing for discriminating keys.
    static func classify(indexData: Data) throws -> ArchiveContentType {
        guard let root = try? JSONSerialization.jsonObject(with: indexData) as? [String: Any] else {
            throw ImportError.unrecognizedArchive
        }

        // AJT audio source: must have "meta" (Object with "name" String),
        // plus "headwords" and "files" top-level objects.
        if let meta = root["meta"] as? [String: Any],
           meta["name"] is String,
           root["headwords"] is [String: Any],
           root["files"] is [String: Any]
        {
            return .audioSource
        }

        if root["type"] as? String == TokenizerDictionaryIndex.packageType,
           root["name"] is String,
           root["version"] is String,
           root["format"] is Int
        {
            return .tokenizerDictionary
        }

        // Maru grammar dictionaries intentionally share Yomitan-like metadata keys
        // such as title/revision/format, so check the explicit package type before
        // the looser Yomitan dictionary probe.
        if root["type"] as? String == GrammarDictionaryIndex.packageType,
           root["title"] is String,
           root["format"] is Int,
           root["entries"] is [[String: Any]],
           root["formTags"] is [String: Any]
        {
            return .grammarDictionary
        }

        // Yomitan dictionary: must have "title" (String) and "revision" (String),
        // plus at least one of "format" or "version" (Int).
        if root["title"] is String,
           root["revision"] is String,
           root["format"] is Int || root["version"] is Int
        {
            return .dictionary
        }

        throw ImportError.unrecognizedArchive
    }
}
