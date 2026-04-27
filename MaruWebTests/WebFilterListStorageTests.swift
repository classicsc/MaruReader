// WebFilterListStorageTests.swift
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

@MainActor
struct WebFilterListStorageTests {
    @Test func seedDefaults_isIdempotentAcrossTwoCalls() throws {
        let env = try TestEnv.make()
        env.storage.seedDefaultsIfNeeded(defaults: env.defaults)
        let firstCount = env.storage.entries.count
        env.storage.seedDefaultsIfNeeded(defaults: env.defaults)
        #expect(env.storage.entries.count == firstCount)
        #expect(firstCount == WebContentBlocker.defaultFilterListSeeds.count)
    }

    @Test func seedDefaults_doesNotReSeedWhenUserHasRemovedADefault() throws {
        let env = try TestEnv.make()
        env.storage.seedDefaultsIfNeeded(defaults: env.defaults)
        guard let first = env.storage.entries.first else {
            Issue.record("expected seeded entries")
            return
        }
        env.storage.remove(id: first.id)
        env.storage.seedDefaultsIfNeeded(defaults: env.defaults)
        let urls = Set(env.storage.entries.map(\.sourceURL))
        #expect(!urls.contains(first.sourceURL))
    }

    @Test func add_andRemove_writesAndDeletesContentsFile() throws {
        let env = try TestEnv.make()
        let seed = try WebFilterListSeed(
            name: "Test",
            sourceURL: #require(URL(string: "https://example.com/list.txt")),
            format: .standard
        )
        guard let entry = env.storage.add(seed: seed) else {
            Issue.record("expected to insert seed")
            return
        }
        let digest = try env.storage.applyDownloadSuccess(
            id: entry.id,
            contents: "||ads.example.com^",
            etag: "\"abc\"",
            lastModified: nil,
            attemptedAt: Date(),
            succeededAt: Date()
        )
        let onDisk = env.storage.loadContents(for: entry.id)
        #expect(onDisk == "||ads.example.com^")
        #expect(digest.count == 64)
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.etag == "\"abc\"")
        #expect(updated?.contentDigest == digest)

        env.storage.remove(id: entry.id)
        #expect(env.storage.loadContents(for: entry.id) == nil)
        #expect(env.storage.entries.contains(where: { $0.id == entry.id }) == false)
    }

    @Test func applyDownloadFailure_preservesPreviousContents() throws {
        let env = try TestEnv.make()
        guard let entry = try env.storage.add(seed: WebFilterListSeed(
            name: "T",
            sourceURL: #require(URL(string: "https://example.com/a.txt")),
            format: .standard
        )) else { Issue.record("insert failed"); return }
        try env.storage.applyDownloadSuccess(
            id: entry.id, contents: "||a^",
            etag: nil, lastModified: nil,
            attemptedAt: Date(), succeededAt: Date()
        )
        env.storage.applyDownloadFailure(id: entry.id, attemptedAt: Date(), message: "boom")
        #expect(env.storage.loadContents(for: entry.id) == "||a^")
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.lastFetchError == "boom")
    }

    @Test func setEnabled_andRename_persist() throws {
        let env = try TestEnv.make()
        guard let entry = try env.storage.add(seed: WebFilterListSeed(
            name: "Old",
            sourceURL: #require(URL(string: "https://example.com/b.txt")),
            format: .standard
        )) else { Issue.record("insert failed"); return }
        env.storage.setEnabled(id: entry.id, false)
        env.storage.rename(id: entry.id, to: "New")
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.isEnabled == false)
        #expect(updated?.name == "New")
    }
}

@MainActor
private struct TestEnv {
    let storage: WebFilterListStorage
    let defaults: UserDefaults
    let directory: URL

    static func make() throws -> TestEnv {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MaruWebFilterListsTests-\(UUID().uuidString)")
        let controller = makeWebPersistenceController()
        let suite = "MaruWebFilterListsTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let storage = WebFilterListStorage(
            persistenceController: controller,
            fileManager: .default,
            filterListsDirectory: directory
        )
        storage.start()
        return TestEnv(storage: storage, defaults: defaults, directory: directory)
    }
}
