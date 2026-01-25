// MaruWebTests.swift
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

import Foundation
@testable import MaruWeb
import Testing

struct MaruWebTests {
    @Test func normalizedURLAddsScheme() async throws {
        let url = WebAddressParser.normalizedURL(from: "bookwalker.jp")
        #expect(url?.absoluteString == "https://bookwalker.jp")
    }

    @Test func normalizedURLPreservesScheme() async throws {
        let url = WebAddressParser.normalizedURL(from: "https://example.com/path")
        #expect(url?.absoluteString == "https://example.com/path")
    }

    @Test func normalizedURLRejectsWhitespace() async throws {
        let url = WebAddressParser.normalizedURL(from: "not a url")
        #expect(url == nil)
    }

    @Test func addBookmarkPersistsEntry() async throws {
        let persistence = WebDataPersistenceController(inMemory: true)
        let manager = WebBookmarkManager(persistenceController: persistence)
        let url = URL(string: "https://bookwalker.jp")!

        let snapshot = try await manager.addBookmark(url: url, title: "Bookwalker")
        #expect(snapshot.url == url)
        #expect(snapshot.title == "Bookwalker")

        let bookmarks = try await manager.fetchBookmarks()
        #expect(bookmarks.count == 1)
        #expect(bookmarks.first?.url == url)
    }

    @Test func toggleBookmarkRemovesExisting() async throws {
        let persistence = WebDataPersistenceController(inMemory: true)
        let manager = WebBookmarkManager(persistenceController: persistence)
        let url = URL(string: "https://example.com")!

        let isBookmarked = try await manager.toggleBookmark(url: url, title: "Example")
        #expect(isBookmarked == true)

        let isNowBookmarked = try await manager.toggleBookmark(url: url, title: "Example")
        #expect(isNowBookmarked == false)

        let bookmarks = try await manager.fetchBookmarks()
        #expect(bookmarks.isEmpty)
    }

    @Test func contentBlockingDefaultsToEnabled() async throws {
        let defaults = UserDefaults.standard
        let key = WebContentBlockingSettings.contentBlockingEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        #expect(
            WebContentBlockingSettings.contentBlockingEnabled
                == WebContentBlockingSettings.contentBlockingEnabledDefault
        )
    }

    @Test func contentBlockingPersistsChanges() async throws {
        let defaults = UserDefaults.standard
        let key = WebContentBlockingSettings.contentBlockingEnabledKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        WebContentBlockingSettings.contentBlockingEnabled = false
        #expect(WebContentBlockingSettings.contentBlockingEnabled == false)
        WebContentBlockingSettings.contentBlockingEnabled = true
        #expect(WebContentBlockingSettings.contentBlockingEnabled == true)
    }

    @Test @MainActor func webSessionStoreConsumesPrewarm() async throws {
        let store = WebSessionStore()
        store.prewarm(enableContentBlocking: false)
        let firstSession = await store.makeSession(enableContentBlocking: false)
        let secondSession = await store.makeSession(enableContentBlocking: false)
        #expect(firstSession !== secondSession)
    }
}
