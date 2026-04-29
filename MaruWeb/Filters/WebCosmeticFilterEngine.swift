// WebCosmeticFilterEngine.swift
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

// swiftformat:disable header
// This Source Code Form is subject to the terms of the Mozilla
// Public License, v. 2.0. If a copy of the MPL was not distributed
// with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct WebCosmeticFilterResources: Sendable, Equatable {
    public let hideSelectors: [String]
    public let proceduralActions: [String]
    public let exceptions: [String]
    public let injectedScript: String
    public let genericHide: Bool
}

public final class WebCosmeticFilterEngine: @unchecked Sendable {
    private let engine: AdblockCosmeticFilterEngine

    public convenience init(sources: [WebFilterListSource]) throws {
        try self.init(sources: sources, resourcesJSON: Self.defaultResourcesJSON())
    }

    public init(sources: [WebFilterListSource], resourcesJSON: String) throws {
        engine = try AdblockCosmeticFilterEngine(
            filterLists: sources.map(\.ffiValue),
            resourcesJson: resourcesJSON
        )
    }

    public func resources(for url: URL) -> WebCosmeticFilterResources {
        let resources = engine.resourcesForUrl(url: url.absoluteString)
        return WebCosmeticFilterResources(
            hideSelectors: resources.hideSelectors,
            proceduralActions: resources.proceduralActions,
            exceptions: resources.exceptions,
            injectedScript: resources.injectedScript,
            genericHide: resources.generichide
        )
    }

    public func hiddenClassIDSelectors(
        classes: [String],
        ids: [String],
        exceptions: [String]
    ) -> [String] {
        engine.hiddenClassIdSelectors(
            classes: classes,
            ids: ids,
            exceptions: exceptions
        )
    }

    private static func defaultResourcesJSON() -> String {
        guard let url = Bundle(for: WebCosmeticFilterBundleMarker.self).url(
            forResource: "adblock-resources",
            withExtension: "json"
        ) else {
            return ""
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}

private final class WebCosmeticFilterBundleMarker {}
