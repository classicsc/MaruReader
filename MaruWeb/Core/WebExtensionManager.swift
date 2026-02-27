// WebExtensionManager.swift
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
import MaruReaderCore
import os
import WebKit

private class BundleFinder {}

private extension Bundle {
    static let framework: Bundle = {
        let bundle = Bundle(for: BundleFinder.self)
        let bundleName = "MaruResources"
        let url = bundle.resourceURL?.appendingPathComponent(bundleName + ".bundle")
        return url.flatMap(Bundle.init(url:)) ?? bundle
    }()
}

/// Manages a single shared `WKWebExtensionController` so the content blocker
/// extension is loaded once and reused across all tabs.
@MainActor
final class WebExtensionManager {
    private static let logger = Logger.maru(category: "WebExtensionManager")
    private var controller: WKWebExtensionController?
    private var loadTask: Task<WKWebExtensionController?, Never>?

    /// Returns the shared extension controller, creating and loading the
    /// extension on first call. Concurrent callers coalesce on the same load.
    func extensionController() async -> WKWebExtensionController? {
        if let controller {
            return controller
        }
        if let loadTask {
            return await loadTask.value
        }
        let task = Task { @MainActor () -> WKWebExtensionController? in
            let controller = WKWebExtensionController()
            guard let context = await Self.loadContentBlockerExtension() else {
                return nil
            }
            do {
                try controller.load(context)
            } catch {
                Self.logger.error("Failed to load content blocker: \(String(describing: error), privacy: .public)")
                return nil
            }
            return controller
        }
        loadTask = task
        let result = await task.value
        controller = result
        loadTask = nil
        return result
    }

    private static func loadContentBlockerExtension() async -> WKWebExtensionContext? {
        guard let extensionURL = Bundle.framework.url(
            forResource: "uBOLite.safari",
            withExtension: nil
        ) else {
            Self.logger.warning("uBlock extension bundle not found")
            return nil
        }

        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: extensionURL)
            let context = WKWebExtensionContext(for: webExtension)

            context.setPermissionStatus(
                .grantedExplicitly,
                for: WKWebExtension.Permission.declarativeNetRequest
            )

            if let allURLs = try? WKWebExtension.MatchPattern(string: "<all_urls>") {
                context.setPermissionStatus(.grantedExplicitly, for: allURLs)
            }

            return context
        } catch {
            Self.logger.error("Failed to create web extension: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
