// WebNavigationBlockingTests.swift
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
@testable import MaruWeb
import Testing
import WebKit

struct WebNavigationBlockingTests {
    @Test(arguments: ["https://example.com/chapter", "HTTP://example.com"])
    func popupsOpenForWebURLs(value: String) throws {
        #expect(try WebBrowserPage.allowsNewTab(url: #require(URL(string: value))))
    }

    @Test(arguments: ["about:blank", "javascript:alert(1)", "data:text/html,ad", "youtube://watch", "tel:123"])
    func popupSchemesAreRestricted(value: String) throws {
        #expect(try !WebBrowserPage.allowsNewTab(url: #require(URL(string: value))))
    }

    @Test func throttleAllowsTwoPopupsPerWindow() {
        var throttle = WebPopupThrottle()
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let decisions = [0, 0.5, 1, 2, 2.1, 4.5].map { throttle.allows(at: start.addingTimeInterval($0)) }
        #expect(decisions == [true, true, false, true, false, true])
    }

    @Test func navigationFiltersRespectSourceExceptionsAndResourceTypes() throws {
        let engine = try WebCosmeticFilterEngine(sources: [WebFilterListSource(
            identifier: "test",
            contents: "||ads.example^\n@@||ads.example/allowed^\n||scoped.example^$document,domain=reader.example\n||frames.example^$subdocument\n||scripts.example^$script"
        )], resourcesJSON: "")
        let source = try #require(URL(string: "https://reader.example/chapter"))
        func blocks(_ value: String, mainFrame: Bool = true, from: URL? = nil) throws -> Bool {
            try engine.blocksNavigation(to: #require(URL(string: value)), from: from ?? source, mainFrame: mainFrame, method: "GET")
        }
        #expect(try blocks("https://ads.example/popup"))
        #expect(try !blocks("https://ads.example/allowed"))
        #expect(try blocks("https://scoped.example/ad"))
        let otherSource = try #require(URL(string: "https://other.example/"))
        #expect(try !blocks("https://scoped.example/ad", from: otherSource))
        #expect(try blocks("https://frames.example/ad", mainFrame: false))
        #expect(try !blocks("https://frames.example/ad"))
        #expect(try !blocks("https://scripts.example/chapter"))
        #expect(try !blocks("https://reader.example/next"))
    }

    @Test @MainActor func disabledBlockerSkipsNavigationChecks() throws {
        let suite = "WebNavigationBlockingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = WebContentBlockerProvider(defaults: defaults)
        defaults.set(false, forKey: WebContentBlocker.isEnabledKey)
        let adURL = try #require(URL(string: "https://ads.example/"))
        #expect(!provider.blocksNavigation(to: adURL, from: nil, mainFrame: true, method: "GET"))
    }
}
