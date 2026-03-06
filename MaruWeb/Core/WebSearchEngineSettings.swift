// WebSearchEngineSettings.swift
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

public enum SearchEngine: Codable, Equatable, Sendable {
    case google
    case bing
    case custom(searchURL: String, suggestionsURL: String?)

    var searchTemplate: String {
        switch self {
        case .google:
            "https://www.google.co.jp/search?q=%s&hl=ja"
        case .bing:
            "https://www.bing.com/search?setmkt=ja-JP&q=%s"
        case let .custom(searchURL, _):
            searchURL
        }
    }

    var suggestionsTemplate: String? {
        switch self {
        case .google:
            "https://suggestqueries.google.com/complete/search?client=firefox&q=%s"
        case .bing:
            "https://www.bing.com/osjson.aspx?query=%s&mkt=ja-JP"
        case let .custom(_, suggestionsURL):
            suggestionsURL
        }
    }

    func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = searchTemplate.replacingOccurrences(of: "%s", with: encoded)
        return URL(string: urlString)
    }

    func suggestionsURL(for query: String) -> URL? {
        guard let template = suggestionsTemplate else { return nil }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = template.replacingOccurrences(of: "%s", with: encoded)
        return URL(string: urlString)
    }

    /// The kind is used by the settings picker to distinguish built-in vs custom.
    public var kind: SearchEngineKind {
        switch self {
        case .google: .google
        case .bing: .bing
        case .custom: .custom
        }
    }
}

public enum SearchEngineKind: String, CaseIterable, Identifiable, Sendable {
    case google = "Google"
    case bing = "Bing"
    case custom = "Custom"

    public var id: String {
        rawValue
    }

    public var localizedDisplayName: String {
        WebStrings.searchEngineDisplayName(self)
    }

    func localizedDisplayName(locale: Locale) -> String {
        WebStrings.searchEngineDisplayName(self, locale: locale)
    }
}

public enum WebSearchEngineSettings {
    public static let searchEngineKey = "webSearchEngine"
    public static let searchSuggestionsEnabledKey = "webSearchSuggestionsEnabled"
    public static let searchSuggestionsEnabledDefault = true

    public static var searchEngine: SearchEngine {
        get {
            guard let data = UserDefaults.standard.data(forKey: searchEngineKey),
                  let engine = try? JSONDecoder().decode(SearchEngine.self, from: data)
            else {
                return .google
            }
            return engine
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: searchEngineKey)
            }
        }
    }

    public static var searchSuggestionsEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: searchSuggestionsEnabledKey) as? Bool
            return stored ?? searchSuggestionsEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: searchSuggestionsEnabledKey)
        }
    }
}
