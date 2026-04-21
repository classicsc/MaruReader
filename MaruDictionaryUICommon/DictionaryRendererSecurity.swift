// DictionaryRendererSecurity.swift
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
import WebKit

@MainActor
public struct DictionaryRendererNavigationDecider: WebPage.NavigationDeciding {
    public init() {}

    public mutating func decidePolicy(for action: WebPage.NavigationAction, preferences _: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard DictionaryRendererSecurity.isAllowedNavigationURL(action.request.url) else {
            return .cancel
        }
        return .allow
    }

    public mutating func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        guard DictionaryRendererSecurity.isAllowedNavigationURL(response.response.url) else {
            return .cancel
        }
        return .allow
    }
}

@MainActor
public enum DictionaryRendererSecurity {
    public static let allowedNavigationSchemes: Set<String> = [
        "about",
        "marureader-anki",
        "marureader-audio",
        "marureader-lookup",
        "marureader-media",
        "marureader-resource",
    ]

    private static let blockedNetworkURLPatterns = [
        "^https?://.*",
        "^wss?://.*",
    ]
    private static let contentRuleListIdentifier = "com.marureader.dictionary.local-only"
    private static var contentRuleListTask: Task<WKContentRuleList, Error>?

    public static func isAllowedNavigationURL(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else {
            return false
        }
        return allowedNavigationSchemes.contains(scheme)
    }

    public static func installContentRuleList(on userContentController: WKUserContentController) async throws {
        let ruleList = try await contentRuleList().value
        userContentController.add(ruleList)
    }

    public static func contentRuleListSource() throws -> String {
        let rules = blockedNetworkURLPatterns.map { pattern in
            [
                "trigger": [
                    "url-filter": pattern,
                ],
                "action": [
                    "type": "block",
                ],
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: rules)
        guard let source = String(data: data, encoding: .utf8) else {
            throw DictionaryRendererSecurityError.invalidContentRuleListEncoding
        }
        return source
    }

    private static func contentRuleList() -> Task<WKContentRuleList, Error> {
        if let contentRuleListTask {
            return contentRuleListTask
        }

        let task = Task { @MainActor in
            let source = try contentRuleListSource()
            guard let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: contentRuleListIdentifier,
                encodedContentRuleList: source
            ) else {
                throw DictionaryRendererSecurityError.ruleListCompilationReturnedNil
            }
            return ruleList
        }

        contentRuleListTask = task
        return task
    }
}

private enum DictionaryRendererSecurityError: Error {
    case invalidContentRuleListEncoding
    case ruleListCompilationReturnedNil
}
