// WebSession.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import WebKit

import Foundation

private class BundleFinder {}

private extension Bundle {
    static let framework: Bundle = {
        let bundle = Bundle(for: BundleFinder.self)
        let bundleName = "MaruResources"
        let url = bundle.resourceURL?.appendingPathComponent(bundleName + ".bundle")
        return url.flatMap(Bundle.init(url:)) ?? bundle
    }()
}

@MainActor
final class WebSession {
    let page: WebPage
    let dataStore: WKWebsiteDataStore
    private let extensionController: WKWebExtensionController?

    init(
        dataStore: WKWebsiteDataStore = WebsiteDataStore.main,
        enableContentBlocking: Bool = true
    ) {
        self.dataStore = dataStore

        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore

        // Configure extension controller if content blocking is enabled
        if enableContentBlocking {
            let controller = WKWebExtensionController()
            self.extensionController = controller
            configuration.webExtensionController = controller
            Task { @MainActor in
                if let extensionContext = await Self.loadContentBlockerExtension() {
                    do {
                        try controller.load(extensionContext)
                    } catch {
                        print("Failed to load content blocker: \(error)")
                    }
                }
            }
        } else {
            self.extensionController = nil
        }

        page = WebPage(configuration: configuration)
        page.isInspectable = true
    }

    private static func loadContentBlockerExtension() async -> WKWebExtensionContext? {
        guard let extensionURL = Bundle.framework.url(
            forResource: "uBOLite.safari",
            withExtension: nil
        ) else {
            print("uBlock extension bundle not found")
            return nil
        }

        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: extensionURL)
            let context = WKWebExtensionContext(for: webExtension)

            // Grant necessary permissions for content blocking
            context.setPermissionStatus(
                .grantedExplicitly,
                for: WKWebExtension.Permission.declarativeNetRequest
            )

            // Grant access to all URLs for content blocking
            if let allURLs = try? WKWebExtension.MatchPattern(string: "<all_urls>") {
                context.setPermissionStatus(.grantedExplicitly, for: allURLs)
            }

            return context
        } catch {
            print("Failed to create web extension: \(error)")
            return nil
        }
    }
}
