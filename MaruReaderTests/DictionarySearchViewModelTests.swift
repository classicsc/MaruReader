// DictionarySearchViewModelTests.swift
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
@testable import MaruDictionaryUICommon
import MaruReaderCore
import Testing

@MainActor
struct DictionarySearchViewModelTests {
    @Test func linksAreActiveByDefaultAndToggleOffThenOn() {
        let viewModel = DictionarySearchViewModel()

        #expect(viewModel.linksActiveEnabled)

        viewModel.toggleLinksActive()
        #expect(!viewModel.linksActiveEnabled)

        viewModel.toggleLinksActive()
        #expect(viewModel.linksActiveEnabled)
    }

    @Test func searchServiceFactory_IsLazyUntilSearchRuns() async {
        var factoryInvocationCount = 0
        let viewModel = DictionarySearchViewModel(
            searchServiceFactory: {
                factoryInvocationCount += 1
                return DictionarySearchService()
            }
        )

        #expect(factoryInvocationCount == 0)

        viewModel.performSearch("test")
        try? await Task.sleep(for: .milliseconds(400))

        #expect(factoryInvocationCount == 1)
    }

    @Test func showResultsPage_BootstrapsWithFullLoad() async throws {
        let viewModel = DictionarySearchViewModel()
        let requestID = UUID()
        var loadedURLs: [String] = []
        var evaluatedScripts: [String] = []

        viewModel.resultsPageLoadHandler = { _, request in
            loadedURLs.append(request.url?.absoluteString ?? "")
        }
        viewModel.resultsPageJavaScriptHandler = { _, script in
            evaluatedScripts.append(script)
            return nil
        }

        try await viewModel.showResultsPage(for: requestID)

        #expect(viewModel.isResultsPageBootstrapped)
        #expect(loadedURLs == [
            "marureader-resource://dictionary.html?mode=results&requestId=\(requestID.uuidString)",
        ])
        #expect(evaluatedScripts.isEmpty)
    }

    @Test func showResultsPage_ReusesBootstrappedPage() async throws {
        let viewModel = DictionarySearchViewModel()
        let initialRequestID = UUID()
        let replacementRequestID = UUID()
        var loadCount = 0
        var evaluatedScripts: [String] = []

        viewModel.resultsPageLoadHandler = { _, _ in
            loadCount += 1
        }
        viewModel.resultsPageJavaScriptHandler = { _, script in
            evaluatedScripts.append(script)
            return nil
        }

        try await viewModel.showResultsPage(for: initialRequestID)
        try await viewModel.showResultsPage(for: replacementRequestID)

        #expect(loadCount == 1)
        #expect(evaluatedScripts == [
            "window.MaruReader.dictionaryResults.replaceRequest('\(replacementRequestID.uuidString)', 'results');",
        ])
    }

    @Test func showResultsPage_FallsBackToFullLoadWhenReplacementFails() async throws {
        let viewModel = DictionarySearchViewModel()
        let initialRequestID = UUID()
        let replacementRequestID = UUID()
        var loadCount = 0
        var replacementAttemptCount = 0

        viewModel.resultsPageLoadHandler = { _, _ in
            loadCount += 1
        }
        viewModel.resultsPageJavaScriptHandler = { _, script in
            if script.contains("replaceRequest") {
                replacementAttemptCount += 1
                throw NSError(domain: "DictionarySearchViewModelTests", code: 1)
            }
            return nil
        }

        try await viewModel.showResultsPage(for: initialRequestID)
        try await viewModel.showResultsPage(for: replacementRequestID)

        #expect(loadCount == 2)
        #expect(replacementAttemptCount == 1)
        #expect(viewModel.isResultsPageBootstrapped)
    }

    @Test func dictionaryRendererSecurity_AllowsOnlyLocalNavigationSchemes() {
        #expect(DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "about:blank")))
        #expect(DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "marureader-resource://dictionary.html")))
        #expect(DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "marureader-lookup://results")))
        #expect(!DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "https://example.com")))
        #expect(!DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "wss://example.com/socket")))
        #expect(!DictionaryRendererSecurity.isAllowedNavigationURL(URL(string: "javascript:alert('x')")))
        #expect(!DictionaryRendererSecurity.isAllowedNavigationURL(nil))
    }

    @Test func dictionaryRendererSecurity_ContentRuleListSourceBlocksRemoteSchemes() throws {
        let source = try DictionaryRendererSecurity.contentRuleListSource()
        let data = try #require(source.data(using: .utf8))
        let rules = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        let patterns = Set(rules.compactMap { rule in
            (rule["trigger"] as? [String: Any])?["url-filter"] as? String
        })
        let actionTypes = Set(rules.compactMap { rule in
            (rule["action"] as? [String: Any])?["type"] as? String
        })

        #expect(patterns == ["^https?://.*", "^wss?://.*"])
        #expect(actionTypes == ["block"])
    }
}
