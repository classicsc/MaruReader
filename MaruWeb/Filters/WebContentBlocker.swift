// WebContentBlocker.swift
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

/// Namespace for content-blocker constants used across MaruWeb and the host app.
public enum WebContentBlocker {
    /// `@AppStorage` key for the master content-blocker toggle. Defaults to `true`.
    public static let isEnabledKey = "web.contentBlocker.isEnabled"
    /// Default value for the master toggle.
    public static let isEnabledDefault = true

    /// Internal flag: have we seeded the default filter lists for this user?
    static let didSeedDefaultsKey = "web.contentBlocker.didSeedDefaults"

    /// `BGAppRefreshTask` identifier registered for periodic filter list updates.
    public static let backgroundRefreshTaskIdentifier =
        "net.undefinedstar.MaruReader.web.FilterListsRefresh"

    /// Auto-refresh interval (one week).
    public static let updateInterval: TimeInterval = 7 * 24 * 60 * 60

    /// Maximum number of rules per compiled `WKContentRuleList`. WebKit imposes a hard
    /// cap close to this value, so the compiler partitions oversize outputs into chunks.
    public static let maxRulesPerCompiledList = 150_000

    /// Identifier prefix shared by every `WKContentRuleList` MaruWeb compiles. Used both
    /// when assigning identifiers and when garbage-collecting stale ones.
    public static let contentRuleListIdentifierPrefix = "maruweb-adblock"

    /// Filter lists seeded the first time the content blocker is initialised. Tuned for
    /// MaruReader's Japanese-reading audience.
    public static let defaultFilterListSeeds: [WebFilterListSeed] = [
        WebFilterListSeed(
            name: "EasyList",
            sourceURL: URL(string: "https://easylist.to/easylist/easylist.txt")!,
            format: .standard
        ),
        WebFilterListSeed(
            name: "EasyPrivacy",
            sourceURL: URL(string: "https://easylist.to/easylist/easyprivacy.txt")!,
            format: .standard
        ),
        WebFilterListSeed(
            name: "uBlock Origin Filters",
            sourceURL: URL(string: "https://ublockorigin.github.io/uAssets/filters/filters.txt")!,
            format: .standard
        ),
        WebFilterListSeed(
            name: "AdGuard Japanese",
            sourceURL: URL(string: "https://filters.adtidy.org/extension/ublock/filters/7.txt")!,
            format: .standard
        ),
    ]
}
