// WebFilterListUpdateSchedulerTests.swift
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
struct WebFilterListUpdateSchedulerTests {
    @Test func repeatedRefreshesShareWorkAndClearAfterCompletion() async throws {
        let env = try makeEnv()
        let entry = try addEntry(to: env)
        StubURLProtocol.set(
            StubURLProtocol.Response(statusCode: 304, body: Data(), headers: [:]),
            for: entry.sourceURL
        )

        let first = env.scheduler.startRefresh()
        let second = env.scheduler.startRefresh()
        await first.value
        await second.value

        #expect(StubURLProtocol.requestCount(for: [entry.sourceURL]) == 1)

        await env.scheduler.startRefresh().value

        #expect(StubURLProtocol.requestCount(for: [entry.sourceURL]) == 2)
    }

    @Test func cancelledRefreshClearsInFlightTask() async throws {
        let env = try makeEnv()
        let entry = try addEntry(to: env)
        let started = CountGate()
        let stopped = CountGate()
        StubURLProtocol.setHanging(
            for: entry.sourceURL,
            onStart: { Task { await started.signal() } },
            onStop: { Task { await stopped.signal() } }
        )

        let cancelled = env.scheduler.startRefresh()
        await started.wait(for: 1)
        cancelled.cancel()
        await cancelled.value
        await stopped.wait(for: 1)

        StubURLProtocol.set(
            StubURLProtocol.Response(statusCode: 304, body: Data(), headers: [:]),
            for: entry.sourceURL
        )
        await env.scheduler.startRefresh().value

        #expect(StubURLProtocol.requestCount(for: [entry.sourceURL]) == 2)
        let updated = try #require(env.storage.entries.first { $0.id == entry.id })
        #expect(updated.lastFetchError == nil)
    }

    private struct Env {
        let storage: WebFilterListStorage
        let scheduler: WebFilterListUpdateScheduler
    }

    private func makeEnv() throws -> Env {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MaruWebSchedulerTests-\(UUID().uuidString)")
        let storage = WebFilterListStorage(
            persistenceController: makeWebPersistenceController(),
            fileManager: .default,
            filterListsDirectory: directory
        )
        storage.start()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let downloader = WebFilterListDownloader(
            session: URLSession(configuration: configuration),
            storage: storage
        )
        return Env(
            storage: storage,
            scheduler: WebFilterListUpdateScheduler(
                downloader: downloader,
                storage: storage,
                submitRequest: { _ in }
            )
        )
    }

    private func addEntry(to env: Env) throws -> WebFilterListEntry {
        let url = try #require(URL(string: "https://example.com/scheduler-\(UUID().uuidString).txt"))
        return try #require(env.storage.add(seed: WebFilterListSeed(
            name: "Scheduler Test",
            sourceURL: url,
            format: .standard
        )))
    }
}
