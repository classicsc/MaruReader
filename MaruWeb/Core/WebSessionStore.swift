// WebSessionStore.swift
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

@MainActor
final class WebSessionStore {
    static let shared = WebSessionStore()

    private let extensionManager = WebExtensionManager()
    private var prewarmTask: Task<WebSession, Never>?
    private var prewarmContentBlockingEnabled: Bool?

    func prewarm(enableContentBlocking: Bool) {
        if let currentSetting = prewarmContentBlockingEnabled,
           currentSetting != enableContentBlocking
        {
            prewarmTask?.cancel()
            prewarmTask = nil
            prewarmContentBlockingEnabled = nil
        }
        guard prewarmTask == nil else { return }
        prewarmContentBlockingEnabled = enableContentBlocking
        prewarmTask = Task {
            let controller = enableContentBlocking
                ? await extensionManager.extensionController()
                : nil
            return WebSession.make(extensionController: controller)
        }
    }

    func makeSession(enableContentBlocking: Bool) async -> WebSession {
        if let task = prewarmTask,
           prewarmContentBlockingEnabled == enableContentBlocking
        {
            let session = await task.value
            prewarmTask = nil
            prewarmContentBlockingEnabled = nil
            return session
        }

        prewarmTask?.cancel()
        prewarmTask = nil
        prewarmContentBlockingEnabled = nil

        let controller = enableContentBlocking
            ? await extensionManager.extensionController()
            : nil
        return WebSession.make(extensionController: controller)
    }
}
