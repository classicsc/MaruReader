// DeinflectionLocalization.swift
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

/// Language options for deinflection display names and descriptions.
public enum DeinflectionLanguage: String, CaseIterable, Sendable, Codable {
    case followSystem = "system"
    case en
    case ja
    case zhHant = "zh-Hant"
    case zhHans = "zh-Hans"

    /// Resolve to a concrete language, using the system locale when `followSystem`.
    public var resolved: DeinflectionLanguage {
        guard self == .followSystem else { return self }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "ja": return .ja
        case "zh":
            let script = Locale.current.language.script?.identifier
            if script == "Hans" { return .zhHans }
            return .zhHant
        default:
            return .en
        }
    }

    /// The BCP-47 key used in the JSON localizations file.
    public var jsonKey: String {
        switch self {
        case .followSystem: resolved.jsonKey
        case .en: "en"
        case .ja: "ja"
        case .zhHant: "zh-Hant"
        case .zhHans: "zh-Hans"
        }
    }

    /// User-facing display name for the settings picker.
    public var displayLabel: String {
        switch self {
        case .followSystem: FrameworkLocalization.string("Follow System Language")
        case .en: "English"
        case .ja: "日本語"
        case .zhHant: "繁體中文"
        case .zhHans: "简体中文"
        }
    }
}

/// Localized display name and description for a single deinflection transform.
public struct LocalizedDeinflectionEntry: Sendable {
    public let displayName: String
    public let description: String

    public init(displayName: String, description: String) {
        self.displayName = displayName
        self.description = description
    }
}

/// Holds per-language content for a deinflection transform, loaded from JSON.
public struct LocalizedDeinflectionContent: Sendable {
    private let entries: [String: LocalizedDeinflectionEntry] // keyed by jsonKey

    public init(entries: [String: LocalizedDeinflectionEntry]) {
        self.entries = entries
    }

    /// Resolve the display name for a given language preference, falling back to English.
    public func displayName(for language: DeinflectionLanguage) -> String {
        let key = language.resolved.jsonKey
        if let entry = entries[key] {
            return entry.displayName
        }
        return entries["en"]?.displayName ?? ""
    }

    /// Resolve the description for a given language preference, falling back to English.
    public func description(for language: DeinflectionLanguage) -> String {
        let key = language.resolved.jsonKey
        if let entry = entries[key] {
            return entry.description
        }
        return entries["en"]?.description ?? ""
    }
}

// MARK: - JSON Loading

/// Decoded shape matching the JSON file structure.
private struct DeinflectionLocalizationFile: Decodable {
    // Top-level: transform name → language entries
    let transforms: [String: [String: LanguageEntry]]

    struct LanguageEntry: Decodable {
        let displayName: String
        let description: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        transforms = try container.decode([String: [String: LanguageEntry]].self)
    }
}

/// Load all localized deinflection content from the bundled JSON resource.
public func loadDeinflectionLocalizations() -> [String: LocalizedDeinflectionContent] {
    guard let url = Bundle.framework.url(forResource: "deinflection-localizations", withExtension: "json") else {
        assertionFailure("deinflection-localizations.json not found in bundle")
        return [:]
    }

    do {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(DeinflectionLocalizationFile.self, from: data)

        return file.transforms.mapValues { langEntries in
            let entries = langEntries.mapValues { entry in
                LocalizedDeinflectionEntry(displayName: entry.displayName, description: entry.description)
            }
            return LocalizedDeinflectionContent(entries: entries)
        }
    } catch {
        assertionFailure("Failed to decode deinflection-localizations.json: \(error)")
        return [:]
    }
}
