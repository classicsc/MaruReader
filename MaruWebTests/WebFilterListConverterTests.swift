// WebFilterListConverterTests.swift
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

struct WebFilterListConverterTests {
    @Test func convertsStandardFiltersToWebKitContentRuleListJSON() throws {
        let definition = try WebFilterListConverter.convert([
            WebFilterListSource(
                identifier: "test",
                contents: "||ads.example.com^\nexample.com##.ad-banner"
            ),
        ])
        let rules = try decodedRules(from: definition)
        let actionTypes = Set(rules.compactMap { rule in
            (rule["action"] as? [String: Any])?["type"] as? String
        })

        #expect(definition.convertedFilterCount == 2)
        #expect(definition.ruleCount == rules.count)
        #expect(actionTypes.contains("block"))
        #expect(actionTypes.contains("css-display-none"))
        #expect(actionTypes.contains("ignore-previous-rules"))
        #expect(definition.identifier.hasPrefix("maruweb-adblock-"))
        #expect(definition.contentDigest.count == 64)
    }

    @Test func convertsHostsFiltersToNetworkOnlyRules() throws {
        let definition = try WebFilterListConverter.convert(
            [
                WebFilterListSource(
                    identifier: "hosts",
                    contents: "0.0.0.0 ads.example.com\ntracker.example.org",
                    format: .hosts
                ),
            ],
            options: WebFilterListConversionOptions(ruleTypes: .networkOnly)
        )
        let rules = try decodedRules(from: definition)
        let actionTypes = Set(rules.compactMap { rule in
            (rule["action"] as? [String: Any])?["type"] as? String
        })

        #expect(definition.convertedFilterCount == 2)
        #expect(definition.ruleCount == rules.count)
        #expect(actionTypes.contains("block"))
        #expect(!actionTypes.contains("css-display-none"))
    }

    @Test func cosmeticEngineReturnsUrlSpecificAndDynamicSelectors() throws {
        let engine = try WebCosmeticFilterEngine(
            sources: [
                WebFilterListSource(
                    identifier: "test",
                    contents: "example.com##.ad-banner\n##.generic-ad"
                ),
            ],
            resourcesJSON: ""
        )

        let resources = try engine.resources(for: #require(URL(string: "https://example.com/article")))
        let selectors = engine.hiddenClassIDSelectors(
            classes: ["generic-ad"],
            ids: [],
            exceptions: resources.exceptions
        )

        #expect(resources.hideSelectors.contains(".ad-banner"))
        #expect(!resources.hideSelectors.contains(".generic-ad"))
        #expect(selectors.contains(".generic-ad"))
    }

    @Test func cosmeticEngineUsesProvidedScriptletResources() throws {
        let resourcesJSON = """
        [{
            "name":"maru-test.js",
            "aliases":["maru-test"],
            "kind":{"mime":"application/javascript"},
            "content":"ZnVuY3Rpb24gbWFydVRlc3QoYXJnKSB7IHdpbmRvdy5fX21hcnVUZXN0ID0gYXJnOyB9"
        }]
        """
        let engine = try WebCosmeticFilterEngine(
            sources: [
                WebFilterListSource(
                    identifier: "test",
                    contents: "example.com##+js(maru-test, hello)"
                ),
            ],
            resourcesJSON: resourcesJSON
        )

        let resources = try engine.resources(for: #require(URL(string: "https://example.com/")))
        #expect(resources.injectedScript.contains("function maruTest"))
        #expect(resources.injectedScript.contains("maruTest(\"hello\")"))
    }

    private func decodedRules(from definition: WebContentRuleListDefinition) throws -> [[String: Any]] {
        let data = try #require(definition.encodedContentRuleList.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
